import 'package:flutter_test/flutter_test.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/utils/constants.dart';

void main() {
  late ApiService apiService;

  setUp(() {
    apiService = ApiService();
  });

  group('API Service Tests', () {
    test('API Base URL should be configured', () {
      expect(AppConstants.apiBaseUrl, isNotEmpty);
      expect(AppConstants.apiBaseUrl, contains('http'));
    });

    test('API Version should be configured', () {
      expect(AppConstants.apiVersion, isNotEmpty);
      expect(AppConstants.apiVersion, '/api/v1');
    });

    test('Health endpoint should be accessible', () async {
      final response = await apiService.checkConnectivity();
      expect(response, isA<bool>());
    });

    test('Categories endpoint should be configured', () {
      expect(AppConstants.categoriesEndpoint, isNotEmpty);
      expect(AppConstants.categoriesEndpoint, '/api/v1/categories');
    });

    test('Schools endpoint should be configured', () {
      expect(AppConstants.schoolsEndpoint, isNotEmpty);
      expect(AppConstants.schoolsEndpoint, '/api/v1/schools');
    });

    test('Auth endpoints should be configured', () {
      expect(AppConstants.registerEndpoint, isNotEmpty);
      expect(AppConstants.studentLoginEndpoint, isNotEmpty);
      expect(AppConstants.validateStudentTokenEndpoint, isNotEmpty);
    });

    test('Progress endpoints should be configured', () {
      expect(AppConstants.progressSaveEndpoint, isNotEmpty);
      expect(AppConstants.progressOverallEndpoint, isNotEmpty);
      expect(AppConstants.progressCourseEndpoint(1), isNotEmpty);
    });

    test('Notifications endpoints should be configured', () {
      expect(AppConstants.myNotificationsEndpoint, isNotEmpty);
      expect(AppConstants.notificationsUnreadCountEndpoint, isNotEmpty);
    });

    test('Videos endpoint should be configured', () {
      expect(AppConstants.videosByChapter(1), isNotEmpty);
    });

    test('Upload endpoints should be configured', () {
      expect(AppConstants.uploadImageEndpoint, isNotEmpty);
      expect(AppConstants.uploadPaymentProofEndpoint, isNotEmpty);
    });

    test('Chatbot endpoint should be configured', () {
      expect(AppConstants.chatbotChatEndpoint, isNotEmpty);
    });
  });
}
