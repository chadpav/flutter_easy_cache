import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_easy_cache/flutter_easy_cache.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterEasyCache cache;

  // dependencies
  SharedPreferences? sharedPreferences;
  FlutterSecureStorage? secureStorage;

  setUp(() async {
    FlutterEasyCache.setMockInitialValues();
    secureStorage ??= const FlutterSecureStorage();
    sharedPreferences ??= await SharedPreferences.getInstance();

    // sut
    cache = FlutterEasyCache.create(sharedPreferences!, secureStorage!, enalbeLogging: false);
  });

  tearDown(() async {
    await FlutterEasyCache.resetStatic();
  });

  group('AppSession Policy Tests', () {
    test('Add then Get String values', () async {
      String value = 'aString';
      await cache.addOrUpdate(key: 'aKey', value: value);

      // sut
      final retrievedValue = await cache.getValueOrNull<String>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get int values', () async {
      int value = 35;
      await cache.addOrUpdate(key: 'aKey', value: value);

      // sut
      final retrievedValue = await cache.getValueOrNull<int>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get bool values', () async {
      dynamic value = true;
      await cache.addOrUpdate<bool>(key: 'aKey', value: value);

      // sut
      final retrievedValue = await cache.getValueOrNull<bool>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get double values', () async {
      double value = 35.0;
      await cache.addOrUpdate<double>(key: 'aKey', value: value);

      // sut
      final retrievedValue = await cache.getValueOrNull<double>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get dictionary values', () async {
      Map<String, String> value = {
        'key1': 'value1',
        'key2': 'value2',
        //'key3': 3,
      };
      await cache.addOrUpdate<Map<String, dynamic>>(key: 'aKey', value: value);

      // sut
      final retrievedValue = await cache.getValueOrNull<Map<String, dynamic>>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get List<String> values', () async {
      final value = ['value1', 'value2'];
      await cache.addOrUpdate<List<String>>(key: 'aKey', value: value);

      // sut
      final retrievedValue = await cache.getValueOrNull<List<String>>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get List<dictionary> values', () async {
      List<Map<String, dynamic>> value = [
        {'key1': 'value1'},
        {'key2': 'value2'},
      ];
      await cache.addOrUpdate<List<Map<String, dynamic>>>(key: 'aKey', value: value);

      // sut
      final retrievedValue = await cache.getValueOrNull<List<Map<String, dynamic>>>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Update a value returns updated value from AppSession', () async {
      const value = 'aString';
      await cache.addOrUpdate(key: 'aKey', value: value);

      var retrievedValue = await cache.getValueOrNull<String>(key: 'aKey');
      expect(retrievedValue, value);

      const updatedValue = 'updatedString';
      await cache.addOrUpdate(key: 'aKey', value: updatedValue);
      retrievedValue = await cache.getValueOrNull(key: 'aKey');

      expect(retrievedValue, updatedValue);
    });

    test('Get value where underlying datatype does not match should just return null (not throw)', () async {
      await cache.addOrUpdate(key: 'aKey', value: 'aString', policy: CachePolicy.appSession);

      // sut
      final retrievedValue = await cache.getValueOrNull<int>(key: 'aKey');

      expect(retrievedValue, null);
    });

    test('Get value where underlying datatype does not match should just return default (not throw)', () async {
      await cache.addOrUpdate(key: 'aKey', value: 'aString', policy: CachePolicy.appSession);

      // sut
      final retrievedValue = await cache.getValueOrDefault<int>(key: 'aKey', defaultIfNull: 0);

      expect(retrievedValue, 0);
    });
  }, skip: false);
}
