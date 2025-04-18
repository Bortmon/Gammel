// lib/models/login_result.dart

class LoginResult {
  final bool success;
  final String? employeeId;
  final String? nodeId;
  final String? authToken;
  final String? errorMessage;

  LoginResult({
    required this.success,
    this.employeeId,
    this.nodeId,
    this.authToken,
    this.errorMessage,
  });
}