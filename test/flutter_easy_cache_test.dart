import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_easy_cache/flutter_easy_cache.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterEasyCache cache;

  // dependencies
  late SharedPreferences sharedPreferences;
  late FlutterSecureStorage secureStorage;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    secureStorage = const FlutterSecureStorage();

    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    // sut
    cache = FlutterEasyCache.create(sharedPreferences, secureStorage, enalbeLogging: false);
  });

  test('Get a key that does not exist returns null value', () async {
    final retrievedValue = await cache.getValueOrNull<bool>(key: 'aKey');
    expect(retrievedValue, null);
  });

  test('Creating an EasyCache using shared returns a singleton', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    // create one cache and store a value
    final cacheOne = FlutterEasyCache.shared;
    await cacheOne.addOrUpdate<bool>(key: 'keyOne', value: true, policy: CachePolicy.appSession);

    // create another cache and retrieve the value
    final cacheTwo = FlutterEasyCache.shared;
    expect(cacheOne, cacheTwo);

    // sut, ensure this is the same instance and returns the value
    final retrievedValue = await cacheTwo.getValueOrNull<bool>(key: 'keyOne');
    expect(retrievedValue, true);
  });

  test('Not providing a Type for T throws an error when adding values', () async {
    dynamic value = true;

    expect(
      () async => await cache.addOrUpdate(key: 'aKey', value: value),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('Providing an unsupported pirmitive will throw', () async {
    Runes value = Runes('\u{1f44b} \u{1f44b} \u{1f44b}');

    // test that an async function throws
    expect(
      () async => await cache.addOrUpdate<Runes>(key: 'aKey', value: value),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('Providing an unsupported Type will throw', () async {
    List<int> value = [1, 2, 3];

    // test that an async function throws
    expect(
      () async => await cache.addOrUpdate(key: 'aKey', value: value),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('Providing a Type for a value that will not cast will throw an exception', () async {
    Map<String, dynamic> value = {'key1': 'value1', 'key2': 2, 'key3': true, 'key4': 3.14};

    // save and retrieve the value
    await cache.addOrUpdate(key: 'aKey', value: value);
    final correctValue = await cache.getValueOrNull<Map<String, dynamic>>(key: 'aKey');

    // values should match if I gave it the right types
    expect(value, correctValue);

    // should throw if I gave it the wrong type
    expect(() async => await cache.getValueOrNull<List<String>>(key: 'aKey'), throwsA(isA<TypeError>()));
  });

  test('Providing a typed value correctly infers type when adding values', () async {
    bool value = true;

    // write
    await cache.addOrUpdate<bool>(key: 'aKey', value: value);

    // read it back
    final retrievedValue = await cache.getValueOrNull<bool>(key: 'aKey');
    expect(retrievedValue, value);
  });

  test('Not providing a Type for T throws an error when getting values', () async {
    expect(
      () async => await cache.getValueOrNull(key: 'aKey'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('Getting a value with default if null', () async {
    const defaultValue = false;

    final retrievedValue = await cache.getValueOrDefault<bool>(key: 'aKeyThatDontExist', defaultIfNull: defaultValue);

    expect(retrievedValue, defaultValue);
  });

  test('Purging all the cache', () async {
    const value = true;

    await cache.addOrUpdate(key: 'aKey', value: value);

    await cache.purge();

    final retrievedValue = await cache.getValueOrNull<bool>(key: 'aKey');
    expect(retrievedValue, null);
  });

  test('Purging only the in-memory cache', () async {
    const value = true;

    await cache.addOrUpdate(key: 'aSessionKey', value: value, policy: CachePolicy.appSession);
    await cache.addOrUpdate(key: 'appInstallKey', value: value, policy: CachePolicy.appInstall);
    await cache.addOrUpdate(key: 'secureKey', value: value, policy: CachePolicy.secure);

    await cache.purge(includeAppInstall: false, includeSecureStorage: false);

    final retrievedValue = await cache.getValueOrNull<bool>(key: 'aSessionKey');
    expect(retrievedValue, null);

    final retrievedAppInstallValue = await cache.getValueOrNull<bool>(key: 'appInstallKey');
    expect(retrievedAppInstallValue, value);

    final retrievedSecureValue = await cache.getValueOrNull<bool>(key: 'secureKey');
    expect(retrievedSecureValue, value);
  });

  test('Providing a Type for T that doesnt match actual type will throw', () async {
    dynamic value = true;

    // by key
    expect(
      () async => await cache.addOrUpdate<int>(key: 'aKey', value: value),
      throwsA(isA<TypeError>()),
    );
  });

  test('Providing an unsupported Type for T will throw a TypeError', () async {
    dynamic value = true;

    // by key
    expect(
      () async => await cache.addOrUpdate<List<int>>(key: 'aKey', value: value),
      throwsA(isA<TypeError>()),
    );
  });

  test('Get a default value if the key does not exist', () async {
    // sut
    final retrievedValue = await cache.getValueOrDefault<bool>(key: 'aKeyThatDontExist', defaultIfNull: false);

    expect(retrievedValue, false);
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
  }, skip: false);

  group('AppInstall Policy Tests', () {
    test('Add then Get String values', () async {
      String value = 'aString';
      await cache.addOrUpdate(key: 'aKey', value: value, policy: CachePolicy.appInstall);

      // sut
      final retrievedValue = await cache.getValueOrNull<String>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get int values', () async {
      int value = 35;
      await cache.addOrUpdate(key: 'aKey', value: value, policy: CachePolicy.appInstall);

      // sut
      final retrievedValue = await cache.getValueOrNull<int>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get bool values', () async {
      dynamic value = true;
      await cache.addOrUpdate<bool>(key: 'aKey', value: value, policy: CachePolicy.appInstall);

      // sut
      final retrievedValue = await cache.getValueOrNull<bool>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get double values', () async {
      double value = 35.0;
      await cache.addOrUpdate<double>(key: 'aKey', value: value, policy: CachePolicy.appInstall);

      // sut
      final retrievedValue = await cache.getValueOrNull<double>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get dictionary values', () async {
      final value = {
        'key1': 'value1',
        'key2': 'value2',
      };
      await cache.addOrUpdate<Map<String, dynamic>>(key: 'aKey', value: value, policy: CachePolicy.appInstall);

      // sut
      final retrievedValue = await cache.getValueOrNull<Map<String, dynamic>>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get List<String> values', () async {
      final value = ['value1', 'value2'];
      await cache.addOrUpdate<List<String>>(key: 'aKey', value: value, policy: CachePolicy.appInstall);

      // sut
      final retrievedValue = await cache.getValueOrNull<List<String>>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get List<dictionary> values', () async {
      List<Map<String, dynamic>> value = [
        {'key1': 'value1'},
        {'key2': 'value2'},
      ];
      await cache.addOrUpdate<List<Map<String, dynamic>>>(key: 'aKey', value: value, policy: CachePolicy.appInstall);

      // sut
      final retrievedValue = await cache.getValueOrNull<List<Map<String, dynamic>>>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Update a value returns updated value from AppInstall', () async {
      const value = 'aString';
      await cache.addOrUpdate(key: 'aKey', value: value, policy: CachePolicy.appInstall);

      var retrievedValue = await cache.getValueOrNull<String>(key: 'aKey');
      expect(retrievedValue, value);

      const updatedValue = 'updatedString';
      await cache.addOrUpdate(key: 'aKey', value: updatedValue, policy: CachePolicy.appInstall);
      retrievedValue = await cache.getValueOrNull(key: 'aKey');

      expect(retrievedValue, updatedValue);
    });
  }, skip: false);

  group('Secure Policy Tests', () {
    test('Add then Get String values', () async {
      String value = 'aString';
      await cache.addOrUpdate(key: 'aKey', value: value, policy: CachePolicy.secure);

      // sut
      final retrievedValue = await cache.getValueOrNull<String>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get int values', () async {
      int value = 35;
      await cache.addOrUpdate(key: 'aKey', value: value, policy: CachePolicy.secure);

      // sut
      final retrievedValue = await cache.getValueOrNull<int>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get bool values', () async {
      dynamic value = true;
      await cache.addOrUpdate<bool>(key: 'aKey', value: value, policy: CachePolicy.secure);

      // sut
      final retrievedValue = await cache.getValueOrNull<bool>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get double values', () async {
      double value = 35.0;
      await cache.addOrUpdate<double>(key: 'aKey', value: value, policy: CachePolicy.secure);

      // sut
      final retrievedValue = await cache.getValueOrNull<double>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get dictionary values', () async {
      final value = {
        'key1': 'value1',
        'key2': 'value2',
      };
      await cache.addOrUpdate<Map<String, dynamic>>(key: 'aKey', value: value, policy: CachePolicy.secure);

      // sut
      final retrievedValue = await cache.getValueOrNull<Map<String, dynamic>>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Add then Get List<String> values', () async {
      final value = ['value1', 'value2'];
      await cache.addOrUpdate<List<String>>(key: 'aKey', value: value, policy: CachePolicy.secure);

      // sut
      final retrievedValue = await cache.getValueOrNull<List<String>>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Get List<String> values doesnt propogate later mutations', () async {
      final value = ['value1', 'value2'];
      await cache.addOrUpdate<List<String>>(key: 'aKey', value: value, policy: CachePolicy.secure);

      // sut
      final retrievedValue = await cache.getValueOrNull<List<String>>(key: 'aKey');

      // mutate the retrieved value
      expect(retrievedValue, value);
      retrievedValue!.add('value3');

      // get the value again
      final retrievedValueAgain = await cache.getValueOrNull<List<String>>(key: 'aKey');
      expect(retrievedValueAgain, value);
    });

    test('Add then Get List<dictionary> values', () async {
      List<Map<String, dynamic>> value = [
        {'key1': 'value1'},
        {'key2': 'value2'},
      ];
      await cache.addOrUpdate<List<Map<String, dynamic>>>(key: 'aKey', value: value, policy: CachePolicy.secure);

      // sut
      final retrievedValue = await cache.getValueOrNull<List<Map<String, dynamic>>>(key: 'aKey');

      expect(retrievedValue, value);
    });

    test('Update a value returns updated value from Secure Storage', () async {
      const value = 'aString';
      await cache.addOrUpdate(key: 'aKey', value: value, policy: CachePolicy.secure);

      var retrievedValue = await cache.getValueOrNull<String>(key: 'aKey');
      expect(retrievedValue, value);

      const updatedValue = 'updatedString';
      await cache.addOrUpdate(key: 'aKey', value: updatedValue, policy: CachePolicy.secure);
      retrievedValue = await cache.getValueOrNull(key: 'aKey');

      expect(retrievedValue, updatedValue);
    });
  }, skip: false);
}
