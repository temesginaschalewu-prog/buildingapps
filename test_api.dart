import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  try {
    print('Testing API connection...');

    final response = await http.get(
      Uri.parse(
          'https://family-academy-backend-a12l.onrender.com/api/v1/categories'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Device-ID': 'test_device_123',
      },
    );

    print('Status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Categories loaded successfully!');
      print('Number of categories: ${data['data']?.length ?? 0}');
    } else {
      print('API request failed');
    }
  } catch (e) {
    print('Error: $e');
  }
}
