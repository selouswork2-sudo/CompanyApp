import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/database_service.dart';
import '../models/project.dart';
import '../models/plan.dart';
import '../models/pin.dart';
import '../models/plan_image.dart';
import '../models/pin_comment.dart';
import 'job_plans_screen.dart';
import 'pin_detail_screen.dart';

class BuildingDetailScreen extends StatefulWidget {
  final int projectId;

  const BuildingDetailScreen({super.key, required this.projectId});

  @override
  State<BuildingDetailScreen> createState() => _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends State<BuildingDetailScreen> {
  String _selectedMenu = 'Jobs';
  Project? _project;
  bool _isLoading = true;
  List<Plan> _plans = [];
  bool _isLoadingPlans = false;

  final List<MenuItem> _menuItems = [
    MenuItem(icon: Icons.work, title: 'Jobs'),
    MenuItem(icon: Icons.task_alt, title: 'Tasks'),
    MenuItem(icon: Icons.photo_camera, title: 'Photos'),
    MenuItem(icon: Icons.folder, title: 'Files'),
    MenuItem(icon: Icons.people, title: 'People'),
    MenuItem(icon: Icons.settings, title: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProject();
    _loadPlans();
  }

  Future<void> _loadProject() async {
    final maps = await DatabaseService.instance.query(
      'projects',
      where: 'id = ?',
      whereArgs: [widget.projectId],
    );
    if (maps.isNotEmpty) {
      setState(() {
        _project = Project.fromMap(maps.first);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoadingPlans = true;
    });
    final maps = await DatabaseService.instance.query(
      'plans',
      where: 'project_id = ?',
      whereArgs: [widget.projectId],
    );
    setState(() {
      _plans = maps.map((e) => Plan.fromMap(e)).toList();
      _isLoadingPlans = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_project?.name ?? 'Building'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/projects'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddDialog();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF2C2C2E),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1E),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.business, size: 40, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      _project?.name ?? 'Building',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_project?.address != null)
                      Text(
                        _project!.address!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              ..._menuItems.map((item) => Container(
                    color: _selectedMenu == item.title
                        ? const Color(0xFF0A84FF).withOpacity(0.3)
                        : Colors.transparent,
                    child: ListTile(
                      leading: Icon(
                        item.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      selected: _selectedMenu == item.title,
                      onTap: () {
                        setState(() {
                          _selectedMenu = item.title;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  )),
              const Divider(color: Colors.white24, height: 1),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Tasks',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildTaskMenuItem('My tasks', Icons.star, 0),
              _buildTaskMenuItem('Watched tasks', Icons.remove_red_eye, 0),
              _buildTaskMenuItem('All tasks', Icons.apps, 0),
            ],
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildTaskMenuItem(String title, IconData icon, int count) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 15),
      ),
      trailing: count > 0
          ? Text(
              count.toString(),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        // TODO: Implement task filtering
      },
    );
  }

  Widget _buildContent() {
    switch (_selectedMenu) {
      case 'Jobs':
        return _buildJobsList();
      case 'Tasks':
        return _buildTasksList();
      case 'Photos':
        return _buildPhotosList();
      case 'Files':
        return _buildFilesList();
      case 'People':
        return _buildPeopleList();
      case 'Settings':
        return _buildSettingsList();
      default:
        return const Center(child: Text('Select a menu item'));
    }
  }

  Widget _buildJobsList() {
    if (_isLoadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No job numbers yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add a job number',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              // Navigate to job plans screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JobPlansScreen(
                    jobNumber: plan.jobNumber,
                    jobName: plan.name,
                    planId: plan.id!,
                  ),
                ),
              );
            },
            onLongPress: () => _showPlanMenu(plan),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.folder,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.jobNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (plan.name != null && plan.name!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            plan.name!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPlanMenu(Plan plan) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePlan(plan);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlan(Plan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Number'),
        content: Text('Are you sure you want to delete "${plan.jobNumber}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseService.instance.delete('plans', plan.id!);
              if (mounted) {
                _loadPlans();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

         Widget _buildTasksList() {
           // Show all pins from all plans in this project
           return FutureBuilder<List<Map<String, dynamic>>>(
             future: _loadAllPinsForProject(),
             builder: (context, snapshot) {
               if (snapshot.connectionState == ConnectionState.waiting) {
                 return const Center(child: CircularProgressIndicator());
               }

               if (!snapshot.hasData || snapshot.data!.isEmpty) {
                 return Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
                       const SizedBox(height: 16),
                       Text(
                         'No tasks yet',
                         style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                       ),
                       const SizedBox(height: 8),
                       Text(
                         'Create pins on plans to see tasks',
                         style: TextStyle(color: Colors.grey[500]),
                       ),
                     ],
                   ),
                 );
               }

               // Group by status
               final priority1 = snapshot.data!.where((p) => (p['pin'] as Pin).status == 'Priority 1').toList();
               final priority2 = snapshot.data!.where((p) => (p['pin'] as Pin).status == 'Priority 2').toList();
               final priority3 = snapshot.data!.where((p) => (p['pin'] as Pin).status == 'Priority 3').toList();
               final completed = snapshot.data!.where((p) => (p['pin'] as Pin).status == 'Completed').toList();
               final verified = snapshot.data!.where((p) => (p['pin'] as Pin).status == 'Verified').toList();

               return ListView(
                 padding: const EdgeInsets.all(16),
                 children: [
                   if (priority1.isNotEmpty) _buildPriorityGroup('PRIORITY 1', priority1, const Color(0xFFE53935)),
                   if (priority2.isNotEmpty) _buildPriorityGroup('PRIORITY 2', priority2, const Color(0xFFFF9800)),
                   if (priority3.isNotEmpty) _buildPriorityGroup('PRIORITY 3', priority3, const Color(0xFFFFC107)),
                   if (completed.isNotEmpty) _buildPriorityGroup('COMPLETED', completed, const Color(0xFF4CAF50)),
                   if (verified.isNotEmpty) _buildPriorityGroup('VERIFIED', verified, const Color(0xFF03A9F4)),
                 ],
               );
             },
           );
         }

         Future<List<Map<String, dynamic>>> _loadAllPinsForProject() async {
           // Get all plans for this project
           final plans = await DatabaseService.instance.query(
             'plans',
             where: 'project_id = ?',
             whereArgs: [widget.projectId],
           );

           List<Map<String, dynamic>> allPins = [];

           for (var plan in plans) {
             // Get all plan images for this plan
             final planImages = await DatabaseService.instance.query(
               'plan_images',
               where: 'plan_id = ?',
               whereArgs: [plan['id']],
             );

             for (var planImage in planImages) {
               // Get all pins for this plan image
               final pins = await DatabaseService.instance.query(
                 'pins',
                 where: 'plan_image_id = ?',
                 whereArgs: [planImage['id']],
               );

               for (var pin in pins) {
                 allPins.add({
                   'pin': Pin.fromMap(pin),
                   'planImage': PlanImage.fromMap(planImage),
                   'plan': Plan.fromMap(plan),
                 });
               }
             }
           }

           return allPins;
         }

         Widget _buildPriorityGroup(String title, List<Map<String, dynamic>> pins, Color color) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 12),
                 child: Row(
                   children: [
                     Text(
                       '$title (${pins.length})',
                       style: const TextStyle(
                         fontSize: 14,
                         fontWeight: FontWeight.w600,
                         color: Colors.black54,
                       ),
                     ),
                     const SizedBox(width: 8),
                     Expanded(child: Divider(color: Colors.grey[300])),
                   ],
                 ),
               ),
               ...pins.map((data) {
                 final pin = data['pin'] as Pin;
                 final planImage = data['planImage'] as PlanImage;
                 final plan = data['plan'] as Plan;

                 return Card(
                   margin: const EdgeInsets.only(bottom: 8),
                   child: InkWell(
                     onTap: () async {
                       // Navigate to pin detail
                       final result = await Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => PinDetailScreen(
                             pin: pin,
                             planImage: planImage,
                             x: pin.x,
                             y: pin.y,
                           ),
                         ),
                       );
                       if (result == true) {
                         setState(() {}); // Refresh
                       }
                     },
                     child: Padding(
                       padding: const EdgeInsets.all(12),
                       child: Row(
                         children: [
                           Container(
                             width: 40,
                             height: 40,
                             decoration: BoxDecoration(
                               color: color,
                               shape: BoxShape.circle,
                             ),
                             child: Center(
                               child: Text(
                                 '${pin.id}',
                                 style: const TextStyle(
                                   color: Colors.white,
                                   fontSize: 14,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                             ),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   pin.title,
                                   style: const TextStyle(
                                     fontSize: 16,
                                     fontWeight: FontWeight.w600,
                                   ),
                                 ),
                                 const SizedBox(height: 4),
                                 Text(
                                   '#${pin.id} | @${planImage.name} | ${plan.jobNumber}',
                                   style: TextStyle(
                                     fontSize: 12,
                                     color: Colors.grey[600],
                                   ),
                                 ),
                               ],
                             ),
                           ),
                           Icon(Icons.chevron_right, color: Colors.grey[400]),
                         ],
                       ),
                     ),
                   ),
                 );
               }).toList(),
               const SizedBox(height: 8),
             ],
           );
         }

         Widget _buildPhotosList() {
           // Show all photos from all pins in this project
           return FutureBuilder<Map<String, List<PinComment>>>(
             future: _loadAllPhotosForProject(),
             builder: (context, snapshot) {
               if (snapshot.connectionState == ConnectionState.waiting) {
                 return const Center(child: CircularProgressIndicator());
               }

               if (!snapshot.hasData || snapshot.data!.isEmpty) {
                 return Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.photo_camera, size: 64, color: Colors.grey[400]),
                       const SizedBox(height: 16),
                       Text(
                         'No photos yet',
                         style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                       ),
                       const SizedBox(height: 8),
                       Text(
                         'Add photos to pins to see them here',
                         style: TextStyle(color: Colors.grey[500]),
                       ),
                     ],
                   ),
                 );
               }

               // Group photos by date
               final sortedDates = snapshot.data!.keys.toList()..sort((a, b) => b.compareTo(a));

               return ListView.builder(
                 padding: const EdgeInsets.all(16),
                 itemCount: sortedDates.length,
                 itemBuilder: (context, index) {
                   final date = sortedDates[index];
                   final photos = snapshot.data![date]!;

                   return Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Padding(
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         child: Row(
                           children: [
                             Text(
                               '$date (${photos.length})',
                               style: const TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.w600,
                               ),
                             ),
                             const SizedBox(width: 8),
                             Expanded(child: Divider(color: Colors.grey[300])),
                             IconButton(
                               icon: const Icon(Icons.expand_more),
                               onPressed: () {},
                             ),
                           ],
                         ),
                       ),
                       GridView.builder(
                         shrinkWrap: true,
                         physics: const NeverScrollableScrollPhysics(),
                         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                           crossAxisCount: 4,
                           crossAxisSpacing: 4,
                           mainAxisSpacing: 4,
                         ),
                         itemCount: photos.length,
                         itemBuilder: (context, photoIndex) {
                           final photo = photos[photoIndex];
                           return GestureDetector(
                             onTap: () {
                               // Show full image
                               showDialog(
                                 context: context,
                                 builder: (context) => Dialog(
                                   backgroundColor: Colors.black,
                                   child: InteractiveViewer(
                                     child: Image.file(
                                       File(photo.imagePath!),
                                       fit: BoxFit.contain,
                                     ),
                                   ),
                                 ),
                               );
                             },
                             child: Image.file(
                               File(photo.imagePath!),
                               fit: BoxFit.cover,
                               errorBuilder: (context, error, stackTrace) {
                                 return Container(
                                   color: Colors.grey[800],
                                   child: const Icon(Icons.broken_image, color: Colors.white38),
                                 );
                               },
                             ),
                           );
                         },
                       ),
                       const SizedBox(height: 16),
                     ],
                   );
                 },
               );
             },
           );
         }

         Future<Map<String, List<PinComment>>> _loadAllPhotosForProject() async {
           // Get all plans for this project
           final plans = await DatabaseService.instance.query(
             'plans',
             where: 'project_id = ?',
             whereArgs: [widget.projectId],
           );

           Map<String, List<PinComment>> photosByDate = {};

           for (var plan in plans) {
             // Get all plan images for this plan
             final planImages = await DatabaseService.instance.query(
               'plan_images',
               where: 'plan_id = ?',
               whereArgs: [plan['id']],
             );

             for (var planImage in planImages) {
               // Get all pins for this plan image
               final pins = await DatabaseService.instance.query(
                 'pins',
                 where: 'plan_image_id = ?',
                 whereArgs: [planImage['id']],
               );

               for (var pin in pins) {
                 // Get all photos for this pin
                 final comments = await DatabaseService.instance.query(
                   'pin_comments',
                   where: 'pin_id = ? AND type = ?',
                   whereArgs: [pin['id'], 'photo'],
                 );

                 for (var comment in comments) {
                   final pinComment = PinComment.fromMap(comment);
                   final dateKey = _formatDateKey(pinComment.createdAt);
                   
                   if (!photosByDate.containsKey(dateKey)) {
                     photosByDate[dateKey] = [];
                   }
                   photosByDate[dateKey]!.add(pinComment);
                 }
               }
             }
           }

           return photosByDate;
         }

         String _formatDateKey(DateTime date) {
           final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
           return '${months[date.month - 1]} ${date.day}, ${date.year}';
         }

  Widget _buildFilesList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No files yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a file',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No people yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a person',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Settings',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    if (_selectedMenu == 'Jobs') {
      _showAddJobNumberDialog();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Add ${_selectedMenu}'),
          content: Text('Add new ${_selectedMenu.toLowerCase()} functionality coming soon!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showAddJobNumberDialog() {
    showDialog(
      context: context,
      builder: (context) => AddJobNumberDialog(
        projectId: widget.projectId,
        onJobNumberCreated: () {
          _loadPlans();
        },
      ),
    );
  }
}

class MenuItem {
  final IconData icon;
  final String title;

  MenuItem({required this.icon, required this.title});
}

class AddJobNumberDialog extends StatefulWidget {
  final int projectId;
  final VoidCallback onJobNumberCreated;

  const AddJobNumberDialog({
    super.key,
    required this.projectId,
    required this.onJobNumberCreated,
  });

  @override
  State<AddJobNumberDialog> createState() => _AddJobNumberDialogState();
}

class _AddJobNumberDialogState extends State<AddJobNumberDialog> {
  final _jobNumberController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isCreating = false;
  String? _errorText;

  @override
  void dispose() {
    _jobNumberController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _validateAndSave() async {
    final jobNumber = _jobNumberController.text.trim();
    
    // Validate format
    if (jobNumber.isEmpty) {
      setState(() {
        _errorText = 'Job Number cannot be empty';
      });
      return;
    }

    if (!Plan.isValidJobNumber(jobNumber)) {
      setState(() {
        _errorText = 'Invalid format. Use JXXXX.X.X (e.g., J1441.4.1)';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _errorText = null;
    });

    final newPlan = Plan(
      projectId: widget.projectId,
      jobNumber: jobNumber,
      name: _nameController.text.isEmpty ? null : _nameController.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await DatabaseService.instance.insert('plans', newPlan.toMap());
      widget.onJobNumberCreated();
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _isCreating = false;
          _errorText = 'Error creating job number';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Job Number'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _jobNumberController,
              decoration: InputDecoration(
                labelText: 'Job Number',
                hintText: 'JXXXX.X.X (e.g., J1441.4.1)',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (Optional)',
                hintText: 'e.g., Architectural, Civil',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Format: JXXXX.X.X\nExample: J1441.4.1',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _validateAndSave,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

