  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:pocketbase/pocketbase.dart';
  import 'package:intl/intl.dart';

  final pb = PocketBase('https://congress-stood.pockethost.io/');

  class BookingInfo {
    final String playerName;
    final int duration;
    final DateTime startTime;
    final String recordId;
    final String unitType;
    final int unitNumber;
    final bool isTimeout;

    BookingInfo({
      required this.playerName,
      required this.duration,
      required this.startTime,
      required this.recordId,
      required this.unitType,
      required this.unitNumber,
      this.isTimeout = false,
    });
  }

  class HomePage extends StatefulWidget {

    
    const HomePage({Key? key}) : super(key: key);

    

    @override
    State<HomePage> createState() => _HomePageState();
  }

  class _HomePageState extends State<HomePage> {
    final Map<String, Map<int, BookingInfo?>> _bookings = {};
    Timer? _timer;
    String _selectedTab = 'Games';
    

  Future<void> _showCheckoutDialog(String playerName) async {
  debugPrint('Starting checkout process for: $playerName');

    

    try {
      // Correct filter syntax
      final filter = 'player_name="$playerName" && status="Active"';
      debugPrint('Filter used: $filter');
      
      

      // Fetch active bookings for the player
      final bookings = await pb.collection('bookings').getFullList(filter: filter);

      if (bookings.isEmpty) {
        debugPrint('No active bookings found for: $playerName');
        _showSnackBar('No active booking found for $playerName.');
        return;
      }

      final booking = bookings.first;
      debugPrint('Fetched booking: ${booking.toJson()}');

      // Parse booking data
      final unitType = booking.data['unit_type'] ?? 'Unknown';
      final unitNumber = booking.data['unit_number'] ?? 0;
      final duration = booking.data['duration'] ?? 0;

      final startTimeString = booking.data['start_time'];
      DateTime? startTime;
      if (startTimeString != null && startTimeString.isNotEmpty) {
        try {
          startTime = DateTime.parse(startTimeString).toUtc();
        } catch (e) {
          debugPrint('Error parsing start time: $startTimeString');
          _showSnackBar('Error parsing start time for booking. Please check your data.');
          return;
        }
      }

      // Fetch related food orders using the correct field name
      final foodOrders = await pb.collection('food_orders').getFullList(
        filter: 'bookingId="${booking.id}"', // Replace 'linked_booking' with the actual field name
      );


      // Calculate costs
      final gameCost = duration * 50.0; // Example cost per hour
      final foodCost = foodOrders.fold<double>(0, (sum, order) {
        final quantity = (order.data['quantity'] as num?)?.toInt() ?? 0;
        return sum + (quantity * 10.0); // Example cost per food item
      });

      final totalCost = gameCost + foodCost;

      // Show checkout dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Checkout for $playerName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Unit: $unitType $unitNumber'),
                Text(
                  'Check-in Time: ${startTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(startTime) : 'Unknown'}',
                ),
                Text('Total Playtime: $duration hours'),
                if (foodOrders.isNotEmpty)
                  Text('Food Cost: ₱${foodCost.toStringAsFixed(2)}'),
                Text('Game Cost: ₱${gameCost.toStringAsFixed(2)}'),
                const Divider(),
                Text('Total Bill: ₱${totalCost.toStringAsFixed(2)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _recordSale(playerName, booking, totalCost, foodCost, gameCost, foodOrders);
                  if (mounted) Navigator.of(context).pop();

                  // Show notification
                  _showCustomNotification(
                    context,
                    "Checkout Complete",
                    "$playerName's Checkout is complete!",
                  );

                  // Refresh bookings after successful checkout
                  await _loadBookings(); // Reload bookings

                },
                child: const Text('Checkout'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Error during checkout: $e');
      _showSnackBar('Error during checkout. Please try again.');
    }
  }


  Future<void> _recordSale(
    String playerName, 
    dynamic booking, 
    double totalCost, 
    double foodCost, 
    double gameCost, 
    List<dynamic> foodOrders
    ) async {
    try {
      debugPrint('Recording sale for $playerName: Total Cost = $totalCost');

      // Use the booking ID as the status relation
      

      // Handle food orders gracefully
      String? foodItemRelationId;
      if (foodOrders.isNotEmpty) {
        foodItemRelationId = foodOrders.first.id;
      } else {
        debugPrint('No food orders found. Proceeding with game cost only.');
      }
      // Create a sale record in the "sales" collection
      await pb.collection('sales').create(body: {
        'player_name': playerName,
        'unit_type': booking.data['unit_type'],
        'unit_number': booking.data['unit_number'],
        'start_time': booking.data['start_time'],
        'end_time': DateTime.now().toUtc().toIso8601String(),
        'duration': booking.data['duration'],
        'amount_due': totalCost,
        'payment_method': 'Cash', // Update as needed
        'items': {
          'food_cost': foodCost,
          'game_cost': gameCost,
        },
        'receipt_number': _generateReceiptNumber(),
        'status': booking.id, // Reference to the status relation
        'food_item': foodItemRelationId, // Reference to the food item relation
      });
      debugPrint('Sale record successfully created.');

      // Update the booking status to "Completed"
      await pb.collection('bookings').update(booking.id, body: {
        'status': 'Paid',
      });


      debugPrint('Booking status updated to "Completed".');
    } catch (e) {
      debugPrint('Error recording sale: $e');
      _showSnackBar('Error recording sale. Please try again.');
    }
  }

  String _generateReceiptNumber() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

    @override
    void initState() {
      super.initState();
      _loadBookings();
      _startTimer();
    }

    @override
    void dispose() {
      _timer?.cancel();
      super.dispose();
    }

    void _startTimer() {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _removeExpiredBookings());
    }
    Future<void> _loadUnits() async {
          try {
            final units = await pb.collection('units').getFullList(filter: 'is_active=true');

            setState(() {
              _bookings.clear();
              for (var unit in units) {
                final unitType = unit.data['unit_type'];
                final unitNumber = unit.data['unit_number'];

                if (!_bookings.containsKey(unitType)) {
                  _bookings[unitType] = {};
                }
                _bookings[unitType]![unitNumber] = null; // Initialize as not booked
              }
            });
            debugPrint('Units successfully loaded.');
          } catch (e) {
            debugPrint('Error loading units: $e');
          }
        }


    Future<void> _loadBookings() async {
      try {
      // Fetch both active and timed-out bookings
      final result = await pb.collection('bookings').getFullList(
        filter: 'status = "Active" || status = "Timeout"',
      );


        setState(() {
          _bookings.clear();

          // Initialize units with default values
          _bookings['PS5'] = {for (int i = 1; i <= 5; i++) i: null};
          _bookings['Pool Table'] = {for (int i = 1; i <= 2; i++) i: null};

          for (var record in result) {
            final unitType = record.data['unit_type'] ?? 'Unknown';
            final unitNumber = record.data['unit_number'] ?? 0;
            final playerName = record.data['player_name'] ?? 'Unknown Player';
            final duration = record.data['duration'] ?? 1;
            final startTimeString = record.data['start_time'];
            final status = record.data['status'] ?? 'Active';
            final recordId = record.id ?? '';

            if (unitType.isEmpty || unitNumber == 0 || playerName.isEmpty || recordId == null) {
            continue; // Skip invalid records
          }

            final startTime = (startTimeString != null) 
                ? DateTime.parse(startTimeString).toUtc() 
                : DateTime.now().toUtc();

            _bookings[unitType] ??= {};
            _bookings[unitType]![unitNumber] = BookingInfo(
              playerName: playerName,
              duration: duration,
              startTime: startTime,
              recordId: recordId,
              unitType: unitType,
              unitNumber: unitNumber,
              isTimeout: status == 'Timeout', // Mark as timed-out if status is "Timeout"

            );
          }
        });
      } catch (e) {
        debugPrint('Error loading bookings: $e');
        _showSnackBar('Error loading bookings. Please try again.');
      }
    }

  void _removeExpiredBookings() async {
      final expiredBookings = <BookingInfo>[];

    setState(() {
      _bookings.forEach((unitType, units) {
        units.forEach((unitNumber, booking) {
          if (booking != null && _getRemainingMinutes(booking) <= 0) {
            expiredBookings.add(booking); // Collect expired bookings
            // Mark the unit's status as "Timeout" instead of removing it
            _bookings[unitType]![unitNumber] = BookingInfo(
              playerName: booking.playerName,
              duration: booking.duration,
              startTime: booking.startTime,
              recordId: booking.recordId,
              unitType: booking.unitType,
              unitNumber: booking.unitNumber,
              isTimeout: true, // Indicate timeout status
            );
          }
        });
      });
    });

  // Update the expired bookings in the database
  for (var booking in expiredBookings) {
    try {
      await pb.collection('bookings').update(booking.recordId, body: {
        'status': 'Timeout',
      });
    } catch (e) {
      debugPrint('Error marking booking as timed out: $e');
    }
  }

  // Show notifications for timed-out bookings
  for (var booking in expiredBookings) {
    _showCustomNotification(
      context,
      "Booking Timed Out",
      "The booking for ${booking.playerName} on ${booking.unitType} ${booking.unitNumber} has timed out. Please proceed to checkout.",
    );
  }
}

    int _getRemainingMinutes(BookingInfo booking) {
      final now = DateTime.now().toUtc();
      final totalDurationInMinutes = booking.duration * 60;
      final elapsedMinutes = now.difference(booking.startTime).inMinutes;
      return (totalDurationInMinutes - elapsedMinutes).toInt();
    }

    Future<void> _savePlayerDetails(String playerName, String unitType, int unitNumber, int duration) async {
      try {
        final now = DateTime.now().toUtc();
        final record = await pb.collection('bookings').create(body: {
          'player_name': playerName,
          'unit_type': unitType,
          'unit_number': unitNumber,
          'start_time': now.toIso8601String(),
          'duration': duration,
          'status': 'Active',
        });

        setState(() {
          _bookings[unitType] ??= {};
          _bookings[unitType]![unitNumber] = BookingInfo(
            playerName: playerName,
            duration: duration,
            startTime: now,
            recordId: record.id,
            unitType: unitType,
            unitNumber: unitNumber,
          );
        });
          _showSnackBar('Booking saved successfully!');
      } catch (e) {
        debugPrint('Error saving booking: $e');
        _showSnackBar('Error saving booking. Please try again.');
      }
    }

    void _showPlayerDetailsDialog(String unitType, int unitNumber) {
    showDialog(
      context: context,
      builder: (context) {
        final playerNameController = TextEditingController();
        final durationController = TextEditingController(text: '1');

        return AlertDialog(
          title: Text('Enter Player Details for $unitType $unitNumber'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: playerNameController,
                decoration: const InputDecoration(labelText: 'Player Name'),
              ),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Duration (hours)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Start Booking'),
              onPressed: () async {
                final playerName = playerNameController.text.trim();
                final duration = int.tryParse(durationController.text.trim()) ?? 1;

                if (playerName.isNotEmpty) {
                  await _savePlayerDetails(playerName, unitType, unitNumber, duration);
                  Navigator.of(context).pop();
                } else {
                  _showSnackBar('Please enter player name');
                }
              },
            ),
          ],
        );
      },
    );
  }

    Future<void> _editPlayerDetails(
      String recordId, 
      String newPlayerName, 
      int additionalDuration
    ) async {
      try {
        // Fetch the existing booking record
        final existingBooking = await pb.collection('bookings').getOne(recordId);

        // Update the booking details
        final currentDuration = existingBooking.data['duration'] ?? 0;
        final updatedDuration = currentDuration + additionalDuration;

        await pb.collection('bookings').update(recordId, body: {
          'player_name': newPlayerName,
          'duration': updatedDuration,
        });

        // Update the state to reflect changes
        setState(() {
          _bookings[existingBooking.data['unit_type']]![existingBooking.data['unit_number']] =
              BookingInfo(
            playerName: newPlayerName,
            duration: updatedDuration,
            startTime: DateTime.parse(existingBooking.data['start_time']).toUtc(),
            recordId: recordId,
            unitType: existingBooking.data['unit_type'],
            unitNumber: existingBooking.data['unit_number'],
          );
        });

        _showSnackBar('Player details updated successfully!');
      } catch (e) {
        debugPrint('Error editing player details: $e');
        _showSnackBar('Error editing player details. Please try again.');
      }
    }

    void _showEditPlayerDialog(String unitType, int unitNumber, BookingInfo booking) {
        final playerNameController = TextEditingController(text: booking.playerName);
        final extendDurationController = TextEditingController(text: '0');

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Edit Player Details for $unitType $unitNumber'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: playerNameController,
                    decoration: const InputDecoration(labelText: 'Player Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: extendDurationController,
                    decoration: const InputDecoration(labelText: 'Add Duration (hours)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Save Changes'),
                  onPressed: () async {
                    final newPlayerName = playerNameController.text.trim();
                    final additionalDuration = int.tryParse(extendDurationController.text.trim()) ?? 0;

                    if (newPlayerName.isNotEmpty) {
                      await _editPlayerDetails(booking.recordId, newPlayerName, additionalDuration);
                      Navigator.of(context).pop();
                    } else {
                      _showSnackBar('Please enter a valid player name.');
                    }
                  },
                ),
              ],
            );
          },
        );
      }

      


    Future<void> _showOrderDialog(String foodName) async {

    // Fetch active players

    final activePlayers = _bookings.values.expand((units) {
      return units.values.where((booking) => booking != null).map((booking) => booking!.playerName);
    }).toList();

    if (activePlayers.isEmpty) {
      _showSnackBar('No active players available for ordering.');
      return;
    }


    // Use StatefulBuilder to manage state within the dialog

    String? selectedPlayer = activePlayers.first;
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
            title: Text('Order $foodName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown to select the player
                DropdownButton<String>(
                  value: selectedPlayer,
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPlayer = value;
                    });
                  },
                  items: activePlayers.map((player) {
                    return DropdownMenuItem(
                      value: player,
                      child: Text(player),
                    );
                  }).toList(),
                ),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: const Text('Order'),
                onPressed: () async {
                  final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
          
                  if (selectedPlayer != null && quantity > 0) {
                    await _orderFoodForPlayer(foodName, selectedPlayer!, quantity);
                    Navigator.of(context).pop();
                  } else {
                    _showSnackBar('Invalid selection or quantity');
                  }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Function to handle food orders for players actively playing
  Future<void> _orderFoodForPlayer(String foodName, String playerName, int quantity) async {
    try {
      // Fetch the active booking for the player
      final bookings = await pb.collection('bookings').getFullList(
        filter: 'player_name="$playerName" && status="Active"',
      );

      if (bookings.isEmpty) {
        _showSnackBar('No active booking found for $playerName.');
        return;
      }

      final booking = bookings.first;

      // Add the food order and link it to the active booking
      await pb.collection('food_orders').create(body: {
        'food_item': foodName,
        'player_name': playerName,
        'bookingId': booking.id,
        'quantity': quantity,
        'order_time': DateTime.now().toUtc().toIso8601String(),
      });

      _showSnackBar('$quantity x $foodName ordered for $playerName!');
    } catch (e) {
      debugPrint('Error placing food order: $e');
      _showSnackBar('Error placing food order. Please try again.');
    }
  }


  // Function to display a dialog for ordering food linked to an active player
  void _showOrderDialogForPlayer(String foodName) {
    
    // Fetch active players
    final activePlayers = _bookings.values.expand((units) {
      return units.values.where((booking) => booking != null).map((booking) => booking!.playerName);
    }).toList();

    if (activePlayers.isEmpty) {
      _showSnackBar('No active players available for ordering.');
    return;
  }

  String? selectedPlayer = activePlayers.first;
  final quantityController = TextEditingController(text: '1');

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Order $foodName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: selectedPlayer,
              onChanged: (value) {
                setState(() {
                  selectedPlayer = value;
                });
              },
              items: activePlayers.map((player) {
                return DropdownMenuItem(
                  value: player,
                  child: Text(player),
                );
              }).toList(),
            ),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text('Order'),
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text.trim()) ?? 0;

              if (selectedPlayer != null && quantity > 0) {
                await _orderFoodForPlayer(foodName, selectedPlayer!, quantity);
                Navigator.of(context).pop();
              } else {
                _showSnackBar('Invalid selection or quantity');
              }
            },
          ),
        ],
      );
    },
  );
}

  Future<void> _showBillDialog(String playerName) async {
    try {
      final bookings = await pb.collection('bookings').getFullList(
        filter: 'player_name="$playerName" && status="Active"',
      );
      if (bookings.isEmpty) {
        _showSnackBar('No active bookings found.');
        return;
      }

      final booking = bookings.first;
      final foodOrders = await pb.collection('food_orders').getFullList(
        filter: 'booking_id = "${booking.id}"',
      );

      

      final gameCost = (booking.data['duration'] * 50).toDouble(); // Example rate per hour
      final foodCost = foodOrders.fold<int>(0, (sum, order) {
      return sum + ((order.data['quantity'] as num?)?.toInt() ?? 0) * 10;
    });
      final totalCost = gameCost + foodCost;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Bill for $playerName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Game Cost: \$${gameCost.toStringAsFixed(2)}'),
                Text('Food Cost: \$${foodCost.toStringAsFixed(2)}'),
                Divider(),
                Text('Total: \$${totalCost.toStringAsFixed(2)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await pb.collection('bookings').update(booking.id, body: {
                    'status': 'Completed',
                  });
                  Navigator.of(context).pop();
                  _showSnackBar('Checkout complete!');
                },
                child: const Text('Checkout'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showSnackBar('Error fetching bill details. Try again.');
    }
  }

  void _showSnackBar(String message) {
    debugPrint(message); // Log the message
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCustomNotification(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // Rounded corners
          ),
          contentPadding: const EdgeInsets.all(16.0), // Padding inside the dialog
          backgroundColor: const Color(0xFF2B2B2B), // Dark background
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon at the top
              const Icon(
                Icons.notifications,
                size: 48.0,
                color: Colors.white,
              ),
              const SizedBox(height: 16.0),
              // Title text
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              // Message text
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14.0,
                ),
              ),
              const SizedBox(height: 16.0),
              // Buttons: Agree and Cancel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24, // Cancel button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 151, 3, 3), // Agree button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      // Add action for Agree button here
                    },
                    child: const Text('Agree'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeUnit(String unitType, int unitNumber) async {
      try {
        final units = await pb.collection('Units').getFullList(
          filter: 'unit_type="$unitType" && unit_number=$unitNumber',
        );

        if (units.isNotEmpty) {
          final unitId = units.first.id;
          await pb.collection('units').update(unitId, body: {
            'is_active': false, // Mark unit as inactive
          });
        }

        // Refresh the bookings data from the database
        await _loadUnits();
        debugPrint('Unit successfully removed.');
      } catch (e) {
        debugPrint('Error removing unit: $e');
      }
    }

    void _showRemoveUnitDialog(String unitType, int unitNumber) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Remove Unit $unitType $unitNumber'),
              content: const Text('Are you sure you want to remove this unit?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _removeUnit(unitType, unitNumber);
                    Navigator.pop(context);
                  },
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      }





  @override
  Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final crossAxisCount = (screenWidth >= 1200) ? 4 : (screenWidth >= 800) ? 3 : 2;

  final items = _selectedTab == 'Games' ? _buildGameItems() : _buildFoodItems();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _topMenu(title: '1821 Sportsbar', subTitle: 'Manage Your Bookings'),
            _buildTabs(),
            Expanded(
              child: GridView.count(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1 / 1.2,
                children: items.map((item) => _buildGridItem(item)).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
      onPressed: () => _showAddUnitDialog(), // Show the add unit dialog
      backgroundColor: Colors.deepOrange,
      child: const Icon(Icons.add, color: Colors.white), // Add "+" icon
    ),

    );

    
  }

  List<Map<String, dynamic>> _buildGameItems() {
  return _bookings.entries.expand((entry) {
    return entry.value.entries.map((unit) {
      final booking = unit.value;

      // Determine if the unit is booked and calculate remaining time
      final isBooked = booking != null && _getRemainingMinutes(booking) > 0;
      final isTimeout = (booking != null && booking.isTimeout);
      final remainingMinutes = isBooked ? _getRemainingMinutes(booking) : 0;

      return {
        'image': entry.key == 'PS5' 
          ? 'assets/icons/PS5_Icon.png' 
          : entry.key == 'Pool Table'
            ? 'assets/icons/pool_table.png'
            : 'assets/icons/default_icon.png'
            ,
        // Title is now dynamically constructed from the unit type and number    
        'title': '${entry.key} ${unit.key}',
        'unitType': entry.key,
        'unitNumber': unit.key,
        // Use the exact player name from the database, without prefixing
        'playerName': isBooked ? booking.playerName : 'Available',
        // Show remaining minutes only if the unit is booked
        'duration': isTimeout
            ? 'Timed Out'
            : (isBooked && remainingMinutes > 0)
                ? '$remainingMinutes mins left'
                : '',
        'status': isTimeout ? 'Timeout' : (isBooked ? 'Booked' : 'Available'),        
      };
    });
  }).toList();
}
List<Map<String, dynamic>> _buildFoodItems() {
  return [
    {'image': 'assets/icons/icon-noodles.png', 'title': 'Noodles'},
    {'image': 'assets/icons/icon-burger.png', 'title': 'Burger'},
    {'image': 'assets/icons/icon-desserts.png', 'title': 'Desserts'},
  ];
}


  Widget _buildGridItem(Map<String, dynamic> item) {
  final isFoodsTab = _selectedTab == 'Foods';
  final isTimeout = item['status'] == 'Timeout';
  final isPlayerActive = !isFoodsTab && item['playerName'] != null && item['playerName'] != 'Available';

  final unitType = item['unitType'] ?? ''; // Use unitType directly
  final unitNumber = item['unitNumber'] ?? 0; // Use unitNumber directly
  

  return GestureDetector(
    onTap: () {
      if (isFoodsTab) {
        _showOrderDialog(item['title'] ?? 'Unknown'); // Show food ordering dialog
      } else if (isTimeout) {
        _showCheckoutDialog(item['playerName'] ?? 'Unknown'); // Timeout units proceed to checkout
      } else if (isPlayerActive) {
        _showCheckoutDialog(item['playerName'] ?? 'Unknown'); // Show checkout dialog
      } else {
        _showPlayerDetailsDialog(unitType, unitNumber); // Show booking dialog
      }
    },
    child: Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 10, bottom: 20),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            color: isTimeout
                ? Colors.red.shade900 // Highlight timed-out units in red
                : const Color(0xff1f2029),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: AssetImage(item['image'] ?? 'assets/icons/default_icon.png'),
                      fit: BoxFit.scaleDown,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item['title'] ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              if (!isFoodsTab && isPlayerActive)
                Text(
                  item['playerName'] ?? '',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              if (!isFoodsTab && item['duration'] != null && item['duration'] != '')
                ...[
                  const SizedBox(height: 10),
                  Text(
                    item['duration'] ?? '',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 16,
                    ),
                  ),
                ],
              const SizedBox(height: 10),
              ElevatedButton(
                child: Text(
                  isFoodsTab
                      ? 'Order'
                      : (isTimeout
                          ? 'Checkout'
                          : (isPlayerActive ? 'Checkout' : 'Book')),
                ),
                onPressed: () {
                  if (isFoodsTab) {
                    _showOrderDialog(item['title'] ?? 'Unknown');
                  } else if (isTimeout) {
                    _showCheckoutDialog(item['playerName'] ?? 'Unknown');
                  } else if (isPlayerActive) {
                    _showCheckoutDialog(item['playerName'] ?? 'Unknown');
                  } else {
                    _showPlayerDetailsDialog(unitType, unitNumber);
                  }
                },
              ),
            ],
          ),
        ),
        // Add the IconButton at the top-right corner
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              children: [
                // Remove button (X icon)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    _showRemoveUnitDialog(unitType, unitNumber);
                  },
                ),
                // Edit button (pencil icon)
                if (isPlayerActive)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      _showEditPlayerDialog(
                        unitType,
                        unitNumber,
                        _bookings[unitType]![unitNumber]!, // Pass current booking details
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }







  Widget _topMenu({required String title, required String subTitle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20)),
            Text(subTitle, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          _buildTab(icon: 'assets/icons/PS5_Icon.png', title: 'Games', isActive: _selectedTab == 'Games'),
          _buildTab(icon: 'assets/icons/icon-noodles.png', title: 'Foods', isActive: _selectedTab == 'Foods'),
        ],
      ),
    );
  }

  Widget _buildTab({required String icon, required String title, required bool isActive}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 26),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xff1f2029),
          border: Border.all(
            color: isActive ? Colors.deepOrangeAccent : const Color(0xff1f2029),
            width: 3,
          ),
        ),
        child: Row(
          children: [
            Image.asset(icon, width: 38),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
      ),
    );
  }

  // Add new units dynamically
Future<void> _addUnit(String unitType, int unitCount) async {
  try {
    for (int i = 1; i <= unitCount; i++) {
      // Check if the unit already exists in the database
      final existingUnits = await pb.collection('units').getFullList(
        filter: 'unit_type="$unitType" && unit_number=$i',
      );

      if (existingUnits.isEmpty) {
        // Save the new unit to the database
        await pb.collection('units').create(body: {
          'unit_type': unitType,
          'unit_number': i,
          'is_active': true,
        });
      }
    }

    // Refresh the bookings data from the database
    await _loadUnits();
    debugPrint('Units successfully added.');
  } catch (e) {
    debugPrint('Error adding units: $e');
  }
}

Widget _addUnitButton() {
  return ElevatedButton.icon(
    icon: const Icon(Icons.add),
    label: const Text('Add Unit'),
    onPressed: () => _showAddUnitDialog(),
  );
}

void _showAddUnitDialog() {
  final TextEditingController unitTypeController = TextEditingController();
  final TextEditingController unitCountController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Add New Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: unitTypeController,
              decoration: const InputDecoration(labelText: 'Unit Type (e.g., PS5, Pool Table)'),
            ),
            TextField(
              controller: unitCountController,
              decoration: const InputDecoration(labelText: 'Number of the Unit'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final unitType = unitTypeController.text.trim();
              final unitCount = int.tryParse(unitCountController.text.trim()) ?? 0;
              if (unitType.isNotEmpty && unitCount > 0) {
                _addUnit(unitType, unitCount);
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
}




}

