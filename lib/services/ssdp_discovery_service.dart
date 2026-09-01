import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:open_beam/services/logging_helper.dart';

class SsdpDiscoveryService {
  static const String _multicastAddress = '239.255.255.250';
  static const int _multicastPort = 1900;

  Stream<String> discoverTvIps({
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    RawDatagramSocket? socket;
    final seenIps = <String>{};

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.multicastHops = 2;

      const searchMessage =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1+00\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: ssdp:all\r\n'
          '\r\n';

      final data = utf8.encode(searchMessage);
      socket.send(data, InternetAddress(_multicastAddress), _multicastPort);

      // Listen directly to socket events with a timeout
      await for (final event in socket.timeout(
        timeout,
        onTimeout: (sink) => sink.close(),
      )) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final response = utf8.decode(datagram.data, allowMalformed: true);
            final senderIp = datagram.address.address;

            if (response.contains('roku:ecp') ||
                response.contains('vizio') ||
                response.contains('7345')) {
              if (seenIps.add(senderIp)) {
                dPrint('SSDP match found: $senderIp');
                yield senderIp;
              }
            }
          }
        }
      }
    } catch (e) {
      dPrint('SSDP discovery error: $e');
    } finally {
      socket?.close();
    }
  }
}
