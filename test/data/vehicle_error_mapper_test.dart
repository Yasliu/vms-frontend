import 'package:flutter_test/flutter_test.dart';
import 'package:vms_frontend/core/network/api_exception.dart';
import 'package:vms_frontend/data/vehicle_error_mapper.dart';

ApiException error(
  ApiErrorKind kind, {
  Map<String, String> fieldErrors = const {},
  Map<String, Object?> details = const {},
}) => ApiException(
  kind: kind,
  message: 'raw server text',
  statusCode: 400,
  fieldErrors: fieldErrors,
  details: details,
);

void main() {
  group('fieldMessage', () {
    test('blank / null / empty become "Enter the …"', () {
      for (final raw in [
        'must not be blank',
        'must not be null',
        'must not be empty',
      ]) {
        expect(
          VehicleErrorMapper.fieldMessage('brand', raw),
          'Enter the brand.',
        );
      }
      expect(
        VehicleErrorMapper.fieldMessage('vehicleNumber', 'must not be blank'),
        'Enter the vehicle number.',
      );
    });

    test('status asks to choose rather than enter', () {
      expect(
        VehicleErrorMapper.fieldMessage('status', 'must not be null'),
        'Choose a status.',
      );
    });

    test('length limits name the real limit', () {
      expect(
        VehicleErrorMapper.fieldMessage(
          'vehicleNumber',
          'size must be between 0 and 30',
        ),
        'Use 30 characters or fewer for the vehicle number.',
      );
    });

    test('unknown wording falls back to a calm generic message', () {
      expect(
        VehicleErrorMapper.fieldMessage('model', 'some new server rule'),
        'The model is not valid.',
      );
      expect(
        VehicleErrorMapper.fieldMessage('mystery', 'whatever'),
        'The value is not valid.',
      );
    });
  });

  group('forSave', () {
    test('a duplicate number uses the server-normalized number and targets that field', () {
      final mapped = VehicleErrorMapper.forSave(
        error(ApiErrorKind.conflict, details: {'vehicleNumber': 'DHAKA 1'}),
      );

      expect(mapped.fieldErrors.keys, ['vehicleNumber']);
      expect(
        mapped.message,
        'Vehicle number DHAKA 1 is already registered. Use a different number.',
      );
    });

    test('a conflict that is not a duplicate stays out of the fields', () {
      final mapped = VehicleErrorMapper.forSave(error(ApiErrorKind.conflict));

      expect(mapped.fieldErrors, isEmpty);
      expect(mapped.message, contains('Refresh the list'));
    });

    test('validation without field details still gets a usable message', () {
      final mapped = VehicleErrorMapper.forSave(error(ApiErrorKind.validation));

      expect(mapped.message, contains('Check the form'));
      expect(mapped.message, isNot(contains('raw server text')));
    });

    test('other errors pass through untouched', () {
      final original = error(ApiErrorKind.network);

      expect(identical(VehicleErrorMapper.forSave(original), original), isTrue);
    });
  });
}
