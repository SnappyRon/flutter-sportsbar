// import 'package:flutter/material.dart';
// import 'package:pocketbase/pocketbase.dart';

// // PocketBase instance
// final pb = PocketBase('https://congress-stood.pockethost.io/');

// class FoodOrderPage extends StatefulWidget {
//   const FoodOrderPage({Key? key}) : super(key: key);

//   @override
//   _FoodOrderPageState createState() => _FoodOrderPageState();
// }

// class _FoodOrderPageState extends State<FoodOrderPage> {
//   final List<Map<String, String>> foodItems = [
//     {'image': 'assets/icons/icon-noodles.png', 'title': 'Noodles'},
//     {'image': 'assets/icons/icon-burger.png', 'title': 'Burger'},
//     {'image': 'assets/icons/icon-pizza.png', 'title': 'Pizza'},
//     {'image': 'assets/icons/icon-drinks.png', 'title': 'Drinks'},
//     {'image': 'assets/icons/icon-fries.png', 'title': 'Fries'},
//     {'image': 'assets/icons/icon-icecream.png', 'title': 'Ice Cream'},
//   ];

//   // Save food order to PocketBase
//   Future<void> _saveFoodOrder(String foodItem, String playerName, int quantity) async {
//     try {
//       DateTime now = DateTime.now().toUtc();

//       await pb.collection('food_orders').create(body: {
//         'food_item': foodItem,
//         'player_name': playerName,
//         'quantity': quantity,
//         'order_time': now.toIso8601String(),
//         'status': 'Pending',
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Order for $foodItem saved successfully!')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error saving food order: $e')),
//       );
//     }
//   }

//   // Show dialog for ordering
//   void _showFoodOrderDialog(String foodItem) {
//     TextEditingController playerNameController = TextEditingController();
//     TextEditingController quantityController = TextEditingController(text: '1');

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('Order $foodItem'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 controller: playerNameController,
//                 decoration: const InputDecoration(labelText: 'Player Name'),
//               ),
//               TextField(
//                 controller: quantityController,
//                 decoration: const InputDecoration(labelText: 'Quantity'),
//                 keyboardType: TextInputType.number,
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               child: const Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: const Text('Order'),
//               onPressed: () {
//                 String playerName = playerNameController.text.trim();
//                 int quantity = int.tryParse(quantityController.text.trim()) ?? 1;

//                 if (playerName.isNotEmpty) {
//                   _saveFoodOrder(foodItem, playerName, quantity);
//                   Navigator.of(context).pop();
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Please enter a player name')),
//                   );
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     int crossAxisCount = screenWidth >= 1200
//         ? 4
//         : screenWidth >= 800
//             ? 3
//             : 2;

//     return Scaffold(
//       backgroundColor: const Color(0xff121212),
//       appBar: AppBar(
//         title: const Text("Foods"),
//         backgroundColor: const Color(0xff1f2029),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: GridView.count(
//           crossAxisCount: crossAxisCount,
//           childAspectRatio: (1 / 1.2),
//           children: foodItems.map((item) {
//             return _foodItem(
//               image: item['image']!,
//               title: item['title']!,
//               status: "Available", // Placeholder status
//               onTap: () {
//                 _showFoodOrderDialog(item['title']!);
//               },
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }

//   Widget _foodItem({
//     required String image,
//     required String title,
//     required String status,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 20),
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(18),
//           color: const Color(0xff1f2029),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             AspectRatio(
//               aspectRatio: 16 / 9,
//               child: Container(
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(16),
//                   image: DecorationImage(
//                     image: AssetImage(image),
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               title,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 14,
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               status,
//               style: const TextStyle(
//                 color: Colors.white54,
//                 fontSize: 12,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
