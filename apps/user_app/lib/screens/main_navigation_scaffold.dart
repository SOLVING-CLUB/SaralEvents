import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'planning_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';
import 'invitations_list_screen.dart';
import '../widgets/wishlist_manager.dart';
import '../core/wishlist_notifier.dart';
import '../checkout/checkout_state.dart';
import '../checkout/flow.dart';
import 'package:provider/provider.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  // Orders tab removed from bottom navigation; it is now accessible from the
  // Profile screen menu. Invitations moved from Profile to bottom nav.
  final List<Widget> _tabs = const [
    HomeScreen(),
    PlanningScreen(),
    InvitationsListScreen(),
    WishlistScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return WishlistManager(
      child: Scaffold(
        appBar: null,
        body: _tabs[_currentIndex],
        floatingActionButton: Consumer<CheckoutState>(
          builder: (context, checkout, _) {
            final count = checkout.items.length;
            if (count == 0) return const SizedBox.shrink();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton.extended(
                  onPressed: () {
                    if (checkout.items.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CheckoutFlow(
                          // initialItem is not used inside the flow, but required by ctor
                          initialItem: checkout.items.first,
                        ),
                      ),
                    );
                  },
                  backgroundColor: const Color(0xFFFDBB42),
                  foregroundColor: Colors.black87,
                  icon: const Icon(Icons.shopping_cart),
                  label: Text('Cart ($count)'),
                ),
                // Small badge in the top-right of the FAB
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: ListenableBuilder(
          listenable: WishlistNotifier.instance,
          builder: (context, _) {
            return BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
              selectedItemColor: const Color(0xFFFDBB42),
              unselectedItemColor: Colors.grey.shade600,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  activeIcon: Icon(Icons.home, color: Color(0xFFFDBB42)),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event_note),
                  activeIcon: Icon(Icons.event_note, color: Color(0xFFFDBB42)),
                  label: 'Planning',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.card_giftcard),
                  activeIcon: Icon(Icons.card_giftcard, color: Color(0xFFFDBB42)),
                  label: 'Invitations',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_border),
                  activeIcon: Icon(Icons.favorite, color: Color(0xFFFDBB42)),
                  label: 'Wishlist',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  activeIcon: Icon(Icons.person, color: Color(0xFFFDBB42)),
                  label: 'Profile',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
