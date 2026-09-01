import 'package:open_beam/models/http_method.dart';
import 'package:open_beam/models/vizio_payload.dart';
import 'dart:convert';
import 'dart:io';

import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/services/logging_helper.dart';
import 'package:open_beam/services/converter_utils.dart';

/// Manages the two-step pairing handshake with a Vizio SmartCast TV.
///
/// Typical usage involves calling [initiatePairing] to display a PIN on the TV,
/// followed by [completePairing] once the user enters that PIN:
///
/// ```dart
/// final manager = VizioPairingManager(
///   ipAddress: '192.168.1.100',
///   httpService: myHttpService,
/// );
///
/// final initResult = await manager.initiatePairing();
/// if (initResult.isSuccess) {
///   final authResult = await manager.completePairing(
///     pin: '1234',
///     pairingReqToken: initResult.pairingReqToken!,
///   );
/// }
/// ```
class VizioPairingManager {
  /// IP address of target TV
  /// (TODO: likely will also track MAC addresses in the future to avoid DHCP issues)
  final String ipAddress;

  /// Target port of Vizio TV. Defaults to `7345`.
  final int port;

  /// Unique device ID to register remote w/ TV.
  final String deviceId;

  /// Pretty printed device name to be displayed in TV settings / on-screen.
  final String deviceName;

  /// HTTP client service used to preform network requests.
  final HTTPService httpService;

  /// Creates a [VizioPairingManager] instance configured for the target device.
  VizioPairingManager({
    required this.ipAddress,
    this.port = 7345,
    this.deviceId = 'open_beam_remote',
    this.deviceName = 'Open Beam Remote',
    required this.httpService,
  });

  /// Pairing process endpoints. I have no reason to believe these are not consistant
  /// but may allow user to edit in the future.
  // Vizio pairing endpoints use plain HTTP on the device's port
  Uri get _baseUrl => Uri.http('$ipAddress:$port', '/pairing/start');
  Uri get _pairCompleteUrl => Uri.http('$ipAddress:$port', '/pairing/pair');

  /// Starts the pairing handshake with a Vizio TV.
  ///
  /// Sends the [deviceId] and [deviceName] to trigger on-screen PIN challenge
  /// on the TV.
  ///
  /// Returns a [VizioPairingInitiation] containing the pairing token for [completePairing],
  /// or a failure description if the request fails.
  Future<VizioPairingInitiation> initiatePairing() async {
    final body = {'DEVICE_ID': deviceId, 'DEVICE_NAME': deviceName};

    HttpResponse<Map<String, dynamic>> response;
    response = await httpService.sendRequest(
      url: _baseUrl,
      method: HttpMethod.put,
      body: body,
      headers: {'Connection': 'close'},
    );

    // If the high-level client returned a connection-closed style error, try the
    // low-level fallback which can be more tolerant of malformed/truncated headers.
    if (!response.isSuccess && (response.errorMessage?.contains('Connection closed') == true || response.errorMessage?.contains('ClientException') == true)) {
      dPrint('High-level HTTP client reported error (${response.errorMessage}); trying fallback HttpClient');
      response = await _fallbackRequest(_baseUrl, body);
    }

    if (!response.isSuccess || response.data == null) {
      dPrint('Failed to initiate pairing: ${response.errorMessage}');
      return VizioPairingInitiation.failure(
        response.errorMessage ?? 'Unknown network error',
      );
    }

    final rawItem = response.data!['ITEM'];
    if (rawItem == null || rawItem is! Map<String, dynamic>) {
      final status = response.data!['STATUS'];
      if (status is Map<String, dynamic>) {
        final result = status['RESULT']?.toString() ?? 'UNKNOWN';
        final detail = status['DETAIL']?.toString() ?? '';
        return VizioPairingInitiation.failure(
          'Pairing initiation failed: $result ${detail.isNotEmpty ? '- $detail' : ''}',
        );
      }

      return VizioPairingInitiation.failure(
        'Invalid pairing initiation response: ${response.data}',
      );
    }

    final item = rawItem;
    final token = item['PAIRING_REQ_TOKEN']?.toString();

    // CHALLENGE_TYPE may be returned as int or string; normalize to int with default 1
    int challengeType;
    final rawChallenge = item['CHALLENGE_TYPE'];
    if (rawChallenge is int) {
      challengeType = rawChallenge;
    } else if (rawChallenge is String) {
      challengeType = int.tryParse(rawChallenge) ?? 1;
    } else {
      challengeType = 1;
    }

    if (token == null || token.isEmpty) {
      return VizioPairingInitiation.failure(
        'Invalid pairing token received from TV',
      );
    }

    return VizioPairingInitiation.success(
      pairingReqToken: token,
      challengeType: challengeType,
    );
  }

  Future<VizioPairingResult> completePairing({
    required String pin,
    required String pairingReqToken,
    int challengeType = 1,
  }) async {
    /// Form JSON body containing [deviceId]
    ///
    final body = {
      'DEVICE_ID': deviceId,
      'CHALLENGE_TYPE': challengeType,
      'RESPONSE_VALUE': pin.trim(), // need to get from UI
      'PAIRING_REQ_TOKEN': int.tryParse(pairingReqToken) ?? pairingReqToken,
    };

    HttpResponse<Map<String, dynamic>> response;
    response = await httpService.sendRequest(
      url: _pairCompleteUrl,
      method: HttpMethod.put,
      body: body,
      headers: {'Connection': 'close'},
    );

    if (!response.isSuccess && (response.errorMessage?.contains('Connection closed') == true || response.errorMessage?.contains('ClientException') == true)) {
      dPrint('High-level HTTP client reported error (${response.errorMessage}); trying fallback HttpClient for completePairing');
      response = await _fallbackRequest(_pairCompleteUrl, body);
    }

    if (response.data == null) {
      return VizioPairingResult.failure(
        response.errorMessage ?? 'No response data',
      );
    }

    final rawItem = response.data!['ITEM'];
    if (rawItem == null || rawItem is! Map<String, dynamic>) {
      // If ITEM is missing, try to extract a STATUS block for a clearer error message
      final status = response.data!['STATUS'];
      if (status is Map<String, dynamic>) {
        final result = status['RESULT']?.toString() ?? 'UNKNOWN';
        final detail = status['DETAIL']?.toString() ?? '';
        return VizioPairingResult.failure(
          'Pairing failed: $result ${detail.isNotEmpty ? '- $detail' : ''}',
        );
      }

      return VizioPairingResult.failure(
        'Invalid pairing response: ${response.data}',
      );
    }

    final item = rawItem;
    final authToken = item['AUTH_TOKEN']?.toString();

    if (authToken == null || authToken.isEmpty) {
      return VizioPairingResult.failure('Unable to parse auth token.');
    }

    return VizioPairingResult.success(authToken);
  }


  // Fallback low-level HTTP PUT in case package:http client fails (some TVs close
  // connections unusually or return malformed headers). This attempts a raw
  // dart:io HttpClient request and returns a compatible HttpResponse.
  Future<HttpResponse<Map<String, dynamic>>> _fallbackRequest(
    Uri url,
    Map body,
  ) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl('PUT', url);
      // Set common headers; explicitly set Content-Length to avoid chunked
      // Transfer-Encoding which some TVs don't handle.
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Connection', 'close');
      req.headers.set('Accept', 'application/json');
      // Host header may help devices that validate it strictly
      req.headers.set('Host', url.authority);

      final payload = jsonEncode(body);
      final payloadBytes = utf8.encode(payload);
      req.contentLength = payloadBytes.length;
      req.add(payloadBytes);

      final resp = await req.close();
      final status = resp.statusCode;
      final respBody = await resp.transform(utf8.decoder).join();

      dPrint('Fallback response status: $status from $url');
      dPrint(respBody);

      if (status >= 200 && status < 300) {
        try {
          final raw = respBody.isNotEmpty ? convertToRawJson(respBody) : '{}';
          final data = jsonDecode(raw) as Map<String, dynamic>;
          return HttpResponse.success(data, statusCode: status);
        } catch (e) {
          dPrint('Fallback parsing error: $e');
          return HttpResponse.failure('Fallback parsing error: $e', statusCode: status);
        }
      }

      return HttpResponse.failure('Server returned HTTP status $status', statusCode: status);
    } catch (e) {
      dPrint('Fallback request failed: $e');
      return HttpResponse.failure('Fallback request failed: $e');
    } finally {
      client.close(force: true);
    }
  }
}

