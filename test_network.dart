import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  try {
    print('Testing network connectivity...');

    // Test 1: Simple HTTP request
    print('Test 1: HTTP request');
    final response = await http.get(
      Uri.parse(
          'https://family-academy-backend-a12l.onrender.com/api/v1/categories'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Device-ID': 'test_device_123',
      },
    ).timeout(const Duration(seconds: 30));

    print('HTTP Status: ${response.statusCode}');
    print('HTTP Response length: ${response.body.length}');

    // Test 2: Raw socket test
    print('Test 2: Raw socket test');
    final socket = await Socket.connect(
        'family-academy-backend-a12l.onrender.com', 443,
        timeout: const Duration(seconds: 10));
    print('Socket connected successfully');
    socket.close();

    // Test 3: HTTPS with HttpClient
    print('Test 3: HTTPS with HttpClient');
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(
        'https://family-academy-backend-a12l.onrender.com/api/v1/categories'));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    request.headers.set('X-Device-ID', 'test_device_123');
    final response2 = await request.close();
    print('HTTPS Status: ${response2.statusCode}');
    client.close();

    print('All network tests passed!');
  } catch (e) {
    print('Network test failed: $e');
  }
}
