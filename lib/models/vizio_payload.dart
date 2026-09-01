class VizioPairingInitiation {
  final bool isSuccess;
  final String? pairingReqToken;
  final int? challengeType;
  final String? errorMessage;

  const VizioPairingInitiation._({
    required this.isSuccess,
    this.pairingReqToken,
    this.challengeType,
    this.errorMessage,
  });

  factory VizioPairingInitiation.success({
    required String pairingReqToken,
    required int challengeType,
  }) => VizioPairingInitiation._(
    isSuccess: true,
    pairingReqToken: pairingReqToken,
    challengeType: challengeType,
  );

  factory VizioPairingInitiation.failure(String error) =>
      VizioPairingInitiation._(isSuccess: false, errorMessage: error);
}

class VizioPairingResult {
  final bool isSuccess;
  final String? authToken;
  final String? errorMessage;

  const VizioPairingResult._({
    required this.isSuccess,
    this.authToken,
    this.errorMessage,
  });

  factory VizioPairingResult.success(String authToken) =>
      VizioPairingResult._(isSuccess: true, authToken: authToken);

  factory VizioPairingResult.failure(String error) =>
      VizioPairingResult._(isSuccess: false, errorMessage: error);
}
