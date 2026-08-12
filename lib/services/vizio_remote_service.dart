import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:vizio_remote/services/logging_helper.dart';

class VizioRemoteService {
  final String tvIp;
  final int port;
  final String? authToken;

  late final http.Client _client;

  VizioRemoteService({required this.tvIp, this.port = 7345, this.authToken}) {
    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    ioClient.connectionTimeout = const Duration(seconds: 8);

    _client = IOClient(ioClient);
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authToken != null && authToken!.isNotEmpty) {
      headers['AUTH'] = authToken!;
    }
    return headers;
  }

  Future<Map<String, dynamic>?> sendPutRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 8),
    int maxAttempts = 2,
  }) async {
    final uri = Uri.parse('https://$tvIp:$port$endpoint');
    _debugLog('PUT', uri.toString(), body: body);

    Duration currentTimeout = timeout;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client
            .put(uri, headers: _buildHeaders(), body: jsonEncode(body))
            .timeout(currentTimeout);

        Object? decodedBody;
        try {
          decodedBody = response.body.isNotEmpty
              ? jsonDecode(response.body)
              : null;
        } catch (_) {
          decodedBody = response.body;
        }

        _debugLog('PUT RESPONSE', uri.toString(), body: decodedBody);

        if (response.statusCode == 200) {
          if (decodedBody is Map<String, dynamic>) return decodedBody;
          return jsonDecode(response.body) as Map<String, dynamic>?;
        }

        dPrint('HTTP Error: ${response.statusCode} - ${response.body}');

        return null;
      } on TimeoutException catch (e) {
        if (attempt >= maxAttempts) {
          dPrint('Request timed out: $e');
          return null;
        }
        currentTimeout = Duration(seconds: currentTimeout.inSeconds * 2);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } on http.ClientException catch (e) {
        if (attempt >= maxAttempts) {
          dPrint('Connection Error: $e');
          return null;
        }
        currentTimeout = Duration(seconds: currentTimeout.inSeconds + 4);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } on SocketException catch (e) {
        if (attempt >= maxAttempts) {
          dPrint('Socket Error: $e');
          return null;
        }
        currentTimeout = Duration(seconds: currentTimeout.inSeconds + 4);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } catch (error) {
        dPrint('Connection Error: $error');
        return null;
      }
    }

    return null;
  }

  Future<PairingChallenge?> startPairing({
    required String deviceId,
    required String deviceName,
  }) async {
    const endpoint = '/pairing/start';
    final body = <String, dynamic>{
      'DEVICE_ID': deviceId,
      'DEVICE_NAME': deviceName,
    };

    final response = await sendPutRequest(endpoint: endpoint, body: body);
    if (response == null) return null;

    final item = response['ITEM'];
    if (item is! Map<String, dynamic>) return null;

    final pairingReqToken = item['PAIRING_REQ_TOKEN'];
    final challengeType = item['CHALLENGE_TYPE'];

    if (pairingReqToken is int && challengeType is int) {
      return PairingChallenge(
        deviceId: deviceId,
        pairingReqToken: pairingReqToken,
        challengeType: challengeType,
      );
    }

    return null;
  }

  Future<String?> confirmPairing({
    required String deviceId,
    required String pin,
    required int pairingReqToken,
    required int challengeType,
  }) async {
    const endpoint = '/pairing/pair';
    final body = <String, dynamic>{
      'DEVICE_ID': deviceId,
      'CHALLENGE_TYPE': challengeType,
      'RESPONSE_VALUE': pin,
      'PAIRING_REQ_TOKEN': pairingReqToken,
    };

    final response = await sendPutRequest(endpoint: endpoint, body: body);
    if (response == null) return null;

    return _extractAuthToken(response);
  }

  Future<bool> sendKeyPress(int codeSet, int code) async {
    const endpoint = '/key_command/';
    final body = <String, dynamic>{
      'KEYLIST': [
        {'CODESET': codeSet, 'CODE': code, 'ACTION': 'KEYPRESS'},
      ],
    };

    final response = await sendPutRequest(endpoint: endpoint, body: body);
    return response != null;
  }

  String? _extractAuthToken(Map<String, dynamic> response) {
    const tokenKeys = ['AUTH', 'auth', 'token', 'AUTH_TOKEN', 'authToken'];

    for (final key in tokenKeys) {
      final token = response[key];
      if (token is String && token.isNotEmpty) return token;
    }

    final item = response['ITEM'];
    if (item is Map<String, dynamic>) {
      for (final key in tokenKeys) {
        final token = item[key];
        if (token is String && token.isNotEmpty) return token;
      }
    }

    return null;
  }

  void _debugLog(String label, String url, {required Object? body}) {
    if (!kDebugMode) return;
    final payload = body is String ? body : jsonEncode(body);
    dPrint('VizioRemoteService: $label $url');
    dPrint('VizioRemoteService: BODY $payload');
  }
}

class PairingChallenge {
  final String deviceId;
  final int pairingReqToken;
  final int challengeType;

  PairingChallenge({
    required this.deviceId,
    required this.pairingReqToken,
    required this.challengeType,
  });
}
