class AuthResult {
  final String message;
  final String? token;
  final String? resetToken;
  final bool needsVerification;
  final String? phone;

  const AuthResult({
    required this.message,
    this.token,
    this.resetToken,
    this.needsVerification = false,
    this.phone,
  });
}
