import 'package:open_beam/models/tv_key.dart';
import 'package:open_beam/services/http_service.dart';
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
    TvKey.volumeUp: 'VolumeUp',
    TvKey.volumeDown: 'VolumeDown',
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
}
