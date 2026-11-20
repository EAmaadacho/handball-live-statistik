import 'dart:convert';
import 'dart:io';

import 'package:openapi/api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

/// Names of the environment variables the server reads at start.
class EnvVariables {
  static const port = 'SERVER_PORT';
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
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(_router.call);

  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}.');
}
