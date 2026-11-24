import 'dart:convert';

import 'package:openapi/api.dart' as api;

import 'game_source.dart';

/// The server said no (403, 404, 409): its text for the page, e.g.
/// "Die Nummer 7 ist schon vergeben." (T2.1).
///
/// A wrong code (403) shows [forbidden], e.g. "Dieser Ticker-Link ist
/// ungültig." Null if the request did not arrive, e.g. no network (E1.6).
RejectedAction? rejectionOf(api.ApiException e, {required String forbidden}) {
  if (e.innerException != null) return null;
  if (e.code == 403) return RejectedAction(forbidden);
  if (e.code != 400 && e.code != 404 && e.code != 409) return null;
  try {
    final body = jsonDecode(e.message ?? '') as Map<String, dynamic>;
    return RejectedAction(body['message'] as String);
  } catch (_) {
    return const RejectedAction('Der Server hat die Eingabe abgelehnt.');
  }
}
