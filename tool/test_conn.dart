import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

Future<void> main() async {
  // 1) 原始 HttpClient 访问
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('http://localhost:28080/actuator/health'));
    final resp = await req.close();
    final body = await resp.transform(const Utf8Decoder()).join();
    stdout.writeln('[http] ${resp.statusCode} $body');
  } catch (e) {
    stdout.writeln('[http] FAIL: $e');
  } finally {
    client.close();
  }

  // 2) Dio 访问
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  try {
    final resp = await dio.get<Map<String, dynamic>>('http://localhost:28080/actuator/health');
    stdout.writeln('[dio] ${resp.statusCode} ${resp.data}');
  } catch (e) {
    stdout.writeln('[dio] FAIL: $e');
  }
}
