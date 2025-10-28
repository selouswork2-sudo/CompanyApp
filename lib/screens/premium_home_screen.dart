import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/premium_theme.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'timesheet_screen.dart';
import 'login_screen.dart';
import 'debug_screen.dart';

class PremiumHomeScreen extends StatefulWidget {
  const PremiumHomeScreen({super.key});

  @override
  State<PremiumHomeScreen> createState() => _PremiumHomeScreenState();
}

class _PremiumHomeScreenState extends State<PremiumHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  
  String? _username;
  String? _userRole;
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _initializeSync();
    
    _animationController = AnimationController(
      duration: PremiumTheme.slowAnimation,
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: PremiumTheme.premiumCurve,
    ));
    
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: PremiumTheme.premiumCurve,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await AuthService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _username = userInfo['username'];
      _userRole = userInfo['userRole'];
      _name = userInfo['username']; // show username as primary
    });
  }

  Future<void> _initializeSync() async {
    // Check if sync is needed when app starts
    await SyncService.checkAndSyncIfNeeded();
  }

  IconData _getUserRoleIcon() {
    switch (_userRole?.toLowerCase()) {
      case 'manager':
        return Icons.manage_accounts;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'supervisor':
        return Icons.supervisor_account;
      case 'technician':
        return Icons.engineering;
      case 'worker':
        return Icons.construction;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor() {
    switch (_userRole?.toLowerCase()) {
      case 'manager':
        return const Color(0xFF059669); // Green
      case 'admin':
        return const Color(0xFFDC2626); // Red
      case 'supervisor':
        return const Color(0xFF7C3AED); // Purple
      case 'technician':
        return const Color(0xFF0891B2); // Blue
      case 'worker':
        return const Color(0xFFD97706); // Orange
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateWithHaptic(String route) {
    HapticFeedback.lightImpact();
    context.go(route);
  }

  void _navigateWithHapticAndAnimation(String route) {
    HapticFeedback.mediumImpact();
    _animationController.reverse().then((_) {
      context.go(route);
    });
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      HapticFeedback.mediumImpact();
      await AuthService.logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFE2E8F0),
              Color(0xFFCBD5E1),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width > 1200 ? 48.0 : 24.0,
                      vertical: 24.0,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width > 1200 ? 1400 : double.infinity,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          SizedBox(height: MediaQuery.of(context).size.width > 1200 ? 48 : 40),
                          _buildWelcomeSection(),
                          SizedBox(height: MediaQuery.of(context).size.width > 1200 ? 48 : 40),
                          // Sync status widget removed as requested
                          _buildModulesGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 0 : 24, 
        vertical: 16,
      ),
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // User Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getRoleColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getUserRoleIcon(),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username ?? 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userRole ?? 'User',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _getRoleColor(),
                  ),
                ),
              ],
            ),
          ),
          // Logout button
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.logout,
                color: Colors.red[600],
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getWelcomeMessage(),
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  String _getWelcomeMessage() {
    switch (_userRole?.toLowerCase()) {
      case 'manager':
        return 'Ready to oversee your projects and team?';
      case 'admin':
        return 'System administration dashboard ready.';
      case 'supervisor':
        return 'Time to supervise and coordinate work.';
      case 'technician':
        return 'Let\'s get technical and solve problems!';
      case 'worker':
        return 'Ready to tackle today\'s tasks?';
      default:
        return 'Ready to manage your projects?';
    }
  }

  Widget _buildModulesGrid() {
    final modules = [
      _ModuleData(
        icon: Icons.business_center,
        title: 'Projects',
        subtitle: 'Manage buildings & sites',
        gradient: PremiumTheme.primaryGradient,
        route: '/projects',
        color: PremiumTheme.primaryColor,
      ),
      _ModuleData(
        icon: Icons.access_time_filled,
        title: 'TimeSheet',
        subtitle: 'Track work hours',
        gradient: PremiumTheme.secondaryGradient,
        route: '/timesheet',
        color: PremiumTheme.accentColor,
      ),
      _ModuleData(
        icon: Icons.assignment,
        title: 'Forms',
        subtitle: 'Inspections & reports',
        gradient: PremiumTheme.accentGradient,
        route: '/forms',
        color: PremiumTheme.warningColor,
      ),
      _ModuleData(
        icon: Icons.analytics,
        title: 'Analytics',
        subtitle: 'Insights & metrics',
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        route: '/analytics',
        color: PremiumTheme.successColor,
      ),
      _ModuleData(
        icon: Icons.photo_camera,
        title: 'Photos',
        subtitle: 'Project documentation',
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        ),
        route: '/photos',
        color: const Color(0xFF8B5CF6),
      ),
      _ModuleData(
        icon: Icons.people,
        title: 'Team',
        subtitle: 'Manage team members',
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        route: '/team',
        color: const Color(0xFFF59E0B),
      ),
    ];

    // Get screen width to determine responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    
    int crossAxisCount;
    double childAspectRatio;
    double spacing;
    
    if (isDesktop) {
      crossAxisCount = 3; // 3 columns on desktop
      childAspectRatio = 1.2; // Wider cards
      spacing = 24;
    } else if (isTablet) {
      crossAxisCount = 2; // 2 columns on tablet
      childAspectRatio = 1.1;
      spacing = 20;
    } else {
      crossAxisCount = 2; // 2 columns on mobile
      childAspectRatio = 0.8; // Much taller cards to fit content
      spacing = 16;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        return _buildModuleCard(modules[index], index);
      },
    );
  }

  Widget _buildModuleCard(_ModuleData module, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: () => _navigateWithHaptic(module.route),
            child: Container(
              decoration: BoxDecoration(
                gradient: module.gradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: module.color.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        module.icon,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      module.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      module.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

}

class _ModuleData {
  final IconData icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final String route;
  final Color color;

  _ModuleData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.route,
    required this.color,
  });
}
