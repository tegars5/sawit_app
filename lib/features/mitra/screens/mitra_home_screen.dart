import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/services/auth_service.dart';
import 'product_list_screen.dart';
import 'order_list_screen.dart';
import 'profile_screen.dart';

class MitraHomeScreen extends StatefulWidget {
  const MitraHomeScreen({super.key});

  @override
  State<MitraHomeScreen> createState() => _MitraHomeScreenState();
}

class _MitraHomeScreenState extends State<MitraHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ProductListScreen(),
    const OrderListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
