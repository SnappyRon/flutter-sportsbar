import 'package:flutter/material.dart';
import 'package:flutter_application_1/TransactionsPage.dart';
import 'package:flutter_application_1/home.dart';
import 'package:flutter_application_1/login_page.dart';

void main() {ErrorWidget.builder = (FlutterErrorDetails details) {
    return Center(
      child: Text(
        'Error: ${details.exception}',
        style: TextStyle(color: Colors.red),
      ),
    );
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eighteen 21 Sportsbar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key,);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String pageActive = 'Home';

  _pageView() {
    switch (pageActive) {
      case 'Home':
        return const HomePage();
      case 'Transactions':
        return const TransactionsPage();
      case 'Menu':
        return Container();
      case 'Promos':
        return Container();
      case 'Settings':
        return Container();
      default:
        return const HomePage();
    }
  }
  _setPage(String page) {
    setState(() {
      pageActive = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1f2029),
      body: Row(
        children: [
          Container(
            width: 90,
            padding: const EdgeInsets.only(top: 24, right: 12, left: 12),
            height: MediaQuery.of(context).size.height,
            child: _sideMenu(),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 24, right: 12),
              padding: const EdgeInsets.only(top: 12, right: 12, left: 12),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12)),
                color: Color(0xff17181f),
              ),
              child: _pageView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideMenu() {
    return Column(children: [
      _logo(),
      const SizedBox(height: 20),
      Expanded(
        child: ListView(
          children: [
            _itemMenu(
              menu: 'Home',
              icon: Icons.rocket_sharp,
            ),

            _itemMenu(
              menu: 'Transactions',
              icon: Icons.history_toggle_off_rounded,
            ),


            // _itemMenu(
            //   menu: 'Menu',
            //   icon: Icons.format_list_bulleted_rounded,
            // ),
            
            // _itemMenu(
            //   menu: 'Promos',
            //   icon: Icons.discount_outlined,
            // ),
            // _itemMenu(
            //   menu: 'Settings',
            //   icon: Icons.sports_soccer_outlined,
            // ),
            _logoutItem(
              menu: 'Logout',
              icon: Icons.logout,
            ),
          ],
        ),
      ),
    ]);
  }

  // Add a new _logoutItem method
Widget _logoutItem({required String menu, required IconData icon}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: GestureDetector(
      onTap: () => _logout(), // Call the logout function
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent, // No active state for logout
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.slowMiddle,
          child: Column(
            children: [
              Icon(
                icon,
                color: Colors.white,
              ),
              const SizedBox(height: 5),
              Text(
                menu,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Define the logout method
void _logout() {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const LoginPage()),
    (route) => false, // Remove all routes and navigate to LoginPage
  );
}


  Widget _logo() {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.transparent, // Remove the orange background
        ),
        child: Image.asset(
          'assets/icons/1821 Sportsbar.jpg', // New logo path
          width: 40, // Adjusted width for icon size
          height: 40, // Adjusted height for icon size
          fit: BoxFit.contain, // Ensure the image is properly scaled
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        '1821 Sportsbar',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10, // Slightly increased font size for better readability
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

  Widget _itemMenu({required String menu, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: GestureDetector(
        onTap: () => _setPage(menu),
        child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: pageActive == menu
                    ? Colors.deepOrangeAccent
                    : Colors.transparent,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.slowMiddle,
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    menu,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            )),
      ),
    );
  }
}