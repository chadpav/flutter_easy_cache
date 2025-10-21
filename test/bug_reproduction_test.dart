import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_easy_cache/flutter_easy_cache.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These tests are designed to expose specific bugs found in code review
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterEasyCache cache;
  SharedPreferencesWithCache? sharedPreferences;
  FlutterSecureStorage? secureStorage;

  setUp(() async {
    FlutterEasyCache.setMockInitialValues();
    secureStorage ??= const FlutterSecureStorage();
    sharedPreferences ??=
        await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());
    cache = FlutterEasyCache.create(sharedPreferences!, secureStorage!, enableLogging: true);
  });

  tearDown(() async {
    await FlutterEasyCache.resetStatic();
  });

  group('Bug Reproduction Tests', () {
    // Bug #2: int.parse() should use tryParse() to avoid throwing
    test('BUG #2: Reading non-existent int from secure storage should not throw FormatException', () async {
      // First, add and then remove an int to ensure secure storage is initialized
      await cache.addOrUpdate(key: 'tempInt', value: 42, policy: CachePolicy.secure);
      await cache.remove(key: 'tempInt');

      // Now try to read a key that was never set
      // With int.parse(), this will throw FormatException: Invalid radix-10 number (at character 1)
      // With int.tryParse(), this will return null gracefully

      int? retrievedValue;
      bool didThrow = false;

      try {
        retrievedValue = await cache.getValueOrNull<int>(key: 'neverSetIntKey');
      } catch (e) {
        didThrow = true;
        // Exception caught: $e
      }

      expect(didThrow, false, reason: 'Should use int.tryParse() instead of int.parse() to avoid throwing');
      expect(retrievedValue, null);
    });

    // Bug #3: Null pointer when reading non-existent List<Map>
    test('BUG #3: Reading non-existent List<Map> from preferences should not throw', () async {
      // Initialize preferences
      await cache.addOrUpdate(key: 'dummy', value: 'value', policy: CachePolicy.appInstall);

      // Try to read a List<Map> that doesn't exist
      // Line 198: final stringList = _preferences?.getStringList(key) as List<String>;
      // This will throw TypeError: Null check operator used on a null value

      List<Map<String, dynamic>>? retrievedValue;
      bool didThrow = false;

      try {
        retrievedValue = await cache.getValueOrNull<List<Map<String, dynamic>>>(key: 'neverSetListMapKey');
      } catch (e) {
        didThrow = true;
        // Exception caught: $e
      }

      expect(didThrow, false, reason: 'Should check for null before casting');
      expect(retrievedValue, null);
    });

    // Bug #1: Missing await in addOrUpdate switch statement
    test('BUG #1: addOrUpdate should await async operations in switch statement', () async {
      // This test tries to verify that the Future completes only after write finishes
      // In practice, this bug might not be caught by tests due to fast execution
      // But it violates the async contract

      const value = 'test-value';

      // Create a list to track execution order
      final executionOrder = <String>[];

      cache.addOrUpdate(key: 'testKey', value: value, policy: CachePolicy.appInstall).then((_) {
        executionOrder.add('addOrUpdate completed');
      });

      // Small delay to let async operations settle
      await Future.delayed(const Duration(milliseconds: 10));
      executionOrder.add('after delay');

      final retrievedValue = await cache.getValueOrNull<String>(key: 'testKey');

      expect(retrievedValue, value);
      expect(executionOrder, contains('addOrUpdate completed'));
    });
  });
}
