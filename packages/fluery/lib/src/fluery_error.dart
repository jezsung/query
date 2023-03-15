class FlueryError extends Error {
  FlueryError(this.message);

  final String message;

  @override
  String toString() => "Fluery error: $message";
}
