import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trainy/services/settings_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cloud device state is stored outside the training database', () async {
    final settings = SettingsDatabase.instance;
    expect(await settings.getSyncEnabled(), isFalse);
    expect(await settings.getLastSyncMillis(), 0);

    await settings.setSyncEnabled(true);
    await settings.setLastSyncMillis(1234);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(SettingsDatabase.syncEnabledPreferenceKey),
      isTrue,
    );
    expect(preferences.getInt(SettingsDatabase.lastSyncPreferenceKey), 1234);
  });
}
