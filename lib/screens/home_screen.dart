import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'timesheet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.secondaryBlue,
              AppTheme.primaryBlue.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo & Title Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.business,
                          size: 32,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Company Field App',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Professional Project Management',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Welcome Text
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select a module to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Main Buttons Grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildModuleCard(
                        context,
                        icon: Icons.business,
                        title: 'Projects',
                        subtitle: 'Manage buildings',
                        color: AppTheme.accentOrange,
                        onTap: () => context.go('/projects'),
                      ),
                      _buildModuleCard(
                        context,
                        icon: Icons.access_time,
                        title: 'TimeSheet',
                        subtitle: 'Track hours',
                        color: AppTheme.success,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TimesheetScreen(),
                            ),
                          );
                        },
                      ),
                      _buildModuleCard(
                        context,
                        icon: Icons.description,
                        title: 'Forms',
                        subtitle: 'Inspections',
                        color: AppTheme.warning,
                        onTap: () {
                          // TODO: Navigate to forms
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Forms coming soon!')),
                          );
                        },
                      ),
                      _buildModuleCard(
                        context,
                        icon: Icons.bar_chart,
                        title: 'Reports',
                        subtitle: 'Analytics',
                        color: AppTheme.info,
                        onTap: () {
                          // TODO: Navigate to reports
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reports coming soon!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Version & Settings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Settings
                      },
                      icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
                      label: const Text(
                        'Settings',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

