import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_easy_cache/flutter_easy_cache.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for migration of values written by versions before 0.1.0:
/// - secure storage: unprefixed keys holding untyped strings
/// - shared preferences: unprefixed keys
/// Legacy values stay readable (with the old lenient parsing) and are
/// rewritten to the new format on first successful read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterEasyCache cache;
  SharedPreferencesWithCache? sharedPreferences;
  FlutterSecureStorage? secureStorage;

  setUp(() async {
    FlutterEasyCache.setMockInitialValues();
    secureStorage ??= const FlutterSecureStorage();
    sharedPreferences ??= await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions());
    cache = FlutterEasyCache.create(sharedPreferences!, secureStorage!,
        enableLogging: false);
  });

  tearDown(() async {
    await FlutterEasyCache.resetStatic();
  });

  group('Secure storage legacy migration', () {
    test('legacy int value is readable and migrates to the typed format',
        () async {
      // legacy format: unprefixed key, value.toString()
      await secureStorage!.write(key: 'legacyInt', value: '42');

      final retrievedValue = await cache.getValueOrNull<int>(key: 'legacyInt');
      expect(retrievedValue, 42);

      // the legacy key is gone and the value now lives in the typed envelope
      expect(await secureStorage!.read(key: 'legacyInt'), null);
      final envelopeJson =
          await secureStorage!.read(key: 'easyCache.legacyInt');
      expect(envelopeJson, isNotNull);
      final envelope = jsonDecode(envelopeJson!) as Map<String, dynamic>;
      expect(envelope['__easy_cache_type__'], 'int');
      expect(envelope['__easy_cache_value__'], 42);

      // subsequent reads come from the new format
      expect(await cache.getValueOrNull<int>(key: 'legacyInt'), 42);
    });

    test('legacy Map value is readable and migrates', () async {
      await secureStorage!.write(key: 'legacyMap', value: jsonEncode({'a': 1}));

      final retrievedValue =
          await cache.getValueOrNull<Map<String, dynamic>>(key: 'legacyMap');
      expect(retrievedValue, {'a': 1});

      expect(await secureStorage!.read(key: 'legacyMap'), null);
      expect(await secureStorage!.read(key: 'easyCache.legacyMap'), isNotNull);
    });

    test('legacy List<String> value is readable and migrates', () async {
      await secureStorage!
          .write(key: 'legacyList', value: jsonEncode(['a', 'b']));

      final retrievedValue =
          await cache.getValueOrNull<List<String>>(key: 'legacyList');
      expect(retrievedValue, ['a', 'b']);

      expect(await secureStorage!.read(key: 'legacyList'), null);
    });

    test('legacy List<Map> value is readable and migrates', () async {
      await secureStorage!.write(
          key: 'legacyListMap',
          value: jsonEncode([
            {'a': 1}
          ]));

      final retrievedValue = await cache
          .getValueOrNull<List<Map<String, dynamic>>>(key: 'legacyListMap');
      expect(retrievedValue, [
        {'a': 1}
      ]);

      expect(await secureStorage!.read(key: 'legacyListMap'), null);
    });

    test(
        'legacy value keeps the old lenient typing until migrated, then locks in the first-read type',
        () async {
      // legacy "42" could be read as int OR double with the old code;
      // the first read decides the migrated type
      await secureStorage!.write(key: 'legacyNum', value: '42');

      final asDouble = await cache.getValueOrNull<double>(key: 'legacyNum');
      expect(asDouble, 42.0);

      // after migrating as double, an int read now honors type safety
      expect(await cache.getValueOrNull<int>(key: 'legacyNum'), null);
      expect(await cache.getValueOrNull<double>(key: 'legacyNum'), 42.0);
    });

    test('legacy value that fails to parse is not migrated and returns null',
        () async {
      await secureStorage!.write(key: 'legacyJunk', value: 'not-a-number');

      expect(await cache.getValueOrNull<int>(key: 'legacyJunk'), null);

      // untouched: still readable later under a type that does parse
      expect(await secureStorage!.read(key: 'legacyJunk'), 'not-a-number');
      expect(await cache.getValueOrNull<String>(key: 'legacyJunk'),
          'not-a-number');
    });

    test(
        'legacy wrong-element-type list returns null instead of throwing later',
        () async {
      // a legacy List<String> read as List<Map> must fail eagerly inside the cache
      await secureStorage!
          .write(key: 'legacyList', value: jsonEncode(['a', 'b']));

      final retrievedValue = await cache
          .getValueOrNull<List<Map<String, dynamic>>>(key: 'legacyList');
      expect(retrievedValue, null);

      // failed reads don't migrate or destroy the legacy value
      expect(
          await secureStorage!.read(key: 'legacyList'), jsonEncode(['a', 'b']));
    });
  });

  group('Shared preferences legacy migration', () {
    test('legacy String value is readable and migrates to the namespaced key',
        () async {
      await sharedPreferences!.setString('legacyPref', 'hello');

      final retrievedValue =
          await cache.getValueOrNull<String>(key: 'legacyPref');
      expect(retrievedValue, 'hello');

      expect(sharedPreferences!.getString('legacyPref'), null);
      expect(sharedPreferences!.getString('easyCache.legacyPref'), 'hello');

      // subsequent reads come from the namespaced key
      expect(await cache.getValueOrNull<String>(key: 'legacyPref'), 'hello');
    });

    test('legacy List<String> value is readable and migrates', () async {
      await sharedPreferences!.setStringList('legacyList', ['a', 'b']);

      final retrievedValue =
          await cache.getValueOrNull<List<String>>(key: 'legacyList');
      expect(retrievedValue, ['a', 'b']);

      expect(sharedPreferences!.getStringList('legacyList'), null);
      expect(
          sharedPreferences!.getStringList('easyCache.legacyList'), ['a', 'b']);
    });

    test('addOrUpdate then remove clears both namespaced and legacy keys',
        () async {
      await sharedPreferences!.setString('aKey', 'legacyValue');
      await secureStorage!.write(key: 'aKey', value: 'legacySecret');

      await cache.remove(key: 'aKey');

      expect(sharedPreferences!.getString('aKey'), null);
      expect(await secureStorage!.read(key: 'aKey'), null);
      expect(await cache.getValueOrNull<String>(key: 'aKey'), null);
    });
  });
}
