import 'dart:convert';
import 'dart:io';

import 'package:openapi/api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:server_application/api/game_api.dart';
import 'package:server_application/api/team_api.dart';
import 'package:server_application/storage/game_repository.dart';
import 'package:server_application/storage/team_repository.dart';

/// Names of the environment variables the server reads at start.
class EnvVariables {
  static const port = 'SERVER_PORT';

  /// Folder for teams.json and games/ (ADR-004), default "data".
  static const dataDir = 'DATA_DIR';
}

final _router = Router()
  ..get('/', _rootHandler)
  ..get('/health', _healthHandler);

Response _rootHandler(Request request) {
  return Response.ok('Handball-Live-Statistik Server');
}

/// Answers GET /health with {"status": "ok"} as long as the server runs.
Response _healthHandler(Request request) {
  final health = Health(status: 'ok');
  return Response.ok(
    json.encode(health.toJson()),
    headers: {'content-type': 'application/json'},
  );
}

void main(List<String> args) async {
  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment[EnvVariables.port] ?? '8080');
  final dataDir = Platform.environment[EnvVariables.dataDir] ?? 'data';
  final teams = TeamRepository.open('$dataDir/teams.json');
  final games = GameRepository.open('$dataDir/games');

  // The first router that knows the path answers; the others give 404.
  final routes = Cascade()
      .add(_router.call)
      .add(TeamApi(teams).router.call)
      .add(GameApi(teams, games).router.call);
  final handler = Pipeline()
      .addMiddleware(logRequests())
      // The browser may send the team code header from another port.
      .addMiddleware(corsHeaders(headers: {
        ACCESS_CONTROL_ALLOW_HEADERS:
            'accept,content-type,origin,${TeamApi.codeHeader},'
                '${GameApi.tickerCodeHeader}',
      }))
      .addHandler(routes.handler);

  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}.');
}
