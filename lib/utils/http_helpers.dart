import 'package:dio/dio.dart';

class HTTPHelperApi {
  Dio dio = Dio();

  Future<Response> dioGet({
    required String url,
    Map<String, dynamic>? data,
    required Map<String, dynamic> headers,
    BaseOptions? baseOptions,
    Interceptor? interceptors,
    Options? requestOptions,
  }) async {
    if (baseOptions != null) {
      dio = Dio(baseOptions);
    }
    // if (headers != null) {
    //   dio.options.headers = headers;
    // }
    if (interceptors != null) {
      dio.interceptors.add(interceptors);
    }
    dio.options.headers = headers;
    Response response = await dio.get(
      url,
      data: data,
      options: requestOptions,
    );
    return response;
  }

  Future<Response> dioPost({
    required String url,
    required Map<String, dynamic> data,
    required Map<String, dynamic> headers,
    BaseOptions? baseOptions,
    Interceptor? interceptors,
    Options? requestOptions,
  }) async {
    if (baseOptions != null) {
      dio = Dio(baseOptions);
    }
    if (interceptors != null) {
      dio.interceptors.add(interceptors);
    }
    dio.options.headers = headers;
    Response response = await dio.post(
      url,
      data: data,
      options: requestOptions,
    );
    return response;
  }

  Future dioPatch({
    required String url,
    required Map<String, dynamic>? data,
    required FormData? formData,
    Map<String, dynamic>? headers,
    BaseOptions? baseOptions,
    Interceptor? interceptors,
    Options? requestOptions,
  }) async {
    if (baseOptions != null) {
      dio = Dio(baseOptions);
    }
    if (headers != null) {
      dio.options.headers = headers;
    }
    if (interceptors != null) {
      dio.interceptors.add(interceptors);
    }
    Response response = await dio.patch(
      url,
      options: requestOptions,
      data: data ?? formData ?? {},
    );
    return response;
  }

  Future dioPut({
    required String url,
    required Map<String, dynamic> data,
    Map<String, dynamic>? headers,
    BaseOptions? baseOptions,
    Interceptor? interceptors,
    Options? requestOptions,
  }) async {
    if (baseOptions != null) {
      dio = Dio(baseOptions);
    }
    if (headers != null) {
      dio.options.headers = headers;
    }
    if (interceptors != null) {
      dio.interceptors.add(interceptors);
    }
    Response response = await dio.get(
      url,
      options: requestOptions,
    );
    return response;
  }

  Future dioDelete({
    required String url,
    required Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
    BaseOptions? baseOptions,
    Interceptor? interceptors,
    Options? requestOptions,
  }) async {
    if (baseOptions != null) {
      dio = Dio(baseOptions);
    }
    if (interceptors != null) {
      dio.interceptors.add(interceptors);
    }
    dio.options.headers = headers;
    Response response = await dio.delete(
      url,
      options: requestOptions,
    );
    return response;
  }

  Future dioHead({
    required String url,
    Map<String, dynamic>? headers,
    BaseOptions? baseOptions,
    Interceptor? interceptors,
  }) async {
    if (baseOptions != null) {
      dio = Dio(baseOptions);
    }
    if (interceptors != null) {
      dio.interceptors.add(interceptors);
    }
    dio.options.headers = headers;
    Response response = await dio.head(url);
    return response;
  }

  Future dioOptions({required String url}) async {
    Response response = await dio.request(url);
    return response;
  }
}
