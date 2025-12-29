import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../vendor/rider_settlement_history.dart'; // Reuse the history screen

class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({super.key});

  @override
  State<RiderHistoryScreen> createState() => _RiderHistoryScreenState();
}

class _RiderHistoryScreenState extends State<RiderHistoryScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String? _realRiderId;
  String _riderName = "Rider";
  bool _isLoadingProfile = true;

  // Filters
  String _dateFilter = 'All'; // Options: Today, 7 Days, 30 Days, Custom, All
  DateTime? _startDate;
  DateTime? _endDate;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _linkProfileByEmail();
  }

  // --- 1. LINK PROFILE ---
  Future<void> _linkProfileByEmail() async {
    if (user?.email == null) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('riders')
          .where('email', isEqualTo: user!.email)
          .limit(1)
          .get();

      if (mounted) {
        if (snapshot.docs.isNotEmpty) {
          setState(() {
            _realRiderId = snapshot.docs.first.id;
            _riderName = snapshot.docs.first.data()['name'] ?? "Rider";
            _isLoadingProfile = false;
          });
        } else {
          setState(() => _isLoadingProfile = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // --- 2. DATE PICKER LOGIC ---
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            colorScheme: const ColorScheme.light(primary: Colors.blue),
            buttonTheme:
                const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        // Set end date to end of that day (23:59:59)
        _endDate = picked.end
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
        _dateFilter = 'Custom';
      });
    }
  }

  // --- 3. FILTER LOGIC ---
  bool _isWithinDateRange(Timestamp? timestamp) {
    if (timestamp == null) return false;
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (_dateFilter == 'Today') {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    } else if (_dateFilter == 'Last 7 Days') {
      return now.difference(date).inDays <= 7;
    } else if (_dateFilter == 'Last 30 Days') {
      return now.difference(date).inDays <= 30;
    } else if (_dateFilter == 'Custom' &&
        _startDate != null &&
        _endDate != null) {
      return date.isAfter(_startDate!) && date.isBefore(_endDate!);
    }
    return true; // 'All'
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_realRiderId == null) {
      return const Scaffold(body: Center(child: Text("Profile Not Linked.")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Transaction History"),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu),
            tooltip: "Settlement History",
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RiderSettlementHistoryScreen(
                          riderId: _realRiderId!, riderName: _riderName)));
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('rider_id', isEqualTo: _realRiderId)
            .where('status', isEqualTo: 'Delivered')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var allDocs = snapshot.data!.docs.toList();

          allDocs.sort((a, b) {
            Timestamp t1 = (a.data() as Map<String, dynamic>)['delivered_at'] ??
                Timestamp.now();
            Timestamp t2 = (b.data() as Map<String, dynamic>)['delivered_at'] ??
                Timestamp.now();
            return t2.compareTo(t1);
          });

          var filteredDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;

            // 1. Date Filter (Includes Custom)
            if (!_isWithinDateRange(data['delivered_at'])) return false;

            // 2. Search Filter
            if (_searchQuery.isNotEmpty) {
              String id = doc.id.toLowerCase();
              String orderId =
                  (data['order_id'] ?? '').toString().toLowerCase();
              return id.contains(_searchQuery) ||
                  orderId.contains(_searchQuery);
            }
            return true;
          }).toList();

          // --- CALCULATE SUMMARY ---
          double lifetimeEarnings = 0;
          double currentDebt = 0;

          for (var doc in allDocs) {
            var data = doc.data() as Map<String, dynamic>;

            double commission = (data['rider_commission'] ?? 0).toDouble();
            double deliveryFee = (data['delivery_fee'] ?? 0).toDouble();

            lifetimeEarnings += commission;

            if (data['is_settled'] != true) {
              double cashCollected = (data['payment_method'] == 'COD')
                  ? (data['total_amount'] ?? 0).toDouble()
                  : 0;
              double paidSoFar = (data['amount_paid_so_far'] ?? 0).toDouble();

              // Debt = Cash - (Commission + DeliveryFee) - Paid
              double orderDebt =
                  (cashCollected - (commission + deliveryFee)) - paidSoFar;
              if (orderDebt > 0) currentDebt += orderDebt;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // 1. DATE FILTERS (Added Custom Picker Here)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Standard Chips
                    ...['All', 'Today', 'Last 7 Days', 'Last 30 Days']
                        .map((filter) {
                      bool isSelected = _dateFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          selectedColor: Colors.blue.shade100,
                          labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.blue.shade900
                                  : Colors.black),
                          onSelected: (val) =>
                              setState(() => _dateFilter = filter),
                        ),
                      );
                    }),

                    // Custom Date Picker Chip
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        avatar: const Icon(Icons.date_range, size: 16),
                        label: Text(_dateFilter == 'Custom' &&
                                _startDate != null
                            ? "${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}"
                            : "Custom Range"),
                        backgroundColor: _dateFilter == 'Custom'
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        onPressed: _selectDateRange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2. SEARCH BAR
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search Order ID...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          })
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                ),
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
              ),
              const SizedBox(height: 10),

              // 3. FINANCIAL SUMMARY CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text("Cash to Deposit",
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 5),
                    Text(
                      "₹${currentDebt.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeaderStat(
                            "Lifetime Earnings",
                            "+₹${lifetimeEarnings.toStringAsFixed(0)}",
                            Colors.greenAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. ORDER LIST
              if (filteredDocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Center(
                      child: Text("No history found.",
                          style: TextStyle(color: Colors.grey))),
                )
              else
                ...filteredDocs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String displayOrderId = data['order_id']?.toString() ??
                      "KIRI-${doc.id.substring(0, 6).toUpperCase()}";
                  Timestamp? ts = data['delivered_at'];
                  String dateStr = ts != null
                      ? DateFormat('MMM dd, hh:mm a').format(ts.toDate())
                      : "";

                  double commission =
                      (data['rider_commission'] ?? 0).toDouble();
                  bool isSettled = data['is_settled'] == true;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        child:
                            const Icon(Icons.receipt_long, color: Colors.blue),
                      ),
                      title: Text("Order #$displayOrderId",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateStr),
                          if (isSettled)
                            const Text("Settled ✅",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 10))
                        ],
                      ),
                      trailing: Text(
                        "+ ₹${commission.toStringAsFixed(0)}",
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 50),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}
