import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Screens
import 'auth/phone_auth_screen.dart';
import 'customer/customer_dashboard.dart';
// import 'vendor/vendor_dashboard.dart'; // Removed for Customer App
// import 'admin/admin_web_layout.dart'; // Removed for Customer App
// import 'rider/rider_dashboard.dart'; // Removed for Customer App
// import 'seller/seller_dashboard.dart'; // Removed for Customer App

// IMPORT THE GATES
import 'customer/onboarding/pincode_gate.dart';
import 'package:app_links/app_links.dart'; // Import AppLinks
import 'dart:async'; // optimizing imports
import 'package:kirihat_core/services/product_display_settings_service.dart'; // Added
import 'customer/services/notification_service.dart'; // Added
import 'customer/product/enhanced_product_detail.dart'; // Added for Deep Link Navigation
import 'customer/widgets/splash_screen.dart'; // Import SplashScreen
import 'package:url_launcher/url_launcher.dart'; // For opening external links

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register FCM background message handler (must be after Firebase.initializeApp)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Check for preview mode (Web URL parameters)
  // This allows the Admin Portal to open the app with ?mode=preview
  final uri = Uri.base;
  final isPreview = uri.queryParameters['mode'] == 'preview';
  
  if (isPreview) {
    debugPrint('🚀 Initializing App in PREVIEW MODE');
    await ProductDisplaySettingsService().initialize(isPreview: true);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Check initial link
    // final appLink = await _appLinks.getInitialLink(); // legacy
    // if (appLink != null) _handleLink(appLink);

    // Subscribe to link changes
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 Deep Link Received: $uri');
      _handleLink(uri);
    });
  }

  void _handleLink(Uri uri) {
    // Expected format: https://kirihat.com/product?id=123
    // or https://kirihat.com/product/123
    
    // Check if it is a product link
    String? productId;
    
    // Strategy 1: Query Param
    if (uri.queryParameters.containsKey('id')) {
      productId = uri.queryParameters['id'];
    } 
    // Strategy 2: Path Segment (e.g. /product/123)
    else if (uri.pathSegments.contains('product') && uri.pathSegments.length > 1) {
       // simple check: if 'product' is index X, id is X+1
       int index = uri.pathSegments.indexOf('product');
       if (index + 1 < uri.pathSegments.length) {
         productId = uri.pathSegments[index + 1];
       }
    }

    if (productId != null) {
      debugPrint("🚀 Navigating to Product ID: $productId");
      // Use Global Key to navigate
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => EnhancedProductDetailScreen(
            productId: productId!,
            // We only have ID, so we might need to fetch data inside screen 
            // OR pass partial data if we had it.
            // EnhancedProductDetailScreen should handle fetching if productData is minimal/missing.
            // Assuming it handles it or we need to update it.
          ),
        ),
      );
    } else {
      // Not a product link - open in external browser
      // This handles policy pages, seller registration, about us, etc.
      debugPrint("🌐 Opening in external browser: $uri");
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add Global Navigator Key
      debugShowCheckedModeBanner: false,
      title: 'Kirihat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const SplashScreen(), // Show Splash first
    );
  }
}

// --- THE TRAFFIC COP (Decides which screen to show on app start) ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Future.delayed(const Duration(seconds: 1));
    
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.notification,
      Permission.microphone,
    ].request();
    
    debugPrint("Permissions: $statuses");
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If Waiting for Auth Data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // 2. If User is NOT Logged In -> Show PincodeGate (Guest Mode)
        // Customers can browse without login
        if (!snapshot.hasData) {
          return const PincodeGateScreen();
        }

        // 3. User is logged in - Initialize Notification Service
        NotificationService().init(context);

        return FutureBuilder<bool>(
          future: SessionService().isCustomerMode(),
          builder: (context, modeSnapshot) {
            // Wait for pref check
            if (modeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // In Customer App, we don't strictly enforce roles. 
            // If they are logged in, they see the Customer Dashboard (via PincodeGate).
            return const PincodeGateScreen(); 
          }
        );
      },
    );
  }
}
