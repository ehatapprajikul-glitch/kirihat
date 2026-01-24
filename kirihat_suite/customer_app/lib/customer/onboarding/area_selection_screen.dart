import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kirihat_core/services/session_service.dart';
import 'package:kirihat_core/services/service_area_service.dart';
import '../customer_dashboard.dart';
import 'package:kirihat_core/services/user_service.dart';
import 'account_setup_screen.dart';

class AreaSelectionScreen extends StatefulWidget {
  final String pincode;
  final List<String> areas;
  final String city;
  final String state;

  const AreaSelectionScreen({
    super.key,
    required this.pincode,
    required this.areas,
    required this.city,
    required this.state,
  });

  @override
  State<AreaSelectionScreen> createState() => _AreaSelectionScreenState();
}

class _AreaSelectionScreenState extends State<AreaSelectionScreen> {
  final _sessionService = SessionService();
  String? _selectedArea;
  bool _isLoading = false;

  Future<void> _confirmSelection() async {
    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your area'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final isGuest = userId == null;
      
      final serviceAreaService = ServiceAreaService();
      final vendorIds = await serviceAreaService.findVendorsForArea(widget.pincode, _selectedArea!);
      
      if (vendorIds.isEmpty) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('No active vendors for this area currently.'),
               behavior: SnackBarBehavior.floating,
             )
           );
         }
         setState(() => _isLoading = false);
         return;
      }

      if (isGuest) {
        await _sessionService.saveGuestSession(
          pincode: widget.pincode,
          area: _selectedArea!,
          vendorIds: vendorIds,
        );
      } else {
        await _sessionService.saveSession(
          userId: userId!,
          pincode: widget.pincode,
          area: _selectedArea!,
          vendorIds: vendorIds,
        );
      }

      if (mounted) {
        // Pincode/Area saved. Now check profile completeness (Name/Gender/Address)
        // If guest, go to dashboard.
        // If logged in, check profile.
        
        if (isGuest) {
           Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const CustomerDashboard()),
            (route) => false,
          );
        } else {
           // Check profile
           final isProfileComplete = await UserService().isProfileComplete(userId);
           
           if (!isProfileComplete) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AccountSetupScreen()),
              );
           } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const CustomerDashboard()),
                (route) => false,
              );
           }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
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
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: [
              const Color(0xFF0D9759).withOpacity(0.05),
              Colors.white,
              const Color(0xFF0D9759).withOpacity(0.02),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Custom Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      'Choose Locality',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Summary Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
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
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF0D9759),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.city.isNotEmpty ? widget.city : 'Your City',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pincode: ${widget.pincode}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Select your exact area',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Areas List
              Expanded(
                child: widget.areas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_rounded, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No areas available for this pincode',
                              style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: widget.areas.length,
                        itemBuilder: (context, index) {
                          final area = widget.areas[index];
                          final isSelected = _selectedArea == area;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: const Color(0xFF0D9759).withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  )
                                ] : [],
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0D9759) : Colors.grey.shade100,
                                  width: 2,
                                ),
                              ),
                              child: ListTile(
                                onTap: () {
                                  setState(() => _selectedArea = area);
                                  _confirmSelection();
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                title: Text(
                                  area,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF0D9759) : const Color(0xFF4A4A4A),
                                  ),
                                ),
                                trailing: isSelected 
                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0D9759))
                                  : Icon(Icons.circle_outlined, color: Colors.grey[300]),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
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
                      onPressed: _isLoading ? null : _confirmSelection,
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
                                  'Confirm Locality',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Icon(Icons.shopping_bag_rounded),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

