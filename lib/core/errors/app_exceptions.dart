class AppException implements Exception {
  final String message;
  final dynamic details;

  const AppException(this.message, [this.details]);

  @override
  String toString() => message;
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.details]);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.details]);
}

class DatabaseOperationException extends AppException {
  const DatabaseOperationException(super.message, [super.details]);
}

class BusinessRuleException extends AppException {
  const BusinessRuleException(super.message, [super.details]);
}
