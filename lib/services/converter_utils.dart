import 'dart:convert';

import 'package:xml2json/xml2json.dart';

/// Takes raw input data (JSON or XML) and returns a normalized JSON string.
/// Throws a FormatException if the input is neither or is completely malformed.
String convertToRawJson(String rawData) {
  final trimmed = rawData.trimLeft();

  if (trimmed.isEmpty) throw const FormatException('Input data is empty');

  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      final parsed = jsonDecode(trimmed);
      return jsonEncode(parsed);
    } catch (error) {
      throw FormatException('Data started like JSON, but is malformed: $error');
    }
  }

  if (trimmed.startsWith('<')) {
    try {
      final transformer = Xml2Json();
      transformer.parse(trimmed);

      return transformer.toParker();
    } catch (error) {
      throw FormatException('Data started like XML, but is malformed: $error');
    }
  }

  throw const FormatException('Input is neither valid JSON or XML.');
}
