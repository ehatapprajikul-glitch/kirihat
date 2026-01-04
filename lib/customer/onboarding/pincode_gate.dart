import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/session_service.dart';
import '../../services/service_area_service.dart';
import '../customer_dashboard.dart';
import 'area_selection_screen.dart';

class PincodeGateScreen extends StatefulWidget {
  const PincodeGateScreen({super.key});

  @override
  State<PincodeGateScreen> createState() => _PincodeGateScreenState();
}

class _PincodeGateScreenState extends State<PincodeGateScreen> {
  final _sessionService = SessionService();
  final _serviceAreaService = ServiceAreaService();
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Check if user has already completed onboarding
    final hasCompleted = await _sessionService.hasCompletedOnboarding();
    
    if (hasCompleted && mounted) {
      // Navigate directly to home
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
              backgroundColor: Colors.red,
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
          MaterialPageRoute(
            builder: (context) => AreaSelectionScreen(
              pincode: pincode,
              areas: areas,
              city: zoneName, 
              state: '', 
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Welcome Icon
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0D9759).withOpacity(0.2),
                          const Color(0xFF0D9759).withOpacity(0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      size: 60,
                      color: Color(0xFF0D9759),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Welcome Text
                const Center(
                  child: Text(
                    'Welcome!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: Text(
                    'Let\'s find your nearest store',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 48),

                // Info Cards
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.flash_on,
                          color: Color(0xFF0D9759),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hyper-Local Delivery',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Get fresh products from your local dark store',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Pincode Input
                Text(
                  'Enter Your Pincode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: '781003',
                    prefixIcon: const Icon(
                      Icons.pin_drop,
                      color: Color(0xFF0D9759),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF0D9759),
                        width: 2,
                      ),
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter pincode';
                    }
                    if (value.length != 6) {
                      return 'Pincode must be 6 digits';
                    }
                    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                      return 'Please enter a valid pincode';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _validateAndProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9759),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Help Text
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('How it works'),
                          content: const Text(
                            '1. Enter your 6-digit pincode\n'
                            '2. Select your area/locality\n'
                            '3. We\'ll connect you to your nearest dark store\n'
                            '4. Shop fresh products with fast delivery!',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Got it!'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.help_outline, size: 20),
                    label: const Text('How does this work?'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9759),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
