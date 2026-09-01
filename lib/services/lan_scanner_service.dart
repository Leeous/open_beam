import 'dart:async';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:open_beam/services/logging_helper.dart';
import 'package:open_beam/services/ssdp_discovery_service.dart';
import 'package:open_beam/services/tv_discovery_prober.dart';

class LanScannerService {
  final TvDiscoveryProber _prober;
  final SsdpDiscoveryService _ssdpService;
  final NetworkInfo _networkInfo;

  LanScannerService({
    required this._prober,
    SsdpDiscoveryService? ssdpService,
    NetworkInfo? networkInfo,
  }) : _ssdpService = ssdpService ?? SsdpDiscoveryService(),
       _networkInfo = networkInfo ?? NetworkInfo();

  Stream<DiscoveredTvCandidate> scan() {
    final discoveredIps = <String>{};
    final controller = StreamController<DiscoveredTvCandidate>();

    // Run scanning work in a detached async block so the Stream returned
    // by this method can be listened to while the scan proceeds and emits
    // discovered candidates via the controller.
    Future(() async {
      StreamSubscription<String>? ssdpSub;

      try {
        ssdpSub = _ssdpService.discoverTvIps().listen((ip) async {
          if (discoveredIps.add(ip)) {
            final candidate = await _prober.probeIp(ip);
            if (candidate != null && !controller.isClosed) {
              dPrint('Discovered TV via SSDP: ${candidate.defaultName} at $ip');
              controller.add(candidate);
            }
          }
        }, onError: (Object error) => dPrint('SSDP stream error: $error'));

        // Batch subnet sweep
        final localIp = await _networkInfo.getWifiIP();
        if (localIp != null && localIp.contains('.')) {
          final subnetPrefix = localIp.substring(
            0,
            localIp.lastIndexOf('.') + 1,
          );
          dPrint('Preforming subnet sweep on: ${subnetPrefix}0/24');

          const batchSize = 25;
          for (int i = 1; i <= 254; i += batchSize) {
            final batchIps = [
              for (int j = i; j < i + batchSize && j <= 254; j++)
                '$subnetPrefix$j',
            ];

            final results = await Future.wait(
              batchIps.map((ip) async {
                if (discoveredIps.contains(ip)) return null;
                return _prober.probeIp(ip);
              }),
            );

            for (final candidate in results) {
              if (candidate != null && discoveredIps.add(candidate.ipAddress)) {
                dPrint(
                  'Discovered TV via sweep: ${candidate.defaultName} at ${candidate.ipAddress}',
                );
                if (!controller.isClosed) {
                  controller.add(candidate);
                }
              }
            }
          }
        } else {
          dPrint('No active Wi-Fi connection detected; skipping subnet sweep');
        }
      } catch (error) {
        dPrint('Subnet sweep error: $error');
      } finally {
        if (ssdpSub != null) await ssdpSub.cancel();
        await controller.close();
      }
    });

    return controller.stream;
  }
}
