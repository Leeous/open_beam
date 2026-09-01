import 'package:open_beam/models/http_method.dart';
import 'package:open_beam/models/vizio_payload.dart';

import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/services/logging_helper.dart';

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
  Uri get _baseUrl => Uri.https('$ipAddress:$port', '/pairing/start');
  Uri get _pairCompleteUrl => Uri.https('$ipAddress:$port', '/pairing/pair');

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
    );

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
    );

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
}
