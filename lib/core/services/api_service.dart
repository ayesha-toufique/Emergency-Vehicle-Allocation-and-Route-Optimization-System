import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../constants/app_constants.dart';
import '../mock/demo_data.dart';
import '../mock/mock_repository.dart';

/// Network result wrapper containing status, data payload, and fallback flag.
class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isFromFallback;
  final int? statusCode;

  const ApiResponse({
    this.data,
    this.error,
    this.isFromFallback = false,
    this.statusCode,
  });

  bool get isSuccess => error == null && data != null;
}

/// Service providing unified HTTP access to Django REST backend with
/// safe automatic offline fallback to in-memory [MockRepository].
class ApiService {
  final String baseUrl;
  final http.Client _client;
  String? _authToken;
  bool _isBackendReachable = false;
  DateTime? _lastHealthCheck;

  ApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? AppConstants.apiBase,
        _client = client ?? http.Client();

  String? get authToken => _authToken;
  bool get isBackendReachable => _isBackendReachable;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Token $_authToken';
    }
    return headers;
  }

  /// Checks if Django backend `/api/health/` is reachable with a short 2s timeout.
  Future<bool> checkHealth({Duration timeout = const Duration(seconds: 2)}) async {
    final now = DateTime.now();
    if (_lastHealthCheck != null &&
        now.difference(_lastHealthCheck!) < const Duration(seconds: 5)) {
      return _isBackendReachable;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/health/');
      final response = await _client.get(uri).timeout(timeout);
      _lastHealthCheck = now;
      _isBackendReachable = response.statusCode == 200;
      return _isBackendReachable;
    } catch (e) {
      _lastHealthCheck = now;
      _isBackendReachable = false;
      debugPrint('ApiService.checkHealth: backend unreachable at $baseUrl ($e)');
      return false;
    }
  }

  Future<http.Response?> _request({
    required String method,
    required String path,
    Map<String, dynamic>? jsonBody,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final isOnline = await checkHealth();
    if (!isOnline) return null;

    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = _buildHeaders();
      final bodyStr = jsonBody != null ? jsonEncode(jsonBody) : null;

      if (method == 'POST') {
        return await _client.post(uri, headers: headers, body: bodyStr).timeout(timeout);
      }
      return await _client.get(uri, headers: headers).timeout(timeout);
    } catch (e) {
      debugPrint('ApiService.$path error: $e');
      return null;
    }
  }

  /// Authenticate user via Django `/api/auth/login/` with fallback to [MockRepository].
  Future<ApiResponse<DemoUserAccount>> login(
    String email,
    String password, {
    required MockRepository mockRepo,
  }) async {
    final response = await _request(
      method: 'POST',
      path: '${AppConstants.endpointAuth}login/',
      jsonBody: {'username': email, 'password': password},
    );

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _authToken = data['token'] as String?;
        final userJson = data['user'] as Map<String, dynamic>;

        final account = DemoUserAccount(
          id: 'USR-${userJson['id']}',
          name: userJson['full_name'] ?? userJson['username'] ?? 'User',
          email: userJson['email'] ?? email,
          password: '',
          role: (userJson['role'] as String? ?? 'citizen').toLowerCase(),
          phone: userJson['phone'] ?? '',
          isActive: userJson['is_active'] ?? true,
          createdAt: DateTime.now(),
        );

        return ApiResponse(data: account, statusCode: 200);
      } catch (e) {
        debugPrint('ApiService.login decode error: $e');
      }
    }

    // Graceful fallback to mock repository
    debugPrint('ApiService: falling back to MockRepository for login.');
    final mockAccount = mockRepo.authenticate(email, password);
    if (mockAccount != null) {
      return ApiResponse(data: mockAccount, isFromFallback: true);
    }

    return const ApiResponse(
      error: 'Invalid email or password.',
      isFromFallback: true,
    );
  }

  /// Fetch vehicles list from `/api/vehicles/` with fallback to [MockRepository].
  Future<ApiResponse<List<DemoVehicle>>> getVehicles({
    required MockRepository mockRepo,
  }) async {
    final response = await _request(
      method: 'GET',
      path: AppConstants.endpointVehicles,
    );

    if (response != null && response.statusCode == 200) {
      try {
        final list = jsonDecode(response.body) as List;
        final vehicles = list.map((item) {
          final map = item as Map<String, dynamic>;
          final lat = (map['latitude'] as num?)?.toDouble() ?? 24.8607;
          final lng = (map['longitude'] as num?)?.toDouble() ?? 67.0011;
          return DemoVehicle(
            id: map['call_sign'] ?? 'VH-${map['id']}',
            licensePlate: map['license_plate'] ?? 'KHI-${map['id']}',
            type: map['vehicle_type'] ?? 'Ambulance',
            status: map['status'] ?? 'Available',
            location: LatLng(lat, lng),
            assignedEmergencyId: map['assigned_emergency_id']?.toString(),
            driverName: map['driver_name'],
          );
        }).toList();

        return ApiResponse(data: vehicles, statusCode: 200);
      } catch (e) {
        debugPrint('ApiService.getVehicles decode error: $e');
      }
    }

    return ApiResponse(data: mockRepo.vehicles, isFromFallback: true);
  }

  /// Create emergency report at `/api/emergencies/` with fallback to [MockRepository].
  Future<ApiResponse<DemoEmergency>> reportEmergency({
    required String category,
    required int severity,
    required int urgency,
    required int peopleAffected,
    required String description,
    required LatLng location,
    required String locationLabel,
    required String userId,
    required MockRepository mockRepo,
  }) async {
    final response = await _request(
      method: 'POST',
      path: AppConstants.endpointEmergencies,
      jsonBody: {
        'title': '$category Emergency at $locationLabel',
        'description': description,
        'emergency_type': category.toUpperCase(),
        'severity': severity,
        'urgency': urgency,
        'people_affected': peopleAffected,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'address': locationLabel,
      },
    );

    if (response != null && (response.statusCode == 201 || response.statusCode == 200)) {
      try {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final createdEmergency = DemoEmergency(
          id: map['tracking_number'] ?? 'EM-${map['id']}',
          category: category,
          status: EmergencyStatus.reported,
          severity: severity,
          urgency: urgency,
          peopleAffected: peopleAffected,
          description: map['description'] ?? description,
          location: location,
          locationLabel: locationLabel,
          reportedAt: DateTime.now(),
          reportedByUserId: userId,
        );

        return ApiResponse(data: createdEmergency, statusCode: response.statusCode);
      } catch (e) {
        debugPrint('ApiService.reportEmergency decode error: $e');
      }
    }

    // Offline fallback to mock repo
    final mockCreated = mockRepo.reportEmergency(
      category: category,
      severity: severity,
      urgency: urgency,
      peopleAffected: peopleAffected,
      description: description,
      location: location,
      locationLabel: locationLabel,
      userId: userId,
    );

    return ApiResponse(data: mockCreated, isFromFallback: true);
  }

  /// Trigger multi-criteria 0/1 Knapsack allocation at `/api/allocate/`.
  Future<ApiResponse<Map<String, dynamic>>> triggerAllocation({
    int? emergencyId,
  }) async {
    final response = await _request(
      method: 'POST',
      path: AppConstants.endpointAllocate,
      jsonBody: emergencyId != null ? {'emergency_id': emergencyId} : null,
      timeout: const Duration(seconds: 8),
    );

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(data: data, statusCode: 200);
      } catch (e) {
        debugPrint('ApiService.triggerAllocation decode error: $e');
      }
    }

    return const ApiResponse(
      error: 'Backend allocation service offline.',
      isFromFallback: true,
    );
  }
}
