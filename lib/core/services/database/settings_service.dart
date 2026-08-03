import 'base_service.dart';

class SettingsService extends BaseService {
  Future<void> saveSetting(String key, dynamic value) async {
    await settingsBox?.put(key, value);
    notifyListeners();
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return settingsBox?.get(key, defaultValue: defaultValue);
  }
}
