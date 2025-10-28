import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class BaserowService {
  // Baserow configuration
  static const String _baseUrl = 'http://truenas-scale-1.catfish-census.ts.net:30163/api';
  static const String _token = 'dkgrXhwtp6kFUj4IXYckRPhKDuIri6lb';
  
  static const Map<String, String> _headers = {
    'Authorization': 'Token $_token',
    'Content-Type': 'application/json',
  };

  // Users Table (Table ID: 762)
  static const int _usersTableId = 762;
  
  // Projects Table (Table ID: 753) - Correct table ID
  static const int _projectsTableId = 753;
  
  // Jobs Table (Table ID: 754) - Corrected from 723 to 754
  static const int _jobsTableId = 754;
  
  // Plans Table (Table ID: 755) - Corrected from 724 to 755
  static const int _plansTableId = 755;
  
  // Photos Table (Table ID: 758)
  static const int _photosTableId = 758;
  
  // Pins Table (Table ID: 759)
  static const int _pinsTableId = 759;
  
  /// Get user by username
  static Future<Map<String, dynamic>?> getUser(String username) async {
    final url = '$_baseUrl/database/rows/table/762/?user_data=true&filters=%7B%22filter_type%22%3A%22AND%22%2C%22filters%22%3A%5B%7B%22field%22%3A7287%2C%22type%22%3A%22equal%22%2C%22value%22%3A%22$username%22%7D%5D%7D';
    
    print('🔍 Getting user from URL: $url');
    print('🔑 Using token: ${_token.substring(0, 10)}...');
    
    final response = await http.get(Uri.parse(url), headers: _headers);
    
    print('📡 Response status: ${response.statusCode}');
    print('📡 Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      if (results.isNotEmpty) {
        return results.first as Map<String, dynamic>;
      }
    } else {
      print('❌ Failed to get user: ${response.statusCode}');
    }
    
    return null;
  }

  /// Update user session info
  static Future<void> updateUserSession(String username, Map<String, dynamic> sessionData) async {
    // First get user to find the row ID
    final user = await getUser(username);
    if (user == null) {
      throw Exception('User not found: $username');
    }

    final rowId = user['id'];
    final url = '$_baseUrl/database/rows/table/$_usersTableId/$rowId/';

    // Map session data to Baserow fields
    final updateData = <String, dynamic>{};

    if (sessionData.containsKey('is_active')) {
      updateData['field_7343'] = sessionData['is_active'] ? 'true' : 'false'; // is_active (single line text)
    }
    if (sessionData.containsKey('last_activity')) {
      updateData['field_7344'] = sessionData['last_activity']; // last_activity (date)
    }

    final response = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(updateData),
    );

    if (response.statusCode == 200) {
      print('✅ User session updated successfully');
    } else {
      print('❌ Failed to update user session: ${response.statusCode}');
      throw Exception('Failed to update user session: ${response.statusCode}');
    }
  }

  /// Get all users (for testing)
  static Future<List<Map<String, dynamic>>> getUsers() async {
    final url = '$_baseUrl/database/rows/table/$_usersTableId/';
    
    final response = await http.get(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      print('❌ Failed to get users: ${response.statusCode}');
      return [];
    }
  }

  /// ==================== PROJECT METHODS ====================
  
  static Future<Map<String, dynamic>> createProject(Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_projectsTableId/';
    
    // Map project data to Baserow fields
    final baserowData = {
      'field_7227': data['name'], // Project name - single line text
      'field_7228': data['address'] ?? '', // Address - single line text
      'field_7229': data['status'] ?? 'Active', // Status - single select
    };
    
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200) {
      print('✅ Project created in Baserow');
      return json.decode(response.body);
    } else {
      print('❌ Failed to create project in Baserow: ${response.statusCode}');
      throw Exception('Failed to create project: ${response.statusCode}');
    }
  }

  static Future<void> updateProject(int baserowId, Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_projectsTableId/$baserowId/';
    
    final baserowData = <String, dynamic>{};
    if (data.containsKey('name')) baserowData['field_7227'] = data['name']; // Project name - single line text
    if (data.containsKey('address')) baserowData['field_7228'] = data['address']; // Address - single line text
    if (data.containsKey('status')) baserowData['field_7229'] = data['status']; // Status - single select
    
    final response = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200) {
      print('✅ Project updated in Baserow');
    } else {
      print('❌ Failed to update project in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to update project: ${response.statusCode}');
    }
  }

  static Future<void> deleteProject(int baserowId) async {
    final url = '$_baseUrl/database/rows/table/$_projectsTableId/$baserowId/';
    
    final response = await http.delete(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200 || response.statusCode == 204) {
      print('✅ Project deleted from Baserow');
    } else {
      print('❌ Failed to delete project from Baserow: ${response.statusCode}');
      throw Exception('Failed to delete project: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createJob(Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_jobsTableId/';
    
    // Map job data to Baserow fields
    final baserowData = {
      'field_7237': data['job_number'] ?? '', // Job number
      'field_7238': data['name'] ?? '', // Name
    };
    
    print('🔄 Creating job in Baserow with data: $baserowData');
    
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      print('✅ Job created in Baserow with ID: ${responseData['id']}');
      return responseData;
    } else {
      print('❌ Failed to create job in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to create job: ${response.statusCode}');
    }
  }

  static Future<void> updateJob(int baserowId, Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_jobsTableId/$baserowId/';
    
    // Map job data to Baserow fields
    final baserowData = <String, dynamic>{};
    if (data.containsKey('job_number')) baserowData['field_7237'] = data['job_number'];
    if (data.containsKey('name')) baserowData['field_7238'] = data['name'];
    
    final response = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode != 200) {
      print('❌ Failed to update job in Baserow: ${response.statusCode}');
      throw Exception('Failed to update job: ${response.statusCode}');
    }
    
    print('✅ Job updated in Baserow');
  }

  static Future<void> deleteJob(int baserowId) async {
    final url = '$_baseUrl/database/rows/table/$_jobsTableId/$baserowId/';
    
    final response = await http.delete(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200 || response.statusCode == 204) {
      print('✅ Job deleted from Baserow');
    } else {
      print('❌ Failed to delete job from Baserow: ${response.statusCode}');
      throw Exception('Failed to delete job: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createPlan(Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_plansTableId/';
    
    // Map plan data to Baserow fields
    final baserowData = {
      'field_7242': data['job_id'] ?? '', // Job number
      'field_7244': data['name'] ?? '', // Plan name
      'field_7243': data['image_path'] ?? '', // Image path
      'field_7245': data['created_at'] ?? DateTime.now().toIso8601String(), // Created date
    };
    
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      print('✅ Plan created in Baserow with ID: ${responseData['id']}');
      return responseData;
    } else {
      print('❌ Failed to create plan in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to create plan: ${response.statusCode}');
    }
  }

  static Future<void> updatePlan(int baserowId, Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_plansTableId/$baserowId/';
    
    // Map plan data to Baserow fields
    final baserowData = <String, dynamic>{};
    if (data.containsKey('job_id')) baserowData['field_7242'] = data['job_id'];
    if (data.containsKey('name')) baserowData['field_7244'] = data['name'];
    if (data.containsKey('image_path')) baserowData['field_7243'] = data['image_path'];
    
    final response = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200) {
      print('✅ Plan updated in Baserow');
    } else {
      print('❌ Failed to update plan in Baserow: ${response.statusCode}');
      throw Exception('Failed to update plan: ${response.statusCode}');
    }
  }

  static Future<void> deletePlan(int baserowId) async {
    final url = '$_baseUrl/database/rows/table/$_plansTableId/$baserowId/';
    
    final response = await http.delete(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200 || response.statusCode == 204) {
      print('✅ Plan deleted from Baserow');
    } else {
      print('❌ Failed to delete plan from Baserow: ${response.statusCode}');
      throw Exception('Failed to delete plan: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getProjects() async {
    final url = '$_baseUrl/database/rows/table/$_projectsTableId/';
    
    final response = await http.get(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final projects = List<Map<String, dynamic>>.from(data['results']);
      print('📥 Downloaded ${projects.length} projects from Baserow');
      return projects;
    } else {
      print('❌ Failed to get projects: ${response.statusCode}');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getJobs() async {
    final url = '$_baseUrl/database/rows/table/$_jobsTableId/';
    
    final response = await http.get(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final jobs = List<Map<String, dynamic>>.from(data['results']);
      print('📥 Downloaded ${jobs.length} jobs from Baserow');
      return jobs;
    } else {
      print('❌ Failed to get jobs: ${response.statusCode}');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPlans() async {
    final url = '$_baseUrl/database/rows/table/$_plansTableId/';
    
    final response = await http.get(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final plans = List<Map<String, dynamic>>.from(data['results']);
      print('📥 Downloaded ${plans.length} plans from Baserow');
      return plans;
    } else {
      print('❌ Failed to get plans: ${response.statusCode}');
      return [];
    }
  }

  static String convertStatusFromBaserowFormat(dynamic status) {
    if (status == null) return 'Active';
    if (status is Map) {
      return status['value'] ?? 'Active';
    }
    return status.toString();
  }

  // ==================== PHOTOS CRUD ====================

  /// Create a new photo in Baserow
  static Future<Map<String, dynamic>> createPhoto(Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_photosTableId/';
    
    // Map photo data to Baserow fields
    final baserowData = {
      'field_7260': data['name'] ?? '', // Photo name
      'field_7261': data['plan_id'] ?? '', // Plan ID (as string/job_number)
      'field_7262': data['image_path'] ?? '', // Image path
    };
    
    print('🔄 Creating photo in Baserow with data: $baserowData');
    
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      print('✅ Photo created in Baserow with ID: ${responseData['id']}');
      return responseData;
    } else {
      print('❌ Failed to create photo in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to create photo: ${response.statusCode}');
    }
  }

  /// Update an existing photo in Baserow
  static Future<void> updatePhoto(int baserowId, Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_photosTableId/$baserowId/';
    
    // Map photo data to Baserow fields
    final baserowData = <String, dynamic>{};
    if (data.containsKey('name')) baserowData['field_7260'] = data['name'];
    if (data.containsKey('plan_id')) baserowData['field_7261'] = data['plan_id'];
    if (data.containsKey('image_path')) baserowData['field_7262'] = data['image_path'];
    
    final response = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200) {
      print('✅ Photo updated in Baserow');
    } else {
      print('❌ Failed to update photo in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to update photo: ${response.statusCode}');
    }
  }

  /// Delete a photo from Baserow
  static Future<void> deletePhoto(int baserowId) async {
    final url = '$_baseUrl/database/rows/table/$_photosTableId/$baserowId/';
    
    final response = await http.delete(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200 || response.statusCode == 204) {
      print('✅ Photo deleted from Baserow');
    } else {
      print('❌ Failed to delete photo from Baserow: ${response.statusCode}');
      throw Exception('Failed to delete photo: ${response.statusCode}');
    }
  }

  /// Get all photos from Baserow
  static Future<List<Map<String, dynamic>>> getPhotos() async {
    final url = '$_baseUrl/database/rows/table/$_photosTableId/';
    
    final response = await http.get(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final photos = List<Map<String, dynamic>>.from(data['results']);
      print('📥 Downloaded ${photos.length} photos from Baserow');
      return photos;
    } else {
      print('❌ Failed to get photos: ${response.statusCode}');
      return [];
    }
  }

  // ==================== PINS CRUD ====================

  /// Create a new pin in Baserow
  static Future<Map<String, dynamic>> createPin(Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_pinsTableId/';
    
    // Map pin data to Baserow fields
    final baserowData = {
      'field_7269': data['job_number'] ?? '', // Job number (from plan_images->plans->job_number)
      'field_7270': data['x'] ?? 0.0, // X coordinate
      'field_7271': data['y'] ?? 0.0, // Y coordinate
      'field_7272': data['title'] ?? '', // Title
      'field_7441': data['before_pictures_urls'] ?? '', // Before pictures URLs
      'field_7442': data['during_pictures_urls'] ?? '', // During pictures URLs
      'field_7443': data['after_pictures_urls'] ?? '', // After pictures URLs
    };
    
    print('🔄 Creating pin in Baserow with data: $baserowData');
    
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      print('✅ Pin created in Baserow with ID: ${responseData['id']}');
      return responseData;
    } else {
      print('❌ Failed to create pin in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to create pin: ${response.statusCode}');
    }
  }

  /// Update an existing pin in Baserow
  static Future<void> updatePin(int baserowId, Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_pinsTableId/$baserowId/';
    
    // Map pin data to Baserow fields
    final baserowData = <String, dynamic>{};
    if (data.containsKey('job_number')) baserowData['field_7269'] = data['job_number'];
    if (data.containsKey('x')) baserowData['field_7270'] = data['x'];
    if (data.containsKey('y')) baserowData['field_7271'] = data['y'];
    if (data.containsKey('title')) baserowData['field_7272'] = data['title'];
    if (data.containsKey('before_pictures_urls')) baserowData['field_7441'] = data['before_pictures_urls'] ?? '';
    if (data.containsKey('during_pictures_urls')) baserowData['field_7442'] = data['during_pictures_urls'] ?? '';
    if (data.containsKey('after_pictures_urls')) baserowData['field_7443'] = data['after_pictures_urls'] ?? '';
    
    final response = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200) {
      print('✅ Pin updated in Baserow');
    } else {
      print('❌ Failed to update pin in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to update pin: ${response.statusCode}');
    }
  }

  /// Delete a pin from Baserow
  static Future<void> deletePin(int baserowId) async {
    final url = '$_baseUrl/database/rows/table/$_pinsTableId/$baserowId/';
    
    final response = await http.delete(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200 || response.statusCode == 204) {
      print('✅ Pin deleted from Baserow');
    } else {
      print('❌ Failed to delete pin from Baserow: ${response.statusCode}');
      throw Exception('Failed to delete pin: ${response.statusCode}');
    }
  }

  /// Get all pins from Baserow
  static Future<List<Map<String, dynamic>>> getPins() async {
    final url = '$_baseUrl/database/rows/table/$_pinsTableId/';
    
    final response = await http.get(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final pins = List<Map<String, dynamic>>.from(data['results']);
      print('📥 Downloaded ${pins.length} pins from Baserow');
      return pins;
    } else {
      print('❌ Failed to get pins: ${response.statusCode}');
      return [];
    }
  }

  // ==================== FILE UPLOAD ====================

  /// Upload a single file to Baserow and return the URL
  static Future<String?> uploadFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist: $filePath');
        return null;
      }

      final url = '$_baseUrl/user-files/upload-file/';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add authorization header
      request.headers['Authorization'] = 'Token $_token';
      
      // Add file
      final fileBytes = await file.readAsBytes();
      final fileName = filePath.split(Platform.pathSeparator).last;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      print('📤 Uploading file to Baserow: $fileName');
      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseData);
        final uploadedUrl = data['url'] as String?;
        print('✅ File uploaded successfully: $uploadedUrl');
        return uploadedUrl;
      } else {
        print('❌ Failed to upload file: ${response.statusCode}');
        print('❌ Response: $responseData');
        return null;
      }
    } catch (e) {
      print('❌ Error uploading file: $e');
      return null;
    }
  }

  /// Upload multiple files and return comma-separated URLs
  static Future<String?> uploadMultipleFiles(List<String> filePaths) async {
    final urls = <String>[];
    
    for (final filePath in filePaths) {
      final url = await uploadFile(filePath);
      if (url != null) {
        urls.add(url);
      }
    }
    
    if (urls.isEmpty) return null;
    return urls.join(',');
  }
}