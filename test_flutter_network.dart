import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NetworkTestScreen extends StatefulWidget {
  const NetworkTestScreen({super.key});

  @override
  _NetworkTestScreenState createState() => _NetworkTestScreenState();
}

class _NetworkTestScreenState extends State<NetworkTestScreen> {
  String _status = 'Testing network...';
  String _response = '';

  @override
  void initState() {
    super.initState();
    _testNetwork();
  }

  Future<void> _testNetwork() async {
    setState(() {
      _status = 'Testing network...';
      _response = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://family-academy-backend-a12l.onrender.com/api/v1/categories'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Device-ID': 'test_device_123',
        },
      ).timeout(const Duration(seconds: 30));

      setState(() {
        _status = 'Success! Status: ${response.statusCode}';
        _response = 'Response length: ${response.body.length} characters';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed: $e';
        _response = 'Error details: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text(_response, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testNetwork,
              child: const Text('Test Again'),
            ),
          ],
        ),
      ),
    );
  }
}
