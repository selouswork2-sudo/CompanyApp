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

  // Table IDs
  static const int _usersTableId = 788;
  static const int _projectsTableId = 783;
  static const int _jobsTableId = 785;
  static const int _planImagesTableId = 786;
  static const int _pinsTableId = 787;

  // Projects field IDs
  static const int _fieldName = 7454;
  static const int _fieldAddress = 7455;
  static const int _fieldStatus = 7456;
  static const int _fieldCreatedBy = 7457;
  static const int _fieldCreatedAt = 7458;
  static const int _fieldUpdatedAt = 7459;
  static const int _fieldUuid = 7469;

  // Jobs field IDs
  static const int _jobNumber = 7463;
  static const int _jobName = 7464;
  static const int _jobProjectId = 7465;
  static const int _jobCreatedBy = 7466;
  static const int _jobCreatedAt = 7467;
  static const int _jobUpdatedAt = 7468;
  static const int _jobUuid = 7487;

  // Plan Images field IDs
  static const int _planJobNumber = 7470;
  static const int _planImagePath = 7471;
  static const int _planName = 7472;
  static const int _planCreatedBy = 7473;
  static const int _planCreatedAt = 7474;
  static const int _planUpdatedAt = 7475;
  static const int _planUuid = 7488;

  // Pins field IDs (updated with correct field IDs from Baserow)
  static const int _pinJobNumber = 7476;  // job_number (field 7476)
  static const int _pinPlanName = 7477;   // plan_name (field 7477)
  static const int _pinX = 7478;          // x (field 7478)
  static const int _pinY = 7479;          // y (field 7479)
  static const int _pinTitle = 7480;      // title (field 7480)
  static const int _pinBeforePictures = 7481;  // before_pictures (field 7481)
  static const int _pinDuringPictures = 7482;  // during_pictures (field 7482)
  static const int _pinAfterPictures = 7483;   // after_pictures (field 7483)
  static const int _pinCreatedBy = 7484;        // created_by (field 7484)
  static const int _pinCreatedAt = 7485;        // created_at (field 7485)
  static const int _pinUpdatedAt = 7486;        // updated_at (field 7486)
  static const int _pinUuid = 7489;             // uuid (field 7489)

  // Users field IDs
  static const int _userUsername = 7490;
  static const int _userPassword = 7495;
  static const int _userEmail = 7491;
  static const int _userRole = 7492;
  static const int _userCreatedAt = 7493;
  static const int _userUpdatedAt = 7494;
  static const int _userUuid = 7496;

  // ==================== PROJECTS CRUD ====================

  static Future<Map<String, dynamic>> createProject(Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_projectsTableId/';
    
    final baserowData = {
      'field_$_fieldName': data['name'] ?? '',
      'field_$_fieldAddress': data['address'] ?? '',
      'field_$_fieldStatus': data['status'] ?? 'Active',
      'field_$_fieldCreatedBy': data['created_by'] ?? '',
      'field_$_fieldCreatedAt': data['created_at'] ?? DateTime.now().toIso8601String(),
      'field_$_fieldUpdatedAt': data['updated_at'] ?? DateTime.now().toIso8601String(),
    };
    
    print('🔄 Creating project in Baserow with data: $baserowData');
    
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      print('✅ Project created in Baserow with ID: ${responseData['id']}');
      return responseData;
    } else {
      print('❌ Failed to create project in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to create project: ${response.statusCode}');
    }
  }

  static Future<void> updateProject(int baserowId, Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_projectsTableId/$baserowId/';
    
    final baserowData = <String, dynamic>{};
    if (data.containsKey('name')) baserowData['field_$_fieldName'] = data['name'];
    if (data.containsKey('address')) baserowData['field_$_fieldAddress'] = data['address'];
    if (data.containsKey('status')) baserowData['field_$_fieldStatus'] = data['status'];
    if (data.containsKey('updated_at')) baserowData['field_$_fieldUpdatedAt'] = data['updated_at'];
    
    print('🔄 Updating project in Baserow with ID: $baserowId');
    
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

  // ==================== JOBS CRUD ====================

  static Future<Map<String, dynamic>> createJob(Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_jobsTableId/';
    
    final baserowData = {
      'field_$_jobNumber': data['job_number'] ?? '',
      'field_$_jobName': data['name'] ?? '',
      'field_$_jobProjectId': data['project_id'] ?? '',
      'field_$_jobCreatedBy': data['created_by'] ?? '',
      'field_$_jobCreatedAt': data['created_at'] ?? DateTime.now().toIso8601String(),
      'field_$_jobUpdatedAt': data['updated_at'] ?? DateTime.now().toIso8601String(),
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
    
    final baserowData = <String, dynamic>{};
    if (data.containsKey('job_number')) baserowData['field_$_jobNumber'] = data['job_number'];
    if (data.containsKey('name')) baserowData['field_$_jobName'] = data['name'];
    if (data.containsKey('project_id')) baserowData['field_$_jobProjectId'] = data['project_id'];
    if (data.containsKey('updated_at')) baserowData['field_$_jobUpdatedAt'] = data['updated_at'];
    
    print('🔄 Updating job in Baserow with ID: $baserowId');
    
    final response = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200) {
      print('✅ Job updated in Baserow');
    } else {
      print('❌ Failed to update job in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to update job: ${response.statusCode}');
    }
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

  // ==================== PLAN IMAGES CRUD ====================

  static Future<Map<String, dynamic>> createPlanImage(Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_planImagesTableId/';
    
    final baserowData = {
      'field_$_planJobNumber': data['job_number'] ?? '',
      'field_$_planImagePath': data['image_path'] ?? '',
      'field_$_planName': data['name'] ?? '',
      'field_$_planCreatedBy': data['created_by'] ?? '',
      'field_$_planCreatedAt': data['created_at'] ?? DateTime.now().toIso8601String(),
      'field_$_planUpdatedAt': data['updated_at'] ?? DateTime.now().toIso8601String(),
    };
    
    print('🔄 Creating plan image in Baserow with data: $baserowData');
    
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      print('✅ Plan image created in Baserow with ID: ${responseData['id']}');
      return responseData;
    } else {
      print('❌ Failed to create plan image in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to create plan image: ${response.statusCode}');
    }
  }

  static Future<void> updatePlanImage(int baserowId, Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_planImagesTableId/$baserowId/';
    
    final baserowData = <String, dynamic>{};
    if (data.containsKey('job_number')) baserowData['field_$_planJobNumber'] = data['job_number'];
    if (data.containsKey('image_path')) baserowData['field_$_planImagePath'] = data['image_path'];
    if (data.containsKey('name')) baserowData['field_$_planName'] = data['name'];
    if (data.containsKey('updated_at')) baserowData['field_$_planUpdatedAt'] = data['updated_at'];
    
    print('🔄 Updating plan image in Baserow with ID: $baserowId');
    
    final response = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(baserowData),
    );
    
    if (response.statusCode == 200) {
      print('✅ Plan image updated in Baserow');
    } else {
      print('❌ Failed to update plan image in Baserow: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to update plan image: ${response.statusCode}');
    }
  }

  static Future<void> deletePlanImage(int baserowId) async {
    final url = '$_baseUrl/database/rows/table/$_planImagesTableId/$baserowId/';
    
    final response = await http.delete(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200 || response.statusCode == 204) {
      print('✅ Plan image deleted from Baserow');
    } else {
      print('❌ Failed to delete plan image from Baserow: ${response.statusCode}');
      throw Exception('Failed to delete plan image: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getPlanImages() async {
    final url = '$_baseUrl/database/rows/table/$_planImagesTableId/';
    
    final response = await http.get(Uri.parse(url), headers: _headers);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final planImages = List<Map<String, dynamic>>.from(data['results']);
      print('📥 Downloaded ${planImages.length} plan images from Baserow');
      return planImages;
    } else {
      print('❌ Failed to get plan images: ${response.statusCode}');
      return [];
    }
  }

  // ==================== PINS CRUD ====================

  static Future<Map<String, dynamic>> createPin(Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_pinsTableId/';
    
    print('🔍 DEBUG: createPin received data: $data');
    print('🔍 DEBUG: data[\'plan_name\'] = ${data['plan_name']}');
    
    final baserowData = {
      'field_$_pinJobNumber': data['job_number'] ?? '',
      'field_$_pinPlanName': data['plan_name'] ?? '',
      'field_$_pinX': data['x'] ?? 0.0,
      'field_$_pinY': data['y'] ?? 0.0,
      'field_$_pinTitle': data['title'] ?? '',
      'field_$_pinBeforePictures': data['before_pictures_urls'] ?? '',
      'field_$_pinDuringPictures': data['during_pictures_urls'] ?? '',
      'field_$_pinAfterPictures': data['after_pictures_urls'] ?? '',
      'field_$_pinCreatedBy': data['created_by'] ?? '',
      'field_$_pinCreatedAt': data['created_at'] ?? DateTime.now().toIso8601String(),
      'field_$_pinUpdatedAt': data['updated_at'] ?? DateTime.now().toIso8601String(),
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

  static Future<void> updatePin(int baserowId, Map<String, dynamic> data) async {
    final url = '$_baseUrl/database/rows/table/$_pinsTableId/$baserowId/';
    
    final baserowData = <String, dynamic>{};
    if (data['job_number'] != null && data['job_number'].toString().isNotEmpty) {
      baserowData['field_$_pinJobNumber'] = data['job_number'];
    }
    if (data['plan_name'] != null && data['plan_name'].toString().isNotEmpty) {
      baserowData['field_$_pinPlanName'] = data['plan_name'];
    }
    if (data['x'] != null) baserowData['field_$_pinX'] = data['x'];
    if (data['y'] != null) baserowData['field_$_pinY'] = data['y'];
    if (data['title'] != null && data['title'].toString().isNotEmpty) {
      baserowData['field_$_pinTitle'] = data['title'];
    }
    final bp = data['before_pictures_urls']?.toString();
    if (bp != null && bp.isNotEmpty) baserowData['field_$_pinBeforePictures'] = bp;
    final dp = data['during_pictures_urls']?.toString();
    if (dp != null && dp.isNotEmpty) baserowData['field_$_pinDuringPictures'] = dp;
    final ap = data['after_pictures_urls']?.toString();
    if (ap != null && ap.isNotEmpty) baserowData['field_$_pinAfterPictures'] = ap;
    if (data['updated_at'] != null) baserowData['field_$_pinUpdatedAt'] = data['updated_at'];
    
    // Debug log to inspect outgoing payload
    print('🔍 DEBUG: updatePin($baserowId) payload before request: $baserowData');

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
      print('❌ Payload that caused error: $baserowData');
      throw Exception('Failed to update pin: ${response.statusCode}');
    }
  }

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

  static Future<String?> uploadFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist: $filePath');
        return null;
      }

      final url = '$_baseUrl/user-files/upload-file/';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      request.headers['Authorization'] = 'Token $_token';
      
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

  static Future<String?> uploadMultipleFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return null;
    
    print('📤 Uploading ${filePaths.length} files in PARALLEL...');
    
    final uploadFutures = filePaths.map((filePath) => uploadFile(filePath)).toList();
    final results = await Future.wait(uploadFutures);
    
    final urls = results.where((url) => url != null).cast<String>().toList();
    
    if (urls.isEmpty) {
      print('❌ All uploads failed');
      return null;
    }
    
    print('✅ Successfully uploaded ${urls.length}/${filePaths.length} files');
    return urls.join(',');
  }

  // ==================== USERS ====================

  static Future<Map<String, dynamic>?> getUser(String username) async {
    final url = '$_baseUrl/database/rows/table/$_usersTableId/?user_data=true&filters=%7B%22filter_type%22%3A%22AND%22%2C%22filters%22%3A%5B%7B%22field%22%3A$_userUsername%2C%22type%22%3A%22equal%22%2C%22value%22%3A%22$username%22%7D%5D%7D';
    
    print('🔍 Getting user from URL: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: _headers,
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = List<Map<String, dynamic>>.from(data['results']);
      if (results.isNotEmpty) {
        print('✅ User found: ${results.first['field_$_userUsername']}');
        return results.first;
      }
    } else {
      print('❌ Failed to get user: ${response.statusCode}');
    }
    return null;
  }

  static Future<void> updateUserSession(String username, Map<String, dynamic> sessionData) async {
    final user = await getUser(username);
    if (user == null) {
      throw Exception('User not found: $username');
    }

    final rowId = user['id'];
    final url = '$_baseUrl/database/rows/table/$_usersTableId/$rowId/';

    final updateData = <String, dynamic>{};
    if (sessionData.containsKey('is_active')) {
      updateData['field_7497'] = sessionData['is_active'] ? 'true' : 'false';
    }
    // Note: last_activity field not yet added to Users table

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

  static String convertStatusFromBaserowFormat(dynamic status) {
    if (status == null) return 'Active';
    if (status is Map) {
      return status['value'] ?? 'Active';
    }
    return status.toString();
  }

  static Future<Map<String, dynamic>> createPhoto(Map<String, dynamic> data) async {
    throw UnimplementedError('Photos table not in new schema');
  }

  static Future<void> updatePhoto(int baserowId, Map<String, dynamic> data) async {
    throw UnimplementedError('Photos table not in new schema');
  }

  static Future<void> deletePhoto(int baserowId) async {
    throw UnimplementedError('Photos table not in new schema');
  }
}
