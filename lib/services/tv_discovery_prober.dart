import 'package:open_beam/models/http_method.dart';
import 'package:open_beam/models/paired_tv_device.dart';
import 'package:open_beam/services/http_service.dart';

class DiscoveredTvCandidate {
  final String ipAddress;
  final String defaultName;
  final TvBrand brand;
  final int port;
  final bool requiresPairing;

  const DiscoveredTvCandidate({
    required this.ipAddress,
    required this.defaultName,
    required this.brand,
    required this.port,
    required this.requiresPairing,
  });
}

class TvDiscoveryProber {
  final HTTPService _httpService;

  const TvDiscoveryProber({required this._httpService});

  Future<DiscoveredTvCandidate> probeIp(String ip) async {
    final rokuCandidate = await _probeRoku(ip);
    if (rokuCandidate != null) return rokuCandidate;

    final vizioCandidate = await _probeVizio(ip);
    if (vizioCandidate != null) return vizioCandidate;

    return null;
  }

  Future<DiscoveredTvCandidate?> _probeRoku(String ip) async {
    try {
      final res = await _httpService.sendRequest(
        url: Uri.http('$ip:8060', '/query/device-info'),
        method: HttpMethod.get,
        timeout: const Duration(seconds: 5),
      );

      if (res.isSuccess) {
        return DiscoveredTvCandidate(
          ipAddress: ip,
          defaultName: 'Roku TV',
          brand: TvBrand.roku,
          port: 8060,
          requiresPairing: false,
        );
      }
    } catch (error) {}
    return null;
  }

  Future<DiscoveredTvCandidate?> _probeVizio(String ip) async {
    try {
      final res = await _httpService.sendRequest(
        url: Uri.https('$ip:7345', '/state/device/device_info'),
        method: HttpMethod.get,
        timeout: const Duration(seconds: 5),
      );

      if (res.isSuccess || res.statusCode == 401 || res.statusCode == 403) {
        return DiscoveredTvCandidate(
          ipAddress: ip,
          defaultName: 'Vizio TV',
          brand: TvBrand.vizio,
          port: 7345,
          requiresPairing: true,
        );
      }
    } catch (error) {}
    return null;
  }
}
