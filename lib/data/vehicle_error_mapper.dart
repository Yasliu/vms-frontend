import '../core/network/api_exception.dart';

/// Turns the backend's technical answers about saving a vehicle into messages
/// a person can act on. Lives in the data layer so screens never parse server
/// wording.
class VehicleErrorMapper {
  VehicleErrorMapper._();

  static const _labels = {
    'vehicleNumber': 'vehicle number',
    'company': 'company',
    'type': 'type',
    'brand': 'brand',
    'model': 'model',
    'status': 'status',
  };

  /// For create and update.
  static ApiException forSave(ApiException e) {
    switch (e.kind) {
      case ApiErrorKind.conflict:
        final number = e.details['vehicleNumber'];
        if (number is String) {
          final message =
              'Vehicle number $number is already registered. '
              'Use a different number.';
          return _copy(e, message, {'vehicleNumber': message});
        }
        return _copy(
          e,
          'This change conflicts with another update. '
          'Refresh the list and try again.',
          const {},
        );

      case ApiErrorKind.validation:
        if (e.fieldErrors.isEmpty) {
          return _copy(
            e,
            'The vehicle details could not be saved. '
            'Check the form and try again.',
            const {},
          );
        }
        return _copy(e, 'Please correct the highlighted fields.', {
          for (final entry in e.fieldErrors.entries)
            entry.key: fieldMessage(entry.key, entry.value),
        });

      case ApiErrorKind.notFound:
        return _copy(
          e,
          'This vehicle no longer exists. It may have been deleted. '
          'Go back and refresh the list.',
          const {},
        );

      default:
        return e;
    }
  }

  /// Rewrites one Bean Validation message ("must not be blank",
  /// "size must be between 0 and 50", ...) for [field].
  static String fieldMessage(String field, String serverMessage) {
    final label = _labels[field] ?? 'value';
    final text = serverMessage.toLowerCase();

    if (text.contains('must not be blank') ||
        text.contains('must not be null') ||
        text.contains('must not be empty')) {
      return field == 'status' ? 'Choose a status.' : 'Enter the $label.';
    }
    final size = RegExp(r'between \d+ and (\d+)').firstMatch(text);
    if (size != null) {
      return 'Use ${size.group(1)} characters or fewer for the $label.';
    }
    return 'The $label is not valid.';
  }

  static ApiException _copy(
    ApiException e,
    String message,
    Map<String, String> fieldErrors,
  ) => ApiException(
    kind: e.kind,
    message: message,
    statusCode: e.statusCode,
    fieldErrors: fieldErrors,
    details: e.details,
  );
}
