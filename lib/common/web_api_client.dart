import 'dart:async';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:dio/dio.dart';

class WebAPIClient {
  late Dio client;
  Completer<bool> pingCompleter = Completer<bool>();
  late String url;

  WebAPIClient(WebAPI webAPI) {
    client = Dio();
    url = webAPI.url;
    client.options.connectTimeout = const Duration(seconds: 8);
    client.options.sendTimeout = const Duration(seconds: 60);
    client.options.receiveTimeout = const Duration(seconds: 60);
    client.options.headers = {
      'User-Agent': 'FlClash',
    };
    pingCompleter.complete(_ping());
  }

  Future<bool> _ping() async {
    try {
      final response = await client.get(url);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> upload(Uint8List data) async {
    try {
      final response = await client.post(
        url,
        data: Stream.fromIterable([data]),
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
          },
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      commonPrint.log('Web API upload error: $e');
      return false;
    }
  }

  Future<List<int>> download() async {
    try {
      final response = await client.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      commonPrint.log('Web API download error: $e');
      rethrow;
    }
  }
}