import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/features/roadside_provider/provider_job_flow_pages.dart';

void main() {
  group('provider job data helpers', () {
    test('does not invent a fee when request has no fee', () {
      expect(providerJobFee(<String, dynamic>{}), isNull);
      expect(providerJobFeeLabel(<String, dynamic>{}), 'Fee not set');
    });

    test('uses a real estimated fee from the request', () {
      final Map<String, dynamic> data = {'estimatedFee': 4200};

      expect(providerJobFee(data), 4200);
      expect(providerJobFeeLabel(data), 'Rs.4200');
    });

    test('reads customer, service, vehicle and map location', () {
      final Map<String, dynamic> data = {
        'userName': 'Alex',
        'issueType': 'Flat tire',
        'vehicleType': 'Sedan',
        'latitude': 6.9271,
        'longitude': 79.8612,
      };

      expect(providerJobCustomer(data), 'Alex');
      expect(providerJobService(data), 'Flat tire');
      expect(providerJobVehicle(data), 'Sedan');
      expect(providerJobLocation(data)?.latitude, closeTo(6.9271, 0.000001));
    });
  });
}
