import 'package:flutter/material.dart';

class ProjectDetailScreen extends StatelessWidget {
  final int projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Details')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text('Project #$projectId Details', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            const Text('Coming soon: 8 modules here'),
          ],
        ),
      ),
    );
  }
}

