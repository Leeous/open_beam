import 'package:open_beam/models/paired_tv_device.dart';
import 'package:open_beam/models/tv_key.dart';
import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/services/tv_brands/roku/roku_tv_service.dart';
import 'package:open_beam/services/tv_brands/vizio/vizio_tv_service.dart';

abstract class TVService {
  final String ipAddress;
  final String name;

  const TVService({required this.ipAddress, required this.name});

  Future<HttpResponse<void>> sendKey(TvKey key);

  Future<HttpResponse<void>> up() => sendKey(TvKey.up);
  Future<HttpResponse<void>> down() => sendKey(TvKey.down);
  Future<HttpResponse<void>> left() => sendKey(TvKey.left);
  Future<HttpResponse<void>> right() => sendKey(TvKey.right);
  Future<HttpResponse<void>> select() => sendKey(TvKey.select);
  Future<HttpResponse<void>> back() => sendKey(TvKey.back);
  Future<HttpResponse<void>> home() => sendKey(TvKey.home);
  Future<HttpResponse<void>> volDown() => sendKey(TvKey.volDown);
  Future<HttpResponse<void>> volUp() => sendKey(TvKey.volUp);
  Future<HttpResponse<void>> playPause() => sendKey(TvKey.playPause);
  Future<HttpResponse<void>> mute() => sendKey(TvKey.mute);
  Future<HttpResponse<void>> powerOn() => sendKey(TvKey.powerOn);
  Future<HttpResponse<void>> powerOff() => sendKey(TvKey.powerOff);

  TVService createTVService(PairedTvDevice device, HTTPService httpService) {
    return switch (device.brand) {
      TvBrand.vizio => VizioTvService(
        ipAddress: device.ipAddress,
        name: device.name,
        authToken: device.authToken ?? '',
        httpService: httpService,
      ),
      TvBrand.roku => RokuTvService(
        ipAddress: device.ipAddress,
        name: device.name,
        httpService: httpService,
      ),
      _ => throw UnsupportedError('Brand ${device.brand} not supported yet.'),
    };
  }
}
