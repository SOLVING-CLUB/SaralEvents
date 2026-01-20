import 'package:flutter/material.dart';
import '../../core/ui/app_icons.dart';
import '../dashboard/dashboard_screen.dart';
import '../orders/orders_screen.dart';
import '../wallet/wallet_screen.dart';
import '../services/services_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;
  DateTime? _lastBackPress;

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _tabs = [];

  @override
  void initState() {
    super.initState();
    _tabs.addAll([
      DashboardScreen(onNavigateToTab: _changeTab),
      OrdersScreen(),
      WalletScreen(),
      ServicesScreen(),
      ProfileScreen(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If we're not on the home tab, go to home tab
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return false; // Don't pop the route
        }
        
        // If we're on home tab, check for double tap to exit
        final now = DateTime.now();
        if (_lastBackPress == null || 
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return false; // Don't pop the route
        }
        
        // Double tap detected, allow exit
        return true;
      },
      child: Scaffold(
        body: _tabs[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
          items: [
            BottomNavigationBarItem(
              icon: SvgIcon(AppIcons.homeLineSvg, size: 22),
              activeIcon: SvgIcon(AppIcons.homeSolidSvg, size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: SvgIcon(AppIcons.ordersLineSvg, size: 22),
              activeIcon: SvgIcon(AppIcons.ordersSolidSvg, size: 22),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined, size: 22),
              activeIcon: Icon(Icons.account_balance_wallet, size: 24),
              label: 'Wallet',
            ),
            BottomNavigationBarItem(
              icon: SvgIcon(AppIcons.catalogLineSvg, size: 22),
              activeIcon: SvgIcon(AppIcons.catalogSolidSvg, size: 20),
              label: 'Catalog',
            ),
            BottomNavigationBarItem(
              icon: SvgIcon(AppIcons.vendorLineSvg, size: 22),
              activeIcon: SvgIcon(AppIcons.vendorSvg, size: 24, color: Theme.of(context).colorScheme.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}


