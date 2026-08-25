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

    final response = await httpService.sendRequest(
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

    final item = response.data!['ITEM'] as Map<String, dynamic>;
    final token = item['PAIRING_REQ_TOKEN']?.toString();
    final challengeType = item['CHALLENGE_TYPE']?.toString() ?? '1';

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
    String challengeType = '1',
  }) async {
    /// Form JSON body containing [deviceId]
    ///
    final body = {
      'DEVICE_ID': deviceId,
      'CHALLENGE_TYPE': challengeType,
      'RESPONSE_VALUE': pin.trim(), // need to get from UI
      'PAIRING_REQ_TOKEN': int.tryParse(pairingReqToken) ?? pairingReqToken,
    };

    final response = await httpService.sendRequest(
      url: _pairCompleteUrl,
      method: HttpMethod.put,
      body: body,
    );

    if (response.data == null) {
      return VizioPairingResult.failure('error');
    }

    final item = response.data!['ITEM'] as Map<String, dynamic>;
    final authToken = item['AUTH_TOKEN']?.toString();

    if (authToken == null || authToken.isEmpty) {
      return VizioPairingResult.failure('Unable to parse auth token.');
    }

    return VizioPairingResult.success(authToken);
  }
}
