import 'package:open_beam/models/http_method.dart';
import 'package:open_beam/models/tv_key.dart';
import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/services/logging_helper.dart';
import 'package:open_beam/services/tv_service.dart';

class VizioTvService extends TVService {
  final HTTPService _httpService;
  final String authToken;
  final int port;

  const VizioTvService({
    required super.ipAddress,
    required super.name,
    required this.authToken,
    this.port = 7345,
    required this._httpService,
  });

  static const Map<TvKey, (int codeSet, int code)> _keyMap = {
    TvKey.up: (0, 0),
    TvKey.down: (0, 0),
    TvKey.left: (0, 0),
    TvKey.right: (0, 0),
    TvKey.select: (0, 0),
    TvKey.back: (0, 0),
    TvKey.home: (0, 0),
    TvKey.volDown: (0, 0),
    TvKey.volUp: (0, 0),
    TvKey.playPause: (0, 0),
    TvKey.mute: (0, 0),
    TvKey.powerOn: (0, 0),
    TvKey.powerOff: (0, 0),
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
        {'CODESET': keyCodes.$1, 'CODE': keyCodes.$2, 'ACTION': 'KEYPRESS'},
      ],
    };

    final headers = {'AUTH-TOKEN': authToken};

    final response = await _httpService.sendRequest(
      url: _keyCommandUrl,
      method: HttpMethod.put,
      headers: headers,
      body: body,
    );

    if (response.isSuccess) {
      return HttpResponse.success(null, statusCode: response.statusCode);
    }

    dPrint('Vizio sendKey failed: ${response.errorMessage}');
    return HttpResponse.failure(
      response.errorMessage ?? ' Failed to send command to $name.',
      statusCode: response.statusCode,
    );
  }
}
