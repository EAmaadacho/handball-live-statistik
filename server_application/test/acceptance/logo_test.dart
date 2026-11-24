// Acceptance tests for the club logo (T6), see docs/user-stories.md.
import 'package:test/test.dart';

import 'running_server.dart';

/// The first bytes of a PNG image, followed by [size] bytes in total.
List<int> aPng({int size = 1024}) =>
    [0x89, 0x50, 0x4E, 0x47, ...List.filled(size - 4, 0)];

/// The first bytes of a JPG image, followed by [size] bytes in total.
List<int> aJpg({int size = 1024}) => [
      ...[0xFF, 0xD8, 0xFF, 0xE0],
      ...List.filled(size - 4, 0)
    ];

void main() {
  final server = useRunningServer();

  Future<(String id, String code)> createMettmann() async {
    final (_, json) = await server().post('/teams', body: newTeam());
    return (json['team']['id'] as String, json['code'] as String);
  }

  group('T6 the club logo', () {
    test('T6 TV Mettmann uploads its logo, everyone can load it', () async {
      final (id, code) = await createMettmann();
      final logo = aPng();

      final (status, team) =
          await server().putBytes('/teams/$id/logo', logo, code: code);
      final image = await server().getRaw('/teams/$id/logo');

      expect(status, 200);
      expect(team['hasLogo'], isTrue);
      expect(image.statusCode, 200);
      expect(image.bodyBytes, logo);
    });

    test('T6 without the team code nobody changes the logo', () async {
      final (id, _) = await createMettmann();

      final (status, _) = await server().putBytes('/teams/$id/logo', aPng());

      expect(status, 403);
    });
  });

  group('T6.1 only PNG and JPG up to 500 KB', () {
    test('T6_1 a JPG of 500 KB is accepted', () async {
      final (id, code) = await createMettmann();

      final (status, _) = await server()
          .putBytes('/teams/$id/logo', aJpg(size: 500 * 1024), code: code);

      expect(status, 200);
    });

    test('T6_1 a PNG of 501 KB is rejected with a clear message', () async {
      final (id, code) = await createMettmann();

      final (status, json) = await server()
          .putBytes('/teams/$id/logo', aPng(size: 501 * 1024), code: code);

      expect(status, 409);
      expect(json['message'], 'Das Logo darf höchstens 500 KB groß sein.');
    });

    test('T6_1 a GIF is rejected with a clear message', () async {
      final (id, code) = await createMettmann();
      final gif = [...'GIF89a'.codeUnits, ...List.filled(100, 0)];

      final (status, json) =
          await server().putBytes('/teams/$id/logo', gif, code: code);

      expect(status, 409);
      expect(json['message'], 'Bitte ein PNG- oder JPG-Bild hochladen.');
    });
  });

  group('T6.2 without a logo the short code is shown', () {
    test('T6_2 TV Mettmann without a logo: hasLogo false and no image',
        () async {
      final (id, _) = await createMettmann();

      final (_, team) = await server().get('/teams/$id');
      final image = await server().getRaw('/teams/$id/logo');

      expect(team['hasLogo'], isFalse);
      expect(team['shortCode'], 'TVM');
      expect(image.statusCode, 404);
    });
  });
}
