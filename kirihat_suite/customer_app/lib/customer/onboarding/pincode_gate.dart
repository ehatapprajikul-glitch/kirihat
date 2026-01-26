import 'package:flutter/material.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:kirihat_core/services/service_area_service.dart';
import '../customer_dashboard.dart';
import 'area_selection_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/services/user_service.dart';
import 'account_setup_screen.dart';

class PincodeGateScreen extends StatefulWidget {
  const PincodeGateScreen({super.key});

  @override
  State<PincodeGateScreen> createState() => _PincodeGateScreenState();
}

class _PincodeGateScreenState extends State<PincodeGateScreen> {
  final _sessionService = SessionService();
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Check if user has already completed onboarding (guest or logged in)
    final hasCompleted = await _sessionService.hasCompletedOnboarding();
    
    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;

    if (hasCompleted && mounted) {
      // If logged in, perform additional profile check
      if (user != null) {
        final isProfileComplete =
            await UserService().checkProfileCompletionWithCache(user.uid);
        
        if (!isProfileComplete) {
            // Redirect to Account Setup
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AccountSetupScreen()),
          );
          return;
        }
      }

      // Navigate directly to home (works for both guest and logged-in users)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CustomerDashboard()),
      );
    } else {
      // Show onboarding
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF0D9759),
            strokeWidth: 3,
          ),
        ),
      );
    }

    return const PincodeEntryScreen();
  }
}

class PincodeEntryScreen extends StatefulWidget {
  const PincodeEntryScreen({super.key});

  @override
  State<PincodeEntryScreen> createState() => _PincodeEntryScreenState();
}

class _PincodeEntryScreenState extends State<PincodeEntryScreen> {
  final _pincodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _serviceAreaService = ServiceAreaService();
  bool _isLoading = false;

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _validateAndProceed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final pincode = _pincodeController.text.trim();
      
      // Find aggregated vendor zones for this pincode
      final aggregatedData = await _serviceAreaService.getAggregatedServiceAreas(pincode);
      
      if (aggregatedData == null || (aggregatedData['areas'] as List).isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sorry, we don\'t deliver to pincode $pincode yet'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final areas = List<String>.from(aggregatedData['areas']);
      final zoneName = aggregatedData['zoneName'];

      // Always navigate to area selection (even if 1 area, to confirm logic? Or skip if 1?
      // User said "customer can select only one post office... Let this customer select an area 'a'".
      // If there is only 1 area, we can auto-select, but let's stick to explicit selection for now to be safe.
      
      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AreaSelectionScreen(
              pincode: pincode,
              areas: areas,
              city: zoneName, 
              state: '', 
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutQuart;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D9759).withOpacity(0.05),
              Colors.white,
              const Color(0xFF0D9759).withOpacity(0.02),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Hero Icon
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9759).withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9759).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Header
                  const Center(
                    child: Text(
                      'Welcome Home',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Enter your pincode to check availability\nin your neighborhood',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Feature highlight card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9759).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            color: Color(0xFF0D9759),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ultra-Fast Delivery',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Freshness delivered from your local dark store directly to you.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Pincode Input
                  Text(
                    'Pincode',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onChanged: (value) {
                        if (value.length == 6) {
                          _validateAndProceed();
                        }
                      },
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: Color(0xFF1A1A1A),
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: Colors.grey[300],
                          letterSpacing: 4,
                          fontWeight: FontWeight.normal,
                        ),
                        prefixIcon: const Icon(
                          Icons.pin_drop_rounded,
                          color: Color(0xFF0D9759),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter pincode';
                        if (value.length != 6) return 'Invalid pincode';
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9759).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _validateAndProceed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9759),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Check Availability',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Info Helper
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            padding: const EdgeInsets.all(32),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Delivery Areas',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
                                ),
                                const SizedBox(height: 24),
                                _buildHelpItem(Icons.looks_one_rounded, 'Enter your pincode'),
                                _buildHelpItem(Icons.looks_two_rounded, 'Choose your exact area'),
                                _buildHelpItem(Icons.looks_3_rounded, 'Browse local fresh products'),
                                _buildHelpItem(Icons.looks_4_rounded, 'Get fast doorstep delivery'),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D9759),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Text('Got it, thanks!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.help_outline_rounded, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'How does this work?',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0D9759), size: 28),
          const SizedBox(width: 16),
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4A4A4A)),
          ),
        ],
      ),
    );
  }
}
