import 'package:open_beam/models/http_method.dart';
import 'package:open_beam/models/tv_key.dart';
import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/services/logging_helper.dart';
import 'package:open_beam/services/tv_service.dart';

class RokuTvService extends TVService {
  final HTTPService _httpService;
  final int port;

  const RokuTvService({
    required super.ipAddress,
    required super.name,
    this.port = 7345,
    required this._httpService,
  });

  // Single string mapping for Roku ECP command names
  static const Map<TvKey, String> _keyMap = {
    // Power
    TvKey.powerOn: 'PowerOn',
    TvKey.powerOff: 'PowerOff',

    // Volume & Audio
    TvKey.volUp: 'VolumeUp',
    TvKey.volDown: 'VolumeDown',
    TvKey.mute: 'VolumeMute',

    // Navigation & Menus
    TvKey.home: 'Home',
    TvKey.back: 'Back',
    TvKey.up: 'Up',
    TvKey.down: 'Down',
    TvKey.left: 'Left',
    TvKey.right: 'Right',
    TvKey.select: 'Select',
    // TvKey.info: 'Options', // Asterisk / Options key (*)
    // Playback
    // TvKey.play: 'Play',
    // TvKey.pause: 'Pause',

    // Inputs
    // TvKey.inputHdmi1: 'InputHDMI1',
  };

  Uri get _keyCommandUrl => Uri.https('$ipAddress:$port', '/key_command/');

  @override
  Future<HttpResponse<void>> sendKey(TvKey key) async {
    final keyCodes = _keyMap[key];

    if (keyCodes == null) {
      dPrint('The $key key is not supported on Vizio TVs.');
      return HttpResponse.failure(
        'The $key key is not supported on Vizio TVs.',
      );
    }

    final body = {
      'KEYLIST': [
        {'CODESET': key, 'ACTION': 'KEYPRESS'},
      ],
    };

    final response = await _httpService.sendRequest(
      url: _keyCommandUrl,
      method: HttpMethod.put,
      body: body,
    );

    if (response.isSuccess) {
      return HttpResponse.success(null, statusCode: response.statusCode);
    }

    dPrint('Roku sendKey failed: ${response.errorMessage}');
    return HttpResponse.failure(
      response.errorMessage ?? ' Failed to send command to $name.',
      statusCode: response.statusCode,
    );
  }
}
