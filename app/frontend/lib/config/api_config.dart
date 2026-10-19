import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get dataOrigin =>
      dotenv.env['DATA_ORIGIN'] == 'synthetic' ? 'synthetic' : 'observed';

  /// Check if the environment is set to development
  static bool get isDevelopment {
    return dotenv.env['ENVIRONMENT'] != 'production';
  }

  /// Get the base local host dynamically based on platform
  static String get _localHost {
    const configuredHost = String.fromEnvironment('API_HOST');
    if (configuredHost.isNotEmpty) {
      return configuredHost;
    }
    // For a physical device on the same Wi-Fi, set API_HOST in .env to the
    // computer's LAN IPv4 address (for example, 192.168.1.25).  The dart
    // define above still takes precedence for CI/emulator builds.
    final envHost = dotenv.env['API_HOST']?.trim() ?? '';
    if (envHost.isNotEmpty) {
      return envHost;
    }
    if (kIsWeb) {
      return 'localhost';
    }
    // Android emulator runs on 10.0.2.2, iOS simulator uses 127.0.0.1
    if (Platform.isAndroid) {
      return '10.0.2.2';
    }
    // iOS simulator can reach services running on the same Mac directly.
    // Physical iOS devices must pass the Mac's LAN address with
    // --dart-define=API_HOST=192.168.x.x.
    return '127.0.0.1';
  }

  // --- Base URLs for specific backend microservices ---

  /// Auth & Profiles API (Port 8015)
  static String get authBaseUrl {
    if (isDevelopment) {
      final configured = dotenv.env['AUTH_BASE_URL']?.trim() ?? '';
      if (configured.isNotEmpty) return configured;
      return 'http://$_localHost:8015/api/v1/auth';
    }
    return 'https://adaptedmind-auth-api.onrender.com/api/v1/auth';
  }

  /// Specialist API (Port 8015)
  static String get specialistBaseUrl {
    if (isDevelopment) {
      final configured = dotenv.env['SPECIALIST_BASE_URL']?.trim() ?? '';
      if (configured.isNotEmpty) return configured;
      return 'http://$_localHost:8015/api/v1/specialists';
    }
    return 'https://adaptedmind-auth-api.onrender.com/api/v1/specialists';
  }

  /// Speech Monitoring API (Port 8020 locally, /speech on Azure)
  static String get speechBaseUrl {
    if (isDevelopment) {
      return 'http://$_localHost:8020';
    }
    // Deployed to Azure ML Gateway
    return 'https://sipsara-ml-backend-v2.azurewebsites.net/speech';
  }

  /// Telemetry Analytics API (Port 8025 locally, /telemetry on Azure)
  static String get telemetryBaseUrl {
    if (isDevelopment) {
      return 'http://$_localHost:8025/api/v1/auth';
    }
    // Deployed to Azure ML Gateway
    return 'https://sipsara-ml-backend-v2.azurewebsites.net/telemetry/api/v1/auth';
  }

  /// C1 Behavioral Analytics API (Port 8025 locally, /telemetry/api/v1/c1 on Azure)
  static String get c1BaseUrl {
    if (isDevelopment) {
      return 'http://$_localHost:8025/api/v1/c1';
    }
    // Deployed to Azure ML Gateway
    return 'https://sipsara-ml-backend-v2.azurewebsites.net/telemetry/api/v1/c1';
  }

  /// Unified Learning API Gateway (Port 8015 locally, /learning on Azure)
  static String get learningBaseUrl {
    if (isDevelopment) {
      return 'http://$_localHost:8015/api/v1/learning';
    }
    return 'https://adaptedmind-auth-api.onrender.com/api/v1/learning';
  }

  /// Parent Dashboard API (Port 8015 — auth service, NOT 8025)
  static String get parentDashboardBaseUrl {
    if (isDevelopment) {
      return 'http://$_localHost:8015/api/v1/parent/students';
    }
    return 'https://adaptedmind-auth-api.onrender.com/api/v1/parent/students';
  }

  /// Therapist Dashboard API (Port 8015 — auth service, NOT 8025)
  static String get therapistDashboardBaseUrl {
    if (isDevelopment) {
      return 'http://$_localHost:8015/api/v1/therapist/students';
    }
    return 'https://adaptedmind-auth-api.onrender.com/api/v1/therapist/students';
  }

  // --- Helper Methods ---

  /// Resolves the absolute URL for a profile picture
  static String getProfileImageUrl(String profilePicPath) {
    if (profilePicPath.startsWith('http://') ||
        profilePicPath.startsWith('https://')) {
      return profilePicPath;
    }

    // In production or development, the Auth API serves the profile images.
    // Ensure we correctly map to the domain name.
    if (isDevelopment) {
      return 'http://$_localHost:8015$profilePicPath';
    }
    return 'https://adaptedmind-auth-api.onrender.com$profilePicPath';
  }
}
