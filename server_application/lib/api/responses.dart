import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../domain/rule_violation.dart';

/// An answer other than 200, e.g. 404 "Team nicht gefunden.".
class HttpError implements Exception {
  final int status;
  final String message;

  const HttpError(this.status, this.message);
}

/// A JSON answer, e.g. `jsonResponse(team.toJson(), status: 201)`.
Response jsonResponse(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );

/// Runs [handler] and turns errors into answers with a German message:
/// a [RuleViolation] of the domain becomes 409, an [HttpError] its status.
Future<Response> withErrorAnswers(Future<Response> Function() handler) async {
  try {
    return await handler();
  } on RuleViolation catch (e) {
    return jsonResponse({'message': e.message}, status: 409);
  } on HttpError catch (e) {
    return jsonResponse({'message': e.message}, status: e.status);
  }
}

/// Answers 403 unless the header [header] of [request] holds the secret
/// [code] of the team or game (T1.2, S1.2, ADR-005).
void requireCode(Request request, String header, String code) {
  if (request.headers[header] != code) {
    throw const HttpError(403, 'Dieser Link ist ungültig.');
  }
}

/// Reads the JSON body and builds an object with [fromJson], e.g.
/// `PlayerData.fromJson`. Answers 400 if the body is not valid JSON or
/// misses a field.
Future<T> readBody<T>(Request request, T? Function(dynamic) fromJson) async {
  try {
    final value = fromJson(jsonDecode(await request.readAsString()));
    if (value != null) return value;
  } catch (_) {
    // Not JSON, a missing field or a wrong type: all answered below.
  }
  throw const HttpError(400, 'Die Anfrage ist unvollständig.');
}
