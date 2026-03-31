import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/task_status.dart';

class AppApiException implements Exception {
  const AppApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AppApiClient {
  AppApiClient(this._dio);

  final Dio _dio;

  static String resolveBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api/v1';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:8000/api/v1';
    }
  }

  factory AppApiClient.create() {
    return AppApiClient(
      Dio(
        BaseOptions(
          baseUrl: resolveBaseUrl(),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      ),
    );
  }

  Future<List<Task>> fetchTasks({
    String? search,
    TaskStatus? status,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/tasks/',
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (status != null) 'status': status.label,
        },
      );
      final items = response.data ?? const <dynamic>[];
      return items
          .map((item) => Task.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<List<Task>> fetchAllTasks() async {
    try {
      final response = await _dio.get<List<dynamic>>('/tasks/all');
      final items = response.data ?? const <dynamic>[];
      return items
          .map((item) => Task.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Task> fetchTask(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/tasks/$id');
      return Task.fromJson(Map<String, dynamic>.from(response.data ?? const {}));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Task> createTask(Task task) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/tasks/',
        data: task.toRequestJson(),
      );
      return Task.fromJson(Map<String, dynamic>.from(response.data ?? const {}));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Task> updateTask(Task task) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/tasks/${task.id}',
        data: task.toRequestJson(),
      );
      return Task.fromJson(Map<String, dynamic>.from(response.data ?? const {}));
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      await _dio.delete<void>('/tasks/$id');
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  AppApiException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const AppApiException(
        'The request timed out. Please make sure the backend is running and try again.',
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return const AppApiException(
        'Could not connect to the backend. Check the API base URL and whether the server is running.',
      );
    }

    if (data is Map && data['detail'] is String) {
      return AppApiException(data['detail'] as String, statusCode: statusCode);
    }

    return AppApiException(
      'Request failed${statusCode != null ? ' ($statusCode)' : ''}.',
      statusCode: statusCode,
    );
  }
}
