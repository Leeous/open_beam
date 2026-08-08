import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class VizioRemoteService {
  final String tvIp;
  final int port;
  final String? authToken;

  late final http.Client _client;

  VizioRemoteService({required this.tvIp, this.port = 7345, this.authToken}) {
    // Override HTTP client to accept self-signed SSL certs
    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    _client = IOClient(ioClient);
  }

  Future<Map<String, dynamic>?> sendPutRequest ({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('https://$tvIp:$port$endpoint');

    final headers = {
      'Content-Type': 'application/json',
      'AUTH' : ?authToken,
    };

    try {
      final response = await _client.put(
        uri,
        headers: headers,
        body: jsonEncode(body)
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('HTTP Error: ${response.statusCode} - ${response.body}');
        return null;
      } 
      } catch (error) {
        print('Connection Error: $error');
        return null;
    }
  }
}
