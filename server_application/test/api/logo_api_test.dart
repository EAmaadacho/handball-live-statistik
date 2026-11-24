import 'dart:convert';
import 'dart:io';

import 'package:server_application/api/team_api.dart';
import 'package:server_application/storage/logo_store.dart';
import 'package:server_application/storage/team_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'team_api_test.dart' show newMettmann, send;

/// The first bytes of a PNG and a JPG, enough for the server to tell them.
final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];
final jpg = [0xFF, 0xD8, 0xFF, 0xE0, 4, 5, 6];
final pdf = utf8.encode('%PDF-1.7 Spielplan');

void main() {
  late Directory dir;
  late TeamApi teamApi;

  TeamApi start() => TeamApi(TeamRepository.open('${dir.path}/teams.json'),
      logos: LogoStore('${dir.path}/logos'),
      newCode: () => 'secret-code',
      newId: () => 't1');

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('logo_api_');
    teamApi = start();
    await send(teamApi, 'POST', '/teams', body: newMettmann);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// Uploads [bytes] as the logo of TV Mettmann.
  Future<(int, dynamic)> upload(List<int> bytes,
      {String code = 'secret-code'}) async {
    final response = await teamApi.router.call(Request(
      'PUT',
      Uri.parse('http://localhost/teams/t1/logo'),
      body: bytes,
      headers: {TeamApi.codeHeader: code},
    ));
    return (response.statusCode, jsonDecode(await response.readAsString()));
  }

  Future<Response> getLogo() => teamApi.router
      .call(Request('GET', Uri.parse('http://localhost/teams/t1/logo')));

  group('T6 upload the club logo', () {
    test('T6 the PNG of TV Mettmann is stored and shown to everyone', () async {
      final (status, json) = await upload(png);
      final logo = await getLogo();

      expect(status, 200);
      expect(json['hasLogo'], isTrue);
      expect(logo.headers['content-type'], 'image/png');
      expect(await logo.read().expand((chunk) => chunk).toList(), png);
    });

    test('T6 a new JPG replaces the PNG', () async {
      await upload(png);
      await upload(jpg);

      final logo = await getLogo();

      expect(logo.headers['content-type'], 'image/jpeg');
      expect(File('${dir.path}/logos/t1.png').existsSync(), isFalse);
    });

    test('T6 the logo is still there after a server restart', () async {
      await upload(png);

      teamApi = start();
      final logo = await getLogo();

      expect(logo.statusCode, 200);
    });

    test('T6_1 a PDF is rejected', () async {
      final (status, json) = await upload(pdf);

      expect(status, 409);
      expect(json['message'], 'Bitte ein PNG- oder JPG-Bild hochladen.');
    });

    test('T6_1 a PNG over 500 KB is rejected, 500 KB are accepted', () async {
      final tooBig = [...png, ...List.filled(500 * 1024, 0)];
      final justRight = tooBig.sublist(0, 500 * 1024);

      final (statusTooBig, json) = await upload(tooBig);
      final (statusJustRight, _) = await upload(justRight);

      expect(statusTooBig, 409);
      expect(json['message'], 'Das Logo darf höchstens 500 KB groß sein.');
      expect(statusJustRight, 200);
    });

    test('T6_2 without a logo hasLogo is false and the logo gives 404',
        () async {
      final (_, team) = await send(teamApi, 'GET', '/teams/t1');
      final logo = await getLogo();

      expect(team['hasLogo'], isFalse);
      expect(logo.statusCode, 404);
    });

    test('without the team code the logo is not changed', () async {
      final (status, _) = await upload(png, code: 'wrong');

      expect(status, 403);
      expect((await getLogo()).statusCode, 404);
    });
  });
}
