import 'dart:convert';
import 'dart:io';

void main() async {
  final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJtaW50eXZlcnNlNzAwQGdtYWlsLmNvbSIsInJvbGUiOiJzcGVjaWFsaXN0IiwiaWQiOiI2YTkxMDY4N2FhZDEwZjg1ZmZiODE2NTQiLCJleHAiOjE3ODg3NDg0MTh9.F6OCfIZtXyfdLxJtSuXEMjrTXhbjLjgxHnQCzPKDHPU';
  
  final client = HttpClient();
  client.connectionTimeout = Duration(seconds: 15);
  
  try {
    final req = await client.getUrl(Uri.parse('https://adaptedmind-auth-api.onrender.com/api/v1/auth/therapist/connections'));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer $token');
    
    final response = await req.close();
    print('HTTP ${response.statusCode}');
    
    final body = await response.transform(utf8.decoder).join();
    print(body);
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
