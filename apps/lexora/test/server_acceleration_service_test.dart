import 'package:flutter_test/flutter_test.dart';
import 'package:lexora/services/server_acceleration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'direct batch acceleration defaults on and persists the user choice',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = ServerAccelerationService.instance;

      expect(await service.isEnabled(), isTrue);

      await service.setEnabled(false);
      await service.setEnabled(true);
      final preferences = await SharedPreferences.getInstance();

      expect(service.enabled, isTrue);
      expect(
        preferences.getBool(ServerAccelerationService.preferenceKey),
        isTrue,
      );

      await service.setEnabled(false);
    },
  );
}
