import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import '../main.dart'; // For globalNavigatorKey
import '../config/api_config.dart';

/// Handles authentication-only API calls: login, signup, tokens, passwords.
/// Student management is in StudentService.
class AuthService {
  static String get _baseUrl {
    return ApiConfig.authBaseUrl;
  }
  // Helper to get device info
  Future<Map<String, String>> _getDeviceData() async {
    final prefs = await SharedPreferences.getInstance();
    String deviceId = prefs.getString('device_id') ?? '';
    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    
    String deviceName = 'Unknown Device';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceName = macInfo.computerName;
      }
    } catch (e) {
      // fallback
    }
    
    return {'device_id': deviceId, 'device_name': deviceName};
  }
  /// Returns null on success, or an error message string on failure.
  Future<String?> login(String email, String password, {String role = "parent"}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'device_id': (await _getDeviceData())['device_id'],
          'device_name': (await _getDeviceData())['device_name'],
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String accessToken = data['access_token'];
        String refreshToken = data['refresh_token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        await prefs.setString('auth_provider', 'local');
        
        return null;
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        } else if (data['detail'] is List) {
          final err = data['detail'][0];
          final field = err['loc']?.last?.toString() ?? 'Field';
          return '$field: ${err['msg']}';
        }
        return 'Incorrect email or password.';
      }
    } catch (e) {
      return 'Network Error: $e';
    }
  }
  /// Returns null on success, or an error message string on failure.
  Future<String?> loginWithGoogle({String role = "parent", String? specialization, String? clinicName}) async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: '733315696908-tpau04bmsk824olg6m0a3coanojl147v.apps.googleusercontent.com',
      );

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return 'Failed to get ID token from Google.';
      }
      // Send token to backend
      final deviceData = await _getDeviceData();
      final response = await http.post(
        Uri.parse('$_baseUrl/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
          'device_id': deviceData['device_id'],
          'device_name': deviceData['device_name'],
          'role': role,
          if (specialization != null) 'specialization': specialization,
          if (clinicName != null) 'clinic_name': clinicName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String accessToken = data['access_token'];
        String refreshToken = data['refresh_token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        await prefs.setString('auth_provider', 'google');
        
        return null; // Success
      } else {
        try {
          final data = jsonDecode(response.body);
          return data['detail'] ?? 'Google login failed on server.';
        } catch (_) {
          return 'Google login failed with status: ${response.statusCode}';
        }
      }
    } catch (e) {
      print('GOOGLE SIGN IN ERROR: $e');
      if (e.toString().contains('canceled') || e.toString().contains('Canceled')) {
        return 'CANCELED';
      }
      return 'Google Sign In Error: $e';
    }
  }
  /// Returns null on success, or an error message string on failure.
  Future<String?> loginWithMicrosoft({String role = "parent", String? specialization, String? clinicName}) async {
    try {
      final Config config = Config(
        tenant: 'common', // We will keep 'common' so any Microsoft account can log in
        clientId: 'a1a55b82-e464-4ac1-80fd-5ad23fcbef56', // Microsoft Client ID
        scope: 'openid profile email User.Read',
        redirectUri: 'https://login.live.com/oauth20_desktop.srf', // Standard URI for mobile webviews
        navigatorKey: globalNavigatorKey,
        customParameters: {'prompt': 'select_account'},
        // webUseRedirect is ONLY for web. It breaks mobile authentication.
      );

      final AadOAuth oauth = AadOAuth(config);
      final result = await oauth.login();
      
      final String? accessToken = await oauth.getAccessToken();

      if (accessToken == null) {
        String errMsg = 'Failed to get Access token from Microsoft.';
        try {
           result.fold((l) {
             final errStr = l.toString().toLowerCase();
             if (errStr.contains('canceled') || errStr.contains('accessdenied')) {
               errMsg = 'CANCELED';
             } else {
               errMsg = 'Microsoft Auth Error: ${l.toString()}';
             }
           }, (r) => null);
        } catch (_) {}
        return errMsg;
      }
      // Send token to backend
      final deviceData = await _getDeviceData();
      final response = await http.post(
        Uri.parse('$_baseUrl/microsoft'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_token': accessToken,
          'device_id': deviceData['device_id'],
          'device_name': deviceData['device_name'],
          'role': role,
          if (specialization != null) 'specialization': specialization,
          if (clinicName != null) 'clinic_name': clinicName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String jwtAccessToken = data['access_token'];
        String jwtRefreshToken = data['refresh_token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', jwtAccessToken);
        await prefs.setString('refresh_token', jwtRefreshToken);
        await prefs.setString('auth_provider', 'microsoft');
        
        return null; // Success
      } else {
        try {
          final data = jsonDecode(response.body);
          return data['detail'] ?? 'Microsoft login failed on server.';
        } catch (_) {
          return 'Microsoft login failed with status: ${response.statusCode}';
        }
      }
    } catch (e) {
      print('MICROSOFT SIGN IN ERROR: $e');
      if (e.toString().contains('canceled') || e.toString().contains('Canceled')) {
        return 'CANCELED';
      }
      return 'Microsoft Sign In Error: $e';
    }
  }
  /// Returns null on success, or an error message string on failure.
  Future<String?> signup(String name, String email, String password, {String role = "parent", String? specialization, String? clinicName}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'role': role,
          if (specialization != null) 'specialization': specialization,
          if (clinicName != null) 'clinic_name': clinicName,
        }),
      );

      if (response.statusCode == 201) {
        // Success: Account created, but needs email verification OTP
        return null;
      } else {
        final data = jsonDecode(response.body);
        
        if (data['detail'] is String) {
          return data['detail'];
        } else if (data['detail'] is List) {
          final err = data['detail'][0];
          final field = err['loc']?.last?.toString() ?? 'Field';
          return '$field: ${err['msg']}';
        }
        return 'Failed to sign up. Please check your inputs.';
      }
    } catch (e) {
      print('SIGNUP ERROR: $e');
      return 'Network Error: $e';
    }
  }
  /// Verify Email via OTP during Signup

  Future<String?> resendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) {
        return null;
      }
      return jsonDecode(response.body)['detail'] ?? 'Failed to resend OTP';
    } catch (e) {
      return 'Network error: $e';
    }
  }
  Future<String?> verifyEmail(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim()
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String jwtAccessToken = data['access_token'];
        String jwtRefreshToken = data['refresh_token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', jwtAccessToken);
        await prefs.setString('refresh_token', jwtRefreshToken);
        await prefs.setString('auth_provider', 'local');
        
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        } else if (data['detail'] is List) {
          final err = data['detail'][0];
          return err['msg'] ?? 'Validation error';
        }
        return 'Failed to verify email.';
      }
    } catch (e) {
      return 'Network Error: $e';
    }
  }
  /// Cancel a pending signup
  Future<void> cancelSignup(String email) async {
    try {
      await http.delete(Uri.parse('$_baseUrl/cancel-signup/$email'));
    } catch (e) {
      print('Cancel signup failed: $e');
    }
  }

  /// Helper to get the token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
  /// Helper to get the auth provider
  Future<String> getAuthProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_provider') ?? 'local';
  }
  /// Get current user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final token = await getAccessToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10)); // Reduced timeout from 60s to 10s for better UX

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Cache the role for faster splash screen loads
        if (data['role'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_user_role', data['role']);
        }
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Helper to get the cached role quickly
  Future<String> getCachedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cached_user_role') ?? 'parent';
  }
  /// Update Profile (Name/Email)
  Future<String?> updateProfile({String? name, String? email, String? specialization, String? clinicName}) async {
    try {
      final token = await getAccessToken();
      if (token == null) return 'Not authenticated.';

      final Map<String, dynamic> body = {};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (specialization != null) body['specialization'] = specialization;
      if (clinicName != null) body['clinic_name'] = clinicName;

      final response = await http.put(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        }
        return 'Failed to update profile.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }
  /// Request Email Update (Sends OTP)
  Future<String?> requestEmailUpdate(String newEmail) async {
    try {
      final token = await getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.post(
        Uri.parse('$_baseUrl/request-email-update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'new_email': newEmail}),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Failed to request email update.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }
  /// Verify Email Update (Confirms OTP)
  Future<String?> verifyEmailUpdate(String newEmail, String otp) async {
    try {
      final token = await getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.post(
        Uri.parse('$_baseUrl/verify-email-update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'new_email': newEmail,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        return null;
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'Failed to verify email update.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }
  /// Change Password
  Future<String?> changePassword(String oldPassword, String newPassword) async {
    try {
      final token = await getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.post(
        Uri.parse('$_baseUrl/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        } else if (data['detail'] is List) {
          final err = data['detail'][0];
          final field = err['loc']?.last?.toString() ?? 'Field';
          return '$field: ${err['msg']}';
        }
        return 'Failed to change password.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }
  /// Request Password Reset
  Future<String?> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is List && data['detail'].isNotEmpty) {
          return data['detail'][0]['msg']?.toString() ?? 'Invalid input format.';
        }
        return data['detail']?.toString() ?? 'Failed to send reset code.';
      }
    } catch (e) {
      return 'Network Error: $e';
    }
  }
  /// Reset Password
  Future<String?> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
          'new_password': newPassword
        }),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        } else if (data['detail'] is List) {
          final err = data['detail'][0];
          return err['msg'] ?? 'Validation error';
        }
        return 'Failed to reset password.';
      }
    } catch (e) {
      return 'Network Error: $e';
    }
  }
  /// Verify parent password
  Future<String?> verifyPassword(String password) async {
    try {
      final token = await getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.post(
        Uri.parse('$_baseUrl/verify-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'password': password}),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] is String) {
          return data['detail'];
        }
        return 'Incorrect password.';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }
  /// Delete Account
  Future<String?> deleteAccount() async {
    try {
      final token = await getAccessToken();
      if (token == null) return 'Not authenticated.';

      final response = await http.delete(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204) {
        return null; // Success
      } else {
        return 'Failed to delete account. Status: ${response.statusCode}';
      }
    } catch (e) {
      return 'Failed to connect to the server.';
    }
  }
  /// Clear tokens (logout)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('auth_provider');
    
    if (provider == 'google') {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    } else if (provider == 'microsoft') {
      try {
        final Config config = Config(
          tenant: 'common',
          clientId: 'a1a55b82-e464-4ac1-80fd-5ad23fcbef56',
          scope: 'openid profile email User.Read',
          redirectUri: 'https://login.live.com/oauth20_desktop.srf',
          navigatorKey: globalNavigatorKey,
        );
        await AadOAuth(config).logout();
      } catch (_) {}
    }
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('auth_provider');
  }
  // Toggle Login Alerts
  Future<Map<String, dynamic>> toggleLoginAlerts(bool enabled) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('$_baseUrl/settings/login-alerts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'enabled': enabled}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update login alerts');
    }
  }
  // Upload Profile Picture
  Future<String> uploadProfilePicture(File imageFile) async {
    final token = await getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/profile/picture'),
    );
    
    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });
    
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['profile_picture_url'];
    } else {
      throw Exception('Failed to upload profile picture: ${response.body}');
    }
  }
  // Delete Profile Picture
  Future<void> deleteProfilePicture() async {
    final token = await getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$_baseUrl/profile/picture'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete profile picture: ${response.body}');
    }
  }
  // Connect Specialist
  Future<String?> connectSpecialist(String clinicCode, String studentId) async {
    try {
      final token = await getAccessToken();
      if (token == null) return 'Not authenticated';

      final response = await http.post(
        Uri.parse('$_baseUrl/therapist/connect'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'clinic_code': clinicCode,
          'student_id': studentId,
        }),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final body = jsonDecode(response.body);
        return body['detail'] ?? 'Failed to connect';
      }
    } catch (e) {
      return e.toString();
    }
  }
  // Disconnect a specialist
  Future<String?> disconnectSpecialist(String connectionId) async {
    try {
      final token = await getAccessToken();
      if (token == null) return 'No auth token';

      final response = await http.delete(
        Uri.parse('$_baseUrl/therapist/disconnect/$connectionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return null; // success
      }
      
      final data = jsonDecode(response.body);
      return data['detail'] ?? 'Failed to disconnect';
    } catch (e) {
      return e.toString();
    }
  }

  // Get Therapist Connections
  Future<List<dynamic>> getConnections() async {
    try {
      final token = await getAccessToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/therapist/connections'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
