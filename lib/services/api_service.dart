import 'dart:convert';
import 'dart:io';

import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/chapter_model.dart';
import 'package:familyacademyclient/models/course_model.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/models/question_model.dart';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';
  static String? _token;
  static int? _userId;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getInt('userId');
  }

  static Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  static Map<String, String> get _headersWithAuth {
    if (_token == null) {
      throw Exception('No authentication token found');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        _token = data['token'];
        _userId = data['user']['id'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setInt('userId', _userId!);

        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        _token = data['token'];
        _userId = data['user']['id'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setInt('userId', _userId!);
        await prefs.setString('username', username);

        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _headersWithAuth,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _token = null;
      _userId = null;

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Logout failed'};
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _token = null;
      _userId = null;
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<User> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return User.fromJson(data);
      } else {
        throw Exception('Failed to load user');
      }
    } catch (e) {
      throw Exception('Failed to load user: $e');
    }
  }

  static Future<bool> isAuthenticated() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      _userId = prefs.getInt('userId');
    }
    return _token != null;
  }

  static Future<List<School>> getSchools() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/schools'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((school) => School.fromJson(school)).toList();
      } else {
        throw Exception('Failed to load schools');
      }
    } catch (e) {
      throw Exception('Failed to load schools: $e');
    }
  }

  static Future<void> selectSchool(int schoolId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/select-school'),
        headers: _headersWithAuth,
        body: json.encode({'schoolId': schoolId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to select school');
      }
    } catch (e) {
      throw Exception('Failed to select school: $e');
    }
  }

  static Future<List<Category>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((category) => Category.fromJson(category)).toList();
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  static Future<Category> getCategoryById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Category.fromJson(data);
      } else {
        throw Exception('Failed to load category');
      }
    } catch (e) {
      throw Exception('Failed to load category: $e');
    }
  }

  static Future<List<Course>> getCoursesByCategory(int categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/$categoryId/courses'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((course) => Course.fromJson(course)).toList();
      } else {
        throw Exception('Failed to load courses');
      }
    } catch (e) {
      throw Exception('Failed to load courses: $e');
    }
  }

  static Future<Course> getCourseById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Course.fromJson(data);
      } else {
        throw Exception('Failed to load course');
      }
    } catch (e) {
      throw Exception('Failed to load course: $e');
    }
  }

  static Future<List<Chapter>> getChaptersByCourse(int courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/chapters'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((chapter) => Chapter.fromJson(chapter)).toList();
      } else {
        throw Exception('Failed to load chapters');
      }
    } catch (e) {
      throw Exception('Failed to load chapters: $e');
    }
  }

  static Future<Chapter> getChapterById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chapters/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Chapter.fromJson(data);
      } else {
        throw Exception('Failed to load chapter');
      }
    } catch (e) {
      throw Exception('Failed to load chapter: $e');
    }
  }

  static Future<void> incrementVideoView(int videoId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/videos/$videoId/view'),
        headers: _headersWithAuth,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to increment video view');
      }
    } catch (e) {
      throw Exception('Failed to increment video view: $e');
    }
  }

  static Future<List<Question>> getPracticeQuestionsByChapter(
      int chapterId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chapters/$chapterId/practice-questions'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((question) => Question.fromJson(question)).toList();
      } else {
        throw Exception('Failed to load practice questions');
      }
    } catch (e) {
      throw Exception('Failed to load practice questions: $e');
    }
  }

  static Future<List<Exam>> getExamsByCourse(int courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/exams'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((exam) => Exam.fromJson(exam)).toList();
      } else {
        throw Exception('Failed to load exams');
      }
    } catch (e) {
      throw Exception('Failed to load exams: $e');
    }
  }

  static Future<Exam> getExamById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/exams/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Exam.fromJson(data);
      } else {
        throw Exception('Failed to load exam');
      }
    } catch (e) {
      throw Exception('Failed to load exam: $e');
    }
  }

  static Future<List<Question>> getExamQuestions(int examId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/exams/$examId/questions'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((question) => Question.fromJson(question)).toList();
      } else {
        throw Exception('Failed to load exam questions');
      }
    } catch (e) {
      throw Exception('Failed to load exam questions: $e');
    }
  }

  static Future<Map<String, dynamic>> submitExam({
    required int examId,
    required Map<int, int> answers,
  }) async {
    try {
      final List<Map<String, dynamic>> answerList =
          answers.entries.map((entry) {
        return {
          'questionId': entry.key,
          'selectedOption': entry.value,
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/exams/$examId/submit'),
        headers: _headersWithAuth,
        body: json.encode({'answers': answerList}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'result': data};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<Payment>> getPayments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((payment) => Payment.fromJson(payment)).toList();
      } else {
        throw Exception('Failed to load payments');
      }
    } catch (e) {
      throw Exception('Failed to load payments: $e');
    }
  }

  static Future<Map<String, dynamic>> createPayment({
    required int categoryId,
    required String paymentMethod,
    required String paymentType,
    required File proofImage,
    required String password,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/payments'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $_token',
      });

      request.fields['categoryId'] = categoryId.toString();
      request.fields['paymentMethod'] = paymentMethod;
      request.fields['paymentType'] = paymentType;
      request.fields['password'] = password;

      request.files.add(
        await http.MultipartFile.fromPath(
          'proofImage',
          proofImage.path,
          filename:
              'payment_proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode == 201) {
        return {'success': true, 'payment': Payment.fromJson(data)};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<void> uploadPaymentProof(int paymentId, File proofImage) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/payments/$paymentId/upload-proof'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $_token',
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'proofImage',
          proofImage.path,
        ),
      );

      final response = await request.send();
      if (response.statusCode != 200) {
        throw Exception('Failed to upload payment proof');
      }
    } catch (e) {
      throw Exception('Failed to upload payment proof: $e');
    }
  }

  static Future<UserProgress> getProgress() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/progress'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserProgress.fromJson(data);
      } else {
        throw Exception('Failed to load progress');
      }
    } catch (e) {
      throw Exception('Failed to load progress: $e');
    }
  }

  static Future<void> updateStreak() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/progress/streak'),
        headers: _headersWithAuth,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update streak');
      }
    } catch (e) {
      throw Exception('Failed to update streak: $e');
    }
  }

  static Future<Map<String, dynamic>> getCourseProgress(int courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/progress/course/$courseId'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load course progress');
      }
    } catch (e) {
      throw Exception('Failed to load course progress: $e');
    }
  }

  static Future<Map<String, dynamic>> sendChatMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/send'),
        headers: _headersWithAuth,
        body: json.encode({'message': message}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'response': data['response'],
          'remainingMessages': data['remainingMessages'],
        };
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<int> getRemainingChatMessages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/remaining'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['remainingMessages'];
      } else {
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? email,
    String? phone,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (email != null) updateData['email'] = email;
      if (phone != null) updateData['phone'] = phone;

      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: _headersWithAuth,
        body: json.encode(updateData),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': User.fromJson(data)};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfilePicture(
      File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/profile/picture'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $_token',
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'profilePicture',
          imageFile.path,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode == 200) {
        return {'success': true, 'imageUrl': data['imageUrl']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> generatePairingCode() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tv/generate-code'),
        headers: _headersWithAuth,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'code': data['code']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> pairTV(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tv/pair'),
        headers: _headersWithAuth,
        body: json.encode({'code': code}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'device': data['device']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> unpairTV() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tv/unpair'),
        headers: _headersWithAuth,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getPairedTV() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tv/paired'),
        headers: _headersWithAuth,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'device': data['device']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> generateParentToken() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/parent/generate-token'),
        headers: _headersWithAuth,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'token': data['token']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getParentLinkStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/parent/status'),
        headers: _headersWithAuth,
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'linked': data['linked'],
          'parent': data['parent']
        };
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      throw Exception('Failed to load notifications: $e');
    }
  }

  static Future<void> markNotificationAsRead(int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: _headersWithAuth,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  static Future<Map<String, dynamic>> requestDeviceChange({
    required String password,
    required String paymentMethod,
    required File proofImage,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/device-change'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $_token',
      });

      request.fields['password'] = password;
      request.fields['paymentMethod'] = paymentMethod;

      request.files.add(
        await http.MultipartFile.fromPath(
          'proofImage',
          proofImage.path,
          filename:
              'device_change_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<void> clearAuth() async {
    _token = null;
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static String? getToken() => _token;
  static int? getUserId() => _userId;

  static Future<bool> hasCategoryAccess(int categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/$categoryId/access'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['hasAccess'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> hasCourseAccess(int courseId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/access'),
        headers: _headersWithAuth,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['hasAccess'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
