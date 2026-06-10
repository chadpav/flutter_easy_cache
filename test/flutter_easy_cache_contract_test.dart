import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_easy_cache/flutter_easy_cache.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for the contract guarantees:
/// - wrong-type reads return null, they never throw (not even lazily)
/// - the cache never shares mutable state with callers
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

  group('Secure storage type safety', () {
    test(
        'store List<String>, read as List<Map> returns null (not a lazily-throwing list)',
        () async {
      await cache.addOrUpdate<List<String>>(
          key: 'aKey', value: ['a', 'b'], policy: CachePolicy.secure);

      final retrievedValue =
          await cache.getValueOrNull<List<Map<String, dynamic>>>(key: 'aKey');

      expect(retrievedValue, null);
    });

    test(
        'store List<Map>, read as List<String> returns null (not a lazily-throwing list)',
        () async {
      await cache.addOrUpdate<List<Map<String, dynamic>>>(
          key: 'aKey',
          value: [
            {'a': 1}
          ],
          policy: CachePolicy.secure);

      final retrievedValue =
          await cache.getValueOrNull<List<String>>(key: 'aKey');

      expect(retrievedValue, null);
    });

    test('store int, read as double returns null', () async {
      await cache.addOrUpdate<int>(
          key: 'aKey', value: 42, policy: CachePolicy.secure);

      final retrievedValue = await cache.getValueOrNull<double>(key: 'aKey');

      expect(retrievedValue, null);
    });

    test('store bool, read as String returns null', () async {
      await cache.addOrUpdate<bool>(
          key: 'aKey', value: true, policy: CachePolicy.secure);

      final retrievedValue = await cache.getValueOrNull<String>(key: 'aKey');

      expect(retrievedValue, null);
    });

    test('store double, read back returns the same double', () async {
      await cache.addOrUpdate<double>(
          key: 'aKey', value: 3.14, policy: CachePolicy.secure);

      final retrievedValue = await cache.getValueOrNull<double>(key: 'aKey');

      expect(retrievedValue, 3.14);
    });
  });

  group('AppSession mutation isolation', () {
    test(
        'mutating the original list after addOrUpdate does not change the cache',
        () async {
      final value = ['v1', 'v2'];
      await cache.addOrUpdate<List<String>>(
          key: 'aKey', value: value, policy: CachePolicy.appSession);

      value.add('v3');

      final retrievedValue =
          await cache.getValueOrNull<List<String>>(key: 'aKey');
      expect(retrievedValue, ['v1', 'v2']);
    });

    test('mutating a retrieved map does not change the cache', () async {
      await cache.addOrUpdate<Map<String, dynamic>>(
          key: 'aKey', value: {'a': 1}, policy: CachePolicy.appSession);

      final retrievedValue =
          await cache.getValueOrNull<Map<String, dynamic>>(key: 'aKey');
      retrievedValue!['b'] = 2;

      final retrievedAgain =
          await cache.getValueOrNull<Map<String, dynamic>>(key: 'aKey');
      expect(retrievedAgain, {'a': 1});
    });

    test(
        'mutating a nested map inside a retrieved List<Map> does not change the cache',
        () async {
      await cache.addOrUpdate<List<Map<String, dynamic>>>(
          key: 'aKey',
          value: [
            {'a': 1}
          ],
          policy: CachePolicy.appSession);

      final retrievedValue =
          await cache.getValueOrNull<List<Map<String, dynamic>>>(key: 'aKey');
      retrievedValue![0]['b'] = 2;

      final retrievedAgain =
          await cache.getValueOrNull<List<Map<String, dynamic>>>(key: 'aKey');
      expect(retrievedAgain, [
        {'a': 1}
      ]);
    });
  });

  group('Purge scoping', () {
    test('purge leaves non-cache keychain entries alone', () async {
      // simulate another part of the app writing directly to secure storage
      await secureStorage!
          .write(key: 'authToken', value: 'someTokenFromAnotherLib');
      await cache.addOrUpdate<String>(
          key: 'cached', value: 'x', policy: CachePolicy.secure);

      await cache.purge();

      expect(await secureStorage!.read(key: 'authToken'),
          'someTokenFromAnotherLib');
      expect(await cache.getValueOrNull<String>(key: 'cached'), null);
    });

    test('purge leaves non-cache shared preferences alone', () async {
      // simulate another part of the app writing directly to preferences
      await sharedPreferences!.setString('appSetting', 'keep');
      await cache.addOrUpdate<String>(
          key: 'cached', value: 'x', policy: CachePolicy.appInstall);

      await cache.purge();

      expect(sharedPreferences!.getString('appSetting'), 'keep');
      expect(await cache.getValueOrNull<String>(key: 'cached'), null);
    });
  });
}
