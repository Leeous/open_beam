import 'dart:async';
import 'dart:io';

import 'package:open_beam/models/http_method.dart';
import 'package:open_beam/models/paired_tv_device.dart';
import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/services/logging_helper.dart';

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

  @override
  String toString() {
    return 'DiscoveredTvCandidate(\n'
        '  ip: $ipAddress,\n'
        '  name: $defaultName,\n'
        '  brand: $brand,\n'
        '  port: $port,\n'
        '  requires pairing?: $requiresPairing\n'
        ')';
  }
}

class TvDiscoveryProber {
  final HTTPService _httpService;

  const TvDiscoveryProber({required this._httpService});

  Future<DiscoveredTvCandidate?> probeIp(String ip) async {
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
    } on SocketException catch (e) {
      dPrint('Roku probe: no connection to $ip: $e');
      return null;
    } on TimeoutException catch (e) {
      dPrint('Roku probe: timeout for $ip: $e');
      return null;
    } on HttpException catch (e) {
      dPrint('Roku probe: HTTP error for $ip: $e');
      return null;
    } on FormatException catch (e) {
      // Unexpected response format — surface to caller/test harness
      dPrint('Roku probe: unexpected response format from $ip: $e');
      rethrow;
    } catch (e, st) {
      // Unknown/unexpected errors should not be silently swallowed
      dPrint('Roku probe: unexpected error for $ip: $e\n$st');
      rethrow;
    }

    return null;
  }

  Future<DiscoveredTvCandidate?> _probeVizio(String ip) async {
    try {
      final res = await _httpService.sendRequest(
        url: Uri.https('$ip:7345', '/state/device/deviceinfo'),
        method: HttpMethod.get,
        timeout: const Duration(seconds: 5),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.isSuccess) {
        return DiscoveredTvCandidate(
          ipAddress: ip,
          defaultName: 'Vizio TV',
          brand: TvBrand.vizio,
          port: 7345,
          requiresPairing: true,
        );
      }
    } on SocketException catch (e) {
      dPrint('Vizio probe: no connection to $ip: $e');
      return null;
    } on TimeoutException catch (e) {
      dPrint('Vizio probe: timeout for $ip: $e');
      return null;
    } on HttpException catch (e) {
      dPrint('Vizio probe: HTTP error for $ip: $e');
      return null;
    } on FormatException catch (e) {
      dPrint('Vizio probe: unexpected response format from $ip: $e');
      rethrow;
    } catch (e, st) {
      dPrint('Vizio probe: unexpected error for $ip: $e\n$st');
      rethrow;
    }

    return null;
  }
}
