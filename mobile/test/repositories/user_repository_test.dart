import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dio_client.dart';
import 'package:mobile/repositories/user_repository.dart';

class StubDio implements Dio {
  StubDio({
    required this.onGet,
    required this.onPatch,
    required this.onPost,
    required this.onPut,
    required this.onDelete,
  });

  final Future<Response<dynamic>> Function(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  })
  onGet;

  final Future<Response<dynamic>> Function(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  })
  onPatch;

  final Future<Response<dynamic>> Function(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  })
  onPost;

  final Future<Response<dynamic>> Function(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  })
  onPut;

  final Future<Response<dynamic>> Function(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  })
  onDelete;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await onGet(
      path,
      queryParameters: queryParameters,
      data: data,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );

    return Response<T>(
      requestOptions: response.requestOptions,
      data: response.data as T,
      headers: response.headers,
      isRedirect: response.isRedirect,
      redirects: response.redirects,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      extra: response.extra,
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await onPatch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return Response<T>(
      requestOptions: response.requestOptions,
      data: response.data as T,
      headers: response.headers,
      isRedirect: response.isRedirect,
      redirects: response.redirects,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      extra: response.extra,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await onPost(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return Response<T>(
      requestOptions: response.requestOptions,
      data: response.data as T,
      headers: response.headers,
      isRedirect: response.isRedirect,
      redirects: response.redirects,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      extra: response.extra,
    );
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await onPut(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return Response<T>(
      requestOptions: response.requestOptions,
      data: response.data as T,
      headers: response.headers,
      isRedirect: response.isRedirect,
      redirects: response.redirects,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      extra: response.extra,
    );
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final response = await onDelete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    return Response<T>(
      requestOptions: response.requestOptions,
      data: response.data as T,
      headers: response.headers,
      isRedirect: response.isRedirect,
      redirects: response.redirects,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      extra: response.extra,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late UserRepository repository;
  late List<String> requestedPaths;
  late List<Object?> payloads;
  late List<Map<String, dynamic>?> queryParams;

  setUp(() {
    requestedPaths = [];
    payloads = [];
    queryParams = [];
    DioClient.instance = StubDio(
      onGet: (
        path, {
        queryParameters,
        data,
        options,
        cancelToken,
        onReceiveProgress,
      }) async {
        requestedPaths.add(path);
        queryParams.add(queryParameters);
        if (path.endsWith('/warehouses')) {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: [
              {
                'warehouse_id': 1,
                'warehouse_name': 'Main Warehouse',
                'warehouse_code': 'MAIN',
              },
            ],
          );
        }
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'id': 7,
            'username': 'worker_7',
            'full_name': 'Worker User',
            'role': 'WORKER',
            'is_admin': false,
            'is_active': true,
            'created_at': '2026-03-10T10:00:00Z',
            'updated_at': '2026-03-11T10:00:00Z',
            'warehouses': [
              {'id': 1, 'name': 'Main Warehouse', 'code': 'MAIN'},
            ],
          },
        );
      },
      onPatch: (
        path, {
        data,
        queryParameters,
        options,
        cancelToken,
        onSendProgress,
        onReceiveProgress,
      }) async {
        requestedPaths.add(path);
        payloads.add(data);
        queryParams.add(queryParameters);
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'id': 7,
            'username': 'worker_7',
            'full_name': (data as Map<String, dynamic>)['full_name'],
            'role': 'WORKER',
            'is_admin': false,
            'is_active': true,
            'created_at': '2026-03-10T10:00:00Z',
            'updated_at': '2026-03-11T10:00:00Z',
            'warehouses': [],
          },
        );
      },
      onPost: (
        path, {
        data,
        queryParameters,
        options,
        cancelToken,
        onSendProgress,
        onReceiveProgress,
      }) async {
        requestedPaths.add(path);
        payloads.add(data);
        queryParams.add(queryParameters);
        if (path == '/users/' || path.contains('/assign-warehouse')) {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'id': 9,
              'username': 'new_user',
              'full_name': 'New User',
              'role': 'WORKER',
              'is_admin': false,
              'is_active': true,
              'created_at': '2026-03-10T10:00:00Z',
              'updated_at': '2026-03-11T10:00:00Z',
            },
          );
        }
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {'status': 'password_updated'},
        );
      },
      onPut: (
        path, {
        data,
        queryParameters,
        options,
        cancelToken,
        onSendProgress,
        onReceiveProgress,
      }) async {
        requestedPaths.add(path);
        payloads.add(data);
        queryParams.add(queryParameters);
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: {
            'id': 7,
            'username': 'worker_7',
            'full_name': (data as Map<String, dynamic>)['full_name'],
            'role': 'WORKER',
            'is_admin': false,
            'is_active': true,
            'created_at': '2026-03-10T10:00:00Z',
            'updated_at': '2026-03-11T10:00:00Z',
          },
        );
      },
      onDelete: (
        path, {
        data,
        queryParameters,
        options,
        cancelToken,
      }) async {
        requestedPaths.add(path);
        payloads.add(data);
        queryParams.add(queryParameters);
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 204,
          data: null,
        );
      },
    );
    repository = UserRepository();
  });

  test('fetchCurrentUser parses /users/me response', () async {
    final user = await repository.fetchCurrentUser();

    expect(user.id, 7);
    expect(user.username, 'worker_7');
    expect(user.fullName, 'Worker User');
    expect(user.role, 'WORKER');
    expect(user.isAdmin, isFalse);
    expect(user.warehouses.single.name, 'Main Warehouse');
    expect(requestedPaths, ['/users/me']);
  });

  test('updateProfile sends PATCH /users/me', () async {
    final user = await repository.updateProfile('Updated Name');

    expect(user.fullName, 'Updated Name');
    expect(requestedPaths, ['/users/me']);
    expect(payloads, [
      {'full_name': 'Updated Name'},
    ]);
  });

  test('changePassword sends POST /users/change-password', () async {
    await repository.changePassword('old-password', 'new-password-1');

    expect(requestedPaths, ['/users/change-password']);
    expect(payloads, [
      {'old_password': 'old-password', 'new_password': 'new-password-1'},
    ]);
  });

  test('createUser sends POST /users/', () async {
    final user = await repository.createUser(
      username: 'new_user',
      fullName: 'New User',
      password: 'secret123',
      role: 'WORKER',
    );

    expect(user.id, 9);
    expect(requestedPaths, ['/users/']);
    expect(payloads, [
      {
        'username': 'new_user',
        'full_name': 'New User',
        'password': 'secret123',
        'role': 'WORKER',
      },
    ]);
  });

  test('assignWarehouse sends POST with warehouse_id query', () async {
    await repository.assignWarehouse(userId: 9, warehouseId: 3);

    expect(requestedPaths, ['/users/9/assign-warehouse']);
    expect(queryParams, [
      {'warehouse_id': 3},
    ]);
  });

  test('listUserWarehouses parses assigned warehouses', () async {
    final warehouses = await repository.listUserWarehouses(9);

    expect(requestedPaths, ['/users/9/warehouses']);
    expect(warehouses.single.id, 1);
    expect(warehouses.single.name, 'Main Warehouse');
    expect(warehouses.single.code, 'MAIN');
  });

  test('updateUser sends PUT /users/{id}', () async {
    final user = await repository.updateUser(userId: 7, fullName: 'Renamed User');

    expect(user.fullName, 'Renamed User');
    expect(requestedPaths, ['/users/7']);
    expect(payloads, [
      {'full_name': 'Renamed User'},
    ]);
  });

  test('deactivateUser sends DELETE /users/{id}', () async {
    await repository.deactivateUser(1, 7);

    expect(requestedPaths, ['/users/7']);
    expect(queryParams, [
      {'warehouse_id': 1},
    ]);
  });
}
