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
    TvKey.up: (3, 8),
    TvKey.down: (3, 0),
    TvKey.left: (3, 1),
    TvKey.right: (3, 7),
    TvKey.select: (3, 2),
    TvKey.back: (4, 0),
    TvKey.home: (4, 3),
    TvKey.volDown: (5, 0),
    TvKey.volUp: (5, 1),
    TvKey.playPause: (2, 3),
    TvKey.mute: (5, 4),
    TvKey.powerOn: (11, 1),
    TvKey.powerOff: (11, 0),
  };

  Uri get _keyCommandUrl => Uri.https('$ipAddress:$port', '/key_command/');

  @override
  Future<HttpResponse<void>> sendKey(TvKey key) async {
    dPrint(authToken);
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

    final headers = {'AUTH': authToken};

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
