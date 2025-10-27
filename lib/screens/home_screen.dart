import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Pro'),
        backgroundColor: const Color(0xFF2C2C2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş Geldiniz!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (user != null) ...[
                      Text('Ad: ${user.name}'),
                      Text('Email: ${user.email}'),
                      Text('Rol: ${_getRoleText(user.role)}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Quick Actions
            Text(
              'Hızlı İşlemler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Action Buttons
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    context,
                    'Projeler',
                    Icons.folder,
                    Colors.blue,
                    () {
                      // TODO: Navigate to projects
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Projeler sayfası yakında!')),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    'İşler',
                    Icons.work,
                    Colors.green,
                    () {
                      // TODO: Navigate to jobs
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('İşler sayfası yakında!')),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    'Planlar',
                    Icons.architecture,
                    Colors.orange,
                    () {
                      // TODO: Navigate to plans
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Planlar sayfası yakında!')),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    'Ayarlar',
                    Icons.settings,
                    Colors.grey,
                    () {
                      // TODO: Navigate to settings
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ayarlar sayfası yakında!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.manager:
        return 'Manager';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.technician:
        return 'Technician';
    }
  }
}
