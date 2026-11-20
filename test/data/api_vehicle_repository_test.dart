import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vms_frontend/core/network/api_client.dart';
import 'package:vms_frontend/core/network/api_exception.dart';
import 'package:vms_frontend/data/api_vehicle_repository.dart';
import 'package:vms_frontend/models/vehicle.dart';

Map<String, Object?> vehicleJson(int id, {String status = 'ACTIVE'}) => {
  'id': id,
  'vehicleNumber': 'DHAKA-$id',
  'company': 'Acme',
  'type': 'Truck',
  'brand': 'Volvo',
  'model': 'FH16',
  'status': status,
};

Map<String, Object?> pageJson(
  List<Map<String, Object?>> content, {
  int page = 0,
  int totalPages = 1,
}) => {
  'content': content,
  'page': page,
  'size': 100,
  'totalElements': content.length,
  'totalPages': totalPages,
};

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

const input = VehicleInput(
  vehicleNumber: 'DHAKA-1',
  company: 'Acme',
  type: 'Truck',
  brand: 'Volvo',
  model: 'FH16',
  status: VehicleStatus.underMaintenance,
);

void main() {
  late List<http.Request> requests;

  ApiVehicleRepository repo(
    Future<http.Response> Function(http.Request) handler,
  ) {
    requests = [];
    return ApiVehicleRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        tokenProvider: () => 'test-token',
        httpClient: MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
      ),
    );
  }

  group('fetchAll', () {
    test('GETs /api/v1/vehicles and maps every field', () async {
      final r = repo(
        (_) async => json(
          pageJson([
            vehicleJson(1),
            vehicleJson(2, status: 'UNDER_MAINTENANCE'),
          ]),
        ),
      );

      final vehicles = await r.fetchAll();

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v1/vehicles');
      expect(requests.single.url.queryParameters, {'page': '0', 'size': '100'});
      expect(vehicles, hasLength(2));
      expect(vehicles[0].id, 1);
      expect(vehicles[0].vehicleNumber, 'DHAKA-1');
      expect(vehicles[0].company, 'Acme');
      expect(vehicles[0].type, 'Truck');
      expect(vehicles[0].status, VehicleStatus.active);
      expect(vehicles[1].status, VehicleStatus.underMaintenance);
    });

    test('follows pagination until the last page', () async {
      final r = repo((req) async {
        final page = int.parse(req.url.queryParameters['page']!);
        return json(
          pageJson([vehicleJson(page + 1)], page: page, totalPages: 3),
        );
      });

      final vehicles = await r.fetchAll();

      expect(requests.map((q) => q.url.queryParameters['page']), [
        '0',
        '1',
        '2',
      ]);
      expect(vehicles.map((v) => v.id), [1, 2, 3]);
    });

    test('an empty list is a valid result', () async {
      final r = repo((_) async => json(pageJson([], totalPages: 0)));

      expect(await r.fetchAll(), isEmpty);
      expect(requests, hasLength(1));
    });

    test(
      'an unknown status from the server is reported, not guessed',
      () async {
        final r = repo(
          (_) async => json(pageJson([vehicleJson(1, status: 'FLYING')])),
        );

        expect(
          r.fetchAll(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiErrorKind.unexpected,
            ),
          ),
        );
      },
    );

    test('a missing field is reported as unreadable data', () async {
      final r = repo(
        (_) async => json(
          pageJson([
            {'id': 1},
          ]),
        ),
      );

      expect(r.fetchAll(), throwsA(isA<ApiException>()));
    });
  });

  group('create', () {
    test('POSTs the contract fields and returns the saved vehicle', () async {
      final r = repo(
        (_) async => json(vehicleJson(7, status: 'UNDER_MAINTENANCE'), 201),
      );

      final saved = await r.create(input);

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/v1/vehicles');
      expect(jsonDecode(requests.single.body), {
        'vehicleNumber': 'DHAKA-1',
        'company': 'Acme',
        'type': 'Truck',
        'brand': 'Volvo',
        'model': 'FH16',
        'status': 'UNDER_MAINTENANCE',
      });
      expect(saved.id, 7);
    });

    test('a duplicate vehicle number becomes an error on that field', () async {
      final r = repo(
        (_) async => json({
          'title': 'Duplicate vehicle number',
          'detail': 'A vehicle with vehicle number DHAKA-1 already exists',
          'vehicleNumber': 'DHAKA-1',
        }, 409),
      );

      final e = await r
          .create(input)
          .then<ApiException?>(
            (_) => null,
            onError: (Object e) => e as ApiException,
          );

      expect(e!.kind, ApiErrorKind.conflict);
      expect(
        e.fieldErrors['vehicleNumber'],
        'Vehicle number DHAKA-1 is already registered. Use a different number.',
      );
      expect(e.message, e.fieldErrors['vehicleNumber']);
    });

    test('a generic 409 is not attached to a field', () async {
      final r = repo(
        (_) async =>
            json({'detail': 'The request conflicts with existing data.'}, 409),
      );

      final e = await r
          .create(input)
          .then<ApiException?>(
            (_) => null,
            onError: (Object e) => e as ApiException,
          );

      expect(e!.fieldErrors, isEmpty);
    });
  });

  group('server validation is shown in plain language', () {
    http.Response badRequest(List<Map<String, String>> errors) => json({
      'title': 'Validation failed',
      'detail': 'One or more fields are invalid.',
      'status': 400,
      'errors': errors,
    }, 400);

    test('blank and too-long values are rewritten per field', () async {
      final r = repo(
        (_) async => badRequest([
          {'field': 'vehicleNumber', 'message': 'must not be blank'},
          {'field': 'company', 'message': 'size must be between 0 and 100'},
          {'field': 'model', 'message': 'size must be between 0 and 50'},
        ]),
      );

      final e = await r
          .create(input)
          .then<ApiException?>(
            (_) => null,
            onError: (Object e) => e as ApiException,
          );

      expect(e!.kind, ApiErrorKind.validation);
      expect(e.message, 'Please correct the highlighted fields.');
      expect(e.fieldErrors, {
        'vehicleNumber': 'Enter the vehicle number.',
        'company': 'Use 100 characters or fewer for the company.',
        'model': 'Use 50 characters or fewer for the model.',
      });
      expect(e.fieldErrors.values.join(), isNot(contains('must not')));
      expect(e.fieldErrors.values.join(), isNot(contains('size must')));
    });

    test('the same rewriting applies on update', () async {
      final r = repo(
        (_) async => badRequest([
          {'field': 'status', 'message': 'must not be null'},
        ]),
      );

      final e = await r
          .update(3, input)
          .then<ApiException?>(
            (_) => null,
            onError: (Object e) => e as ApiException,
          );

      expect(e!.fieldErrors, {'status': 'Choose a status.'});
    });

    test(
      'a vehicle deleted elsewhere is explained, without ids or server wording',
      () async {
        final r = repo(
          (_) async => json({
            'detail': 'Vehicle with id 3 was not found',
            'status': 404,
          }, 404),
        );

        final e = await r
            .update(3, input)
            .then<ApiException?>(
              (_) => null,
              onError: (Object e) => e as ApiException,
            );

        expect(e!.kind, ApiErrorKind.notFound);
        expect(e.message, contains('no longer exists'));
        expect(e.message, isNot(contains('id 3')));
      },
    );

    test(
      'a server fault gets the standard message, not the server text',
      () async {
        final r = repo(
          (_) async => json({'detail': 'An unexpected error occurred.'}, 500),
        );

        final e = await r
            .create(input)
            .then<ApiException?>(
              (_) => null,
              onError: (Object e) => e as ApiException,
            );

        expect(e!.kind, ApiErrorKind.server);
        expect(
          e.message,
          'The server ran into a problem. Please try again later.',
        );
      },
    );
  });

  group('update', () {
    test('PUTs to /api/v1/vehicles/{id}', () async {
      final r = repo((_) async => json(vehicleJson(5)));

      final saved = await r.update(5, input);

      expect(requests.single.method, 'PUT');
      expect(requests.single.url.path, '/api/v1/vehicles/5');
      expect(jsonDecode(requests.single.body)['status'], 'UNDER_MAINTENANCE');
      expect(saved.id, 5);
    });
  });

  group('delete', () {
    test('DELETEs /api/v1/vehicles/{id} and accepts 204', () async {
      final r = repo((_) async => http.Response('', 204));

      await r.delete(9);

      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/api/v1/vehicles/9');
    });

    test('404 propagates as notFound', () async {
      final r = repo(
        (_) async => json({'detail': 'Vehicle with id 9 was not found'}, 404),
      );

      expect(
        r.delete(9),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.notFound,
          ),
        ),
      );
    });
  });
}
