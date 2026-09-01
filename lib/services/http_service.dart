import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:open_beam/models/http_method.dart';
import 'package:open_beam/services/converter_utils.dart';
import 'package:open_beam/services/logging_helper.dart';
import 'package:http/http.dart' as http;

class HTTPService {
  final http.Client _client;

  HTTPService({bool allowSelfSigned = true})
    : _client = allowSelfSigned ? _createUnsecureClient() : http.Client();

  static http.Client _createUnsecureClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    return IOClient(ioClient);
  }

  Future<HttpResponse<Map<String, dynamic>>> sendRequest({
    required Uri url,
    required HttpMethod method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // dPrint('Sending a ${method.value} request to $url.');

    try {
      // Set JSON headers if [body] exists
      final requestHeaders = <String, String>{
        if (body != null) 'Content-Type': 'application/json',
        ...?headers,
      };

      // Encode body, if it exists
      final encodedBody = body != null ? jsonEncode(body) : null;

      final http.Response response = await switch (method) {
        HttpMethod.get => _client.get(url, headers: requestHeaders),
        HttpMethod.post => _client.post(
          url,
          headers: requestHeaders,
          body: encodedBody,
        ),
        HttpMethod.put => _client.put(
          url,
          headers: requestHeaders,
          body: encodedBody,
        ),
        HttpMethod.delete => _client.delete(
          url,
          headers: requestHeaders,
          body: encodedBody,
        ),
      }.timeout(timeout);

      dPrint('Response Status: ${response.statusCode} from $url');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Try to parse as JSON & XML
        // Roku devices respond w/ XML, Vizio responds w/ JSON
        try {
          // convertToRawJson returns a JSON string (or throws FormatException).
          // Decode that JSON string into a Map<String, dynamic> for callers.
          final raw = response.body.isNotEmpty ? convertToRawJson(response.body) : '{}';
          final data = jsonDecode(raw) as Map<String, dynamic>;

          dPrint(data);

          return HttpResponse.success(data, statusCode: response.statusCode);
        } catch (e) {
          dPrint('Failed to parse response body from $url: $e');
        }
      }

      return HttpResponse.failure(
        'Server returned HTTP status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on SocketException catch (error) {
      // dPrint('Network unreachable ($url): $error');
      return HttpResponse.failure('Network unreachable ($url): $error');
    } on HandshakeException catch (error) {
      dPrint('SSL Handshake Failed ($url): $error');
      return HttpResponse.failure('SSL Handshake Failed ($url): $error');
    } on TimeoutException catch (error) {
      // dPrint('Request Timed Out ($url): $error');
      return HttpResponse.failure('Request Timed Out ($url): $error');
    } catch (error) {
      dPrint('Unexpected HTTP error: $error');
      return HttpResponse.failure('Unexpected HTTP error: $error');
    }
  }
}

class HttpResponse<T> {
  final bool isSuccess;
  final int statusCode;
  final T? data;
  final String? errorMessage;

  const HttpResponse({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.errorMessage,
  });

  factory HttpResponse.success(T data, {int statusCode = 200}) =>
      HttpResponse(isSuccess: true, statusCode: statusCode, data: data);

  factory HttpResponse.failure(String error, {int statusCode = 500}) =>
      HttpResponse(
        isSuccess: false,
        statusCode: statusCode,
        errorMessage: error,
      );
}
