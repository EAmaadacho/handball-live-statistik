/// Thrown when an action breaks a rule of the domain.
///
/// The [message] is German, because the server shows it to the user
/// unchanged (HTTP 409). Example: adding a second No. 7 next to Max fails
/// with "Die Nummer 7 ist schon vergeben."
class RuleViolation implements Exception {
  final String message;

  const RuleViolation(this.message);

  @override
  String toString() => 'RuleViolation: $message';
}
