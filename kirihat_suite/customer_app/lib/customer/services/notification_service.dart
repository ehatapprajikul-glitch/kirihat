import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;
import 'dart:async';
import '../order_details.dart';

/// Top-level function to handle background messages
/// This MUST be a top-level function (not a class method)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  StreamSubscription<QuerySnapshot>? _subscription;
  Stream<QuerySnapshot>? _notificationStream;
  bool _isListening = false;
  bool _fcmInitialized = false;
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  BuildContext? _context;

  Future<void> init(BuildContext context) async {
    debugPrint('NotificationService.init called');
    if (_isListening) {
      debugPrint('NotificationService already listening. Skipping init.');
      return;
    }
    _context = context;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped: ${response.payload}');
        _handleNotificationTap(response.payload);
      },
    );

    await _requestPermissions();
    await _createNotificationChannel();
    await _initFCM();

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('NotificationService: No user logged in during init');
      return;
    }

    debugPrint('Starting Notification Listener for User: ${user.uid}');

    _notificationStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('is_read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();

    _subscription = _notificationStream!.listen((snapshot) {
      debugPrint('Received ${snapshot.docChanges.length} notification changes');
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data() as Map<String, dynamic>;
          
          final Timestamp? timestamp = data['timestamp'];
          if (timestamp != null) {
            final diff = DateTime.now().difference(timestamp.toDate());
            debugPrint('Notification age: ${diff.inSeconds} seconds');
            if (diff.inSeconds > 60) {
              debugPrint('Skipping old notification');
              continue;
            }
          }

          final title = data['title'] ?? 'New Notification';
          final body = data['body'] ?? '';
          
          debugPrint('Showing in-app notification: $title');
          _showInAppNotification(title, doc.doc.reference);
        }
      }
    }, onError: (error) {
      debugPrint('Notification stream error: $error');
    });

    _isListening = true;
    debugPrint('Notification Service Started for ${user.uid}');
  }

  Future<void> _initFCM() async {
    if (_fcmInitialized) return;
    
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      debugPrint('FCM permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        String? token = await _messaging.getToken();
        if (token != null) {
          await _saveFCMToken(token);
        }
        
        _messaging.onTokenRefresh.listen(_saveFCMToken);
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
        
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('App opened from terminated state via notification');
          _handleMessageOpenedApp(initialMessage);
        }
        
        _fcmInitialized = true;
        debugPrint('FCM initialized successfully');
      }
    } catch (e) {
      debugPrint('FCM initialization error: $e');
    }
  }

  Future<void> _saveFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    debugPrint('Saving FCM token for user: ${user.uid}');
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'fcm_tokens': FieldValue.arrayUnion([token]),
            'fcm_token': token,
            'fcm_token_updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      debugPrint('FCM token saved successfully');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    
    if (message.notification != null) {
      _showNotification(
        id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        payload: message.data['order_id'] ?? message.data['notification_id'],
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Notification tapped (app was in background)');
    debugPrint('Data: ${message.data}');
    
    final orderId = message.data['order_id'];
    if (orderId != null && _context != null && _context!.mounted) {
      Navigator.of(_context!).push(
        MaterialPageRoute(
          builder: (context) => OrderDetailsScreen(orderId: orderId),
        ),
      );
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload != null && _context != null && _context!.mounted) {
      debugPrint('Handling notification tap: $payload');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      debugPrint('Android notification permission: ${granted ?? false}');
    } else if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
              
      final bool? granted = await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      debugPrint('iOS notification permission: ${granted ?? false}');
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'admin_channel',
      'Admin Notifications',
      description: 'Notifications from Kirihat Admin',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(channel);
    debugPrint('Notification channel created');
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'admin_channel',
      'Admin Notifications',
      channelDescription: 'Notifications from Kirihat Admin',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/launcher_icon',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(id, title, body, details, payload: payload);
    debugPrint('Notification shown: $title');
  }

  void _showInAppNotification(String title, DocumentReference docRef) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_context != null && _context!.mounted) {
        ScaffoldMessenger.of(_context!).showSnackBar(
          SnackBar(
            content: Text(title),
            action: SnackBarAction(
              label: 'Mark Read',
              onPressed: () {
                docRef.update({'is_read': true});
              },
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _isListening = false;
    _context = null;
    debugPrint('Notification Service Disposed');
  }
}