// widgets/bottom_navigation.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';

class BottomNavigationWidget extends StatelessWidget {
  final int currentIndex;
  final Function(int) onItemTapped;

  const BottomNavigationWidget({
    super.key,
    required this.currentIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.1),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            Icons.chat_bubble_outline,
            'Chat',
            0,
          ),
          _buildNavItem(
            context,
            Icons.search_outlined,
            'Search',
            1,
          ),
          _buildNavItem(
            context,
            Icons.person_outline,
            'Profile',
            2,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => _handleNavigation(context, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Icon(
                icon,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // Don't navigate if already on the same page
    if (currentIndex == index) {
      return;
    }

    // Call the callback first - this is important for state management
    onItemTapped(index);

    // Handle navigation based on index
    switch (index) {
      case 0:
        // Chat page - Navigate to messages/home
        _navigateToPage(context, '/messages', '/home');
        break;
      case 1:
        // Search page
        _navigateToPage(context, '/search');
        break;
      case 2:
        // Profile page
        _navigateToPage(context, '/profile');
        break;
    }
  }

  void _navigateToPage(BuildContext context, String primaryRoute, [String? fallbackRoute]) {
    try {
      // Get current route name
      String? currentRoute = ModalRoute.of(context)?.settings.name;
      
      // Don't navigate if already on the target page
      if (currentRoute == primaryRoute || 
          (fallbackRoute != null && currentRoute == fallbackRoute)) {
        return;
      }

      // Try to navigate to primary route
      Navigator.pushReplacementNamed(context, primaryRoute).catchError((error) {
        // If primary route fails, try fallback route
        if (fallbackRoute != null) {
          Navigator.pushReplacementNamed(context, fallbackRoute).catchError((fallbackError) {
            // If both fail, go to root
            Navigator.popUntil(context, (route) => route.isFirst);
          });
        } else {
          // If no fallback, go to root
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      });
    } catch (e) {
      // Fallback navigation - go to root
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }
}

// Alternative: More robust version with route checking
class BottomNavigationWidgetRobust extends StatelessWidget {
  final int currentIndex;
  final Function(int) onItemTapped;
  final Map<int, String> routes;

  const BottomNavigationWidgetRobust({
    super.key,
    required this.currentIndex,
    required this.onItemTapped,
    this.routes = const {
      0: '/messages',
      1: '/search', 
      2: '/profile',
    },
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.1),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            Icons.chat_bubble_outline,
            'Chat',
            0,
          ),
          _buildNavItem(
            context,
            Icons.search_outlined,
            'Search',
            1,
          ),
          _buildNavItem(
            context,
            Icons.person_outline,
            'Profile',
            2,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => _handleNavigation(context, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isActive
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Icon(
                icon,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // Don't navigate if already on the same page
    if (currentIndex == index) {
      return;
    }

    // Call the callback for state management
    onItemTapped(index);

    // Get the target route
    String? targetRoute = routes[index];
    if (targetRoute == null) return;

    // Navigate with proper error handling
    _safeNavigate(context, targetRoute);
  }

  void _safeNavigate(BuildContext context, String route) {
    try {
      String? currentRoute = ModalRoute.of(context)?.settings.name;
      
      // Don't navigate if already on target route
      if (currentRoute == route) return;

      // Use pushReplacementNamed for main navigation
      Navigator.pushReplacementNamed(context, route).catchError((error) {
        debugPrint('Navigation error: $error');
        // Fallback: try to go to root
        if (Navigator.canPop(context)) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      });
    } catch (e) {
      debugPrint('Navigation exception: $e');
      // Last resort: try to go to root
      if (Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }
}