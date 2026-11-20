import 'dart:convert';

import 'package:http/http.dart';
import 'package:openapi/api.dart';
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

import '../bin/server.dart';

void main() {
  final port = '8081';
  final host = 'http://127.0.0.1:$port';
  late TestProcess process;

  setUp(() async {
    process = await TestProcess.start(
      'dart',
      ['run', 'bin/server.dart'],
      environment: {EnvVariables.port: port},
      forwardStdio: true,
    );

    await expectLater(
        process.stdout, emitsThrough(startsWith('Server listening on port')));
  });

  tearDown(() async => await process.kill());

  test('root answers with the server name', () async {
    final response = await get(Uri.parse('$host/'));

    expect(response.statusCode, 200);
    expect(response.body, 'Handball-Live-Statistik Server');
  });

  test('unknown path answers 404', () async {
    final response = await get(Uri.parse('$host/doesnotexist'));

    expect(response.statusCode, 404);
  });

  test('health answers status ok', () async {
    final response = await get(Uri.parse('$host/health'));

    expect(response.statusCode, 200);
    final health = Health.fromJson(json.decode(response.body));
    expect(health?.status, 'ok');
  });
}
