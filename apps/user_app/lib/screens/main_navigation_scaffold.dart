import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'planning_screen.dart';
import 'profile_screen.dart';
import 'wishlist_screen.dart';
import 'invitations_list_screen.dart';
import '../widgets/wishlist_manager.dart';
import '../core/wishlist_notifier.dart';
import '../checkout/checkout_state.dart';
import '../checkout/booking_flow.dart';
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
      child: WillPopScope(
        onWillPop: () async {
          // If we are not on the Home tab, go to Home instead of closing the app
          if (_currentIndex != 0) {
            setState(() {
              _currentIndex = 0;
            });
            return false; // prevent app from popping
          }
          // Already on Home → allow normal back behaviour (app can close)
          return true;
        },
        child: Scaffold(
        appBar: null,
        body: _tabs[_currentIndex],
        floatingActionButton: Consumer<CheckoutState>(
          builder: (context, checkout, _) {
            // Prevent rebuilds from affecting navigation stack
            // Only rebuild the FAB, not the entire scaffold
            final count = checkout.items.length;
            debugPrint('🛒 MainNavigationScaffold: Cart has $count item(s)');
            // Hide cart button on profile page (index 4)
            if (count == 0 || _currentIndex == 4) {
              if (count == 0) {
                debugPrint('   → Hiding cart button: cart is empty');
              } else {
                debugPrint('   → Hiding cart button: on profile page');
              }
              return const SizedBox.shrink();
            }
            debugPrint('   → Showing cart button with $count item(s)');
            return Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton.extended(
                  onPressed: () {
                    if (checkout.items.isEmpty) return;
                    // Navigate to clean booking flow
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BookingFlow(),
                      ),
                    );
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
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
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home),
                  activeIcon: Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.event_note),
                  activeIcon: Icon(Icons.event_note, color: Theme.of(context).colorScheme.primary),
                  label: 'Planning',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.card_giftcard),
                  activeIcon: Icon(Icons.card_giftcard, color: Theme.of(context).colorScheme.primary),
                  label: 'Invitations',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.favorite_border),
                  activeIcon: Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary),
                  label: 'Wishlist',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person),
                  activeIcon: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                  label: 'Profile',
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }
}
