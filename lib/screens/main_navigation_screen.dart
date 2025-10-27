import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'premium_home_screen.dart';
import 'projects_screen.dart';
import 'timesheet_screen.dart';
import 'photos_screen.dart';
import 'team_screen.dart';
import 'forms_screen.dart';
import 'analytics_screen.dart';
import 'debug_screen.dart';
import '../services/auth_service.dart';
import '../theme/premium_theme.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _updateIndexFromRoute();
  }

  Future<void> _loadUserRole() async {
    final userRole = await AuthService.getUserRole();
    setState(() {
      _userRole = userRole;
    });
  }

  void _updateIndexFromRoute() {
    final location = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    switch (location) {
      case '/':
      case '/dashboard':
        _currentIndex = 0;
        break;
      case '/projects':
        _currentIndex = 1;
        break;
      case '/timesheet':
        _currentIndex = 2;
        break;
      case '/photos':
        _currentIndex = 3;
        break;
      case '/team':
        // Only allow managers to access team page
        if (_userRole == 'Manager') {
          _currentIndex = 4;
        } else {
          // Redirect non-managers to dashboard
          context.go('/');
          _currentIndex = 0;
        }
        break;
      case '/forms':
        _currentIndex = 5;
        break;
      case '/analytics':
        _currentIndex = 6;
        break;
      default:
        _currentIndex = 0;
    }
  }
  
  final List<Widget> _screens = [
    const PremiumHomeScreen(),
    const ProjectsScreen(),
    const TimesheetScreen(),
    const PhotosScreen(),
    const TeamScreen(),
    const FormsScreen(),
    const AnalyticsScreen(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.business),
      label: 'Projects',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.access_time),
      label: 'TimeSheet',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.photo_camera),
      label: 'Photos',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.people),
      label: 'Team',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard, 'Dashboard'),
                _buildNavItem(1, Icons.business, 'Projects'),
                _buildNavItem(2, Icons.access_time, 'TimeSheet'),
                _buildNavItem(3, Icons.photo_camera, 'Photos'),
                // Only show Team page for managers
                if (_userRole == 'Manager')
                  _buildNavItem(4, Icons.people, 'Team'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        
        // Navigate to the correct route
        switch (index) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/projects');
            break;
          case 2:
            context.go('/timesheet');
            break;
          case 3:
            context.go('/photos');
            break;
          case 4:
            // Only allow managers to navigate to team
            if (_userRole == 'Manager') {
              context.go('/team');
            }
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? PremiumTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? PremiumTheme.primaryColor : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? PremiumTheme.primaryColor : Colors.grey[600],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
