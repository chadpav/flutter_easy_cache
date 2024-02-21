library flutter_easy_cache;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CachePolicy {
  appSession, // stores in-memory only
  appInstall, // stores on disk only
  secure, // stores in keychain/keystore across installs
}

/// Flutter Easy Cache
/// Cache key/value pairs with the ability to set the cache policy for each key.
/// Supports scoping lifecycle of cache to the app session, app installation, or even across app installs (via keychain)
class FlutterEasyCache {
  static final FlutterEasyCache shared = FlutterEasyCache._internal();

  final Map<String, dynamic> _inMemoryCache = {};
  SharedPreferences? _preferences;
  FlutterSecureStorage? _secureStorage;
  bool _loggingEnabled;

  /// enables console logging in debug builds only
  set enableLogging(bool value) {
    _loggingEnabled = value;
  }

  FlutterEasyCache._internal(
      {SharedPreferences? preferences, FlutterSecureStorage? secureStorage, bool loggingEnabled = false})
      : _loggingEnabled = loggingEnabled,
        _secureStorage = secureStorage,
        _preferences = preferences;

  factory FlutterEasyCache.create(SharedPreferences preferences, FlutterSecureStorage secureStorage,
      {bool enalbeLogging = false}) {
    return FlutterEasyCache._internal(
        preferences: preferences, secureStorage: secureStorage, loggingEnabled: enalbeLogging);
  }

  /// Add a value to cache, replacing any existing value
  /// TIP: Don't forget to AWAIT!
  Future<void> addOrUpdate<T>(
      {required String key, required T value, CachePolicy policy = CachePolicy.appSession}) async {
    _assertTypeSupport<T>(value);

    // clear the key if it already exists
    await remove(key: key);

    switch (policy) {
      case CachePolicy.appSession:
        _addOrUpdateAppSession<T>(key: key, value: value);
      case CachePolicy.appInstall:
        _addOrUpdateAppInstall<T>(key: key, value: value);
      case CachePolicy.secure:
        _addOrUpdateSecureStorage<T>(key: key, value: value);
        break;
    }
  }

  Future<void> _addOrUpdateAppSession<T>({required String key, required T value}) async {
    _inMemoryCache[key] = value;
    _consolePrint('EasyCache addOrUpdate $key with AppSession Policy');
  }

  Future<void> _addOrUpdateAppInstall<T>({required String key, required T value}) async {
    await _initIfNeeded();

    if (value is String) {
      await _preferences!.setString(key, value);
    } else if (value is bool) {
      await _preferences!.setBool(key, value);
    } else if (value is int) {
      await _preferences!.setInt(key, value);
    } else if (value is double) {
      await _preferences!.setDouble(key, value);
    } else if (value is Map<String, dynamic>) {
      String jsonString = jsonEncode(value);
      await _preferences!.setString(key, jsonString);
    } else if (value is List<String>) {
      await _preferences!.setStringList(key, value);
    } else if (value is List<Map<String, dynamic>>) {
      final jsonStringList = value.map((e) => jsonEncode(e)).toList(growable: false);
      await _preferences!.setStringList(key, jsonStringList);
    }
    _consolePrint('EasyCache addOrUpdate "$key" with AppInstall Policy');
  }

  Future<void> _addOrUpdateSecureStorage<T>({required String key, required T value}) async {
    await _initIfNeeded();

    if (value is String) {
      await _secureStorage?.write(key: key, value: value);
    } else if (value is bool) {
      await _secureStorage?.write(key: key, value: value.toString());
    } else if (value is int) {
      await _secureStorage?.write(key: key, value: value.toString());
    } else if (value is double) {
      await _secureStorage?.write(key: key, value: value.toString());
    } else if (value is Map<String, dynamic>) {
      String jsonString = jsonEncode(value);
      await _secureStorage?.write(key: key, value: jsonString);
    } else if (value is List<String>) {
      String jsonString = jsonEncode(value);
      await _secureStorage?.write(key: key, value: jsonString);
    } else if (value is List<Map<String, dynamic>>) {
      String jsonString = jsonEncode(value);
      await _secureStorage?.write(key: key, value: jsonString);
    }
    _consolePrint('EasyCache addOrUpdate "$key" with Secure Policy');
  }

  /// Remove a value from cache
  /// Returns true if the value was removed
  /// TIP: Don't forget to AWAIT!
  Future<void> remove({required String key}) async {
    await _initIfNeeded();
    _inMemoryCache.remove(key);
    await _secureStorage?.delete(key: key);
    await _preferences?.remove(key);
  }

  /// Get a value from cache, or a default value if the key does not exist
  /// TIP: Don't forget to AWAIT!
  Future<T> getValueOrDefault<T>({required String key, required T defaultIfNull}) async {
    final value = await getValueOrNull<T>(key: key);
    return value ?? defaultIfNull;
  }

  /// Get a value from cache, or null if the key does not exist or types don't match
  /// TIP: Don't forget to AWAIT!
  Future<T?> getValueOrNull<T>({required String key}) async {
    _assertTypeSupport<T>(null);

    T? value;
    // 1 - check in-memory cache first
    value = await _getInMemoryValue<T>(key: key);

    // 2 - check sharedPreferences cache
    value ??= await _getPreferencesValue<T>(key: key);

    // 3 - check secure storage
    value ??= await _getSecureValue<T>(key: key);

    if (value == null) {
      _consolePrint('EasyCache Miss for "$key"');
    }

    return (value is T) ? value : null;
  }

  Future<T?> _getInMemoryValue<T>({required String key}) async {
    T? value;

    if (_inMemoryCache.containsKey(key)) {
      value = _inMemoryCache[key] as T?;
    }

    if (value != null) {
      _consolePrint('EasyCache Hit (in-memory) for "$key"');
    }

    return value;
  }

  Future<T?> _getPreferencesValue<T>({required String key}) async {
    await _initIfNeeded();

    T? value;

    if (_preferences?.containsKey(key) == true) {
      try {
        if (T == String) {
          value = _preferences?.getString(key) as T?;
        } else if (T == int) {
          value = _preferences?.getInt(key) as T?;
        } else if (T == bool) {
          value = _preferences?.getBool(key) as T?;
        } else if (T == double) {
          value = _preferences?.getDouble(key) as T?;
        } else if (T == Map<String, dynamic>) {
          final jsonString = _preferences?.getString(key);
          value = jsonString != null ? jsonDecode(jsonString) as T? : null;
        } else if (T == List<String>) {
          value = _preferences?.getStringList(key) as T?;
        } else if (T == List<Map<String, dynamic>>) {
          final stringList = _preferences?.getStringList(key) as List<String>;
          value = stringList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList() as T?;
        } else {
          throw Exception('EasyCache - Unsupported type');
        }
      } catch (e) {
        _consolePrint('WARN: EasyCache error getting "$key": "$e"');
        rethrow;
      }
    }

    if (value != null) {
      _consolePrint('EasyCache Hit (preferences) for "$key"');
    }

    return value;
  }

  Future<T?> _getSecureValue<T>({required String key}) async {
    await _initIfNeeded();
    T? value;

    if (await _secureStorage?.containsKey(key: key) == true) {
      try {
        if (T == String) {
          value = await _secureStorage?.read(key: key) as T?;
        } else if (T == bool) {
          final stringValue = await _secureStorage?.read(key: key);
          value = bool.tryParse(stringValue ?? '', caseSensitive: false) as T?;
        } else if (T == int) {
          final stringValue = await _secureStorage?.read(key: key);
          value = int.tryParse(stringValue ?? '') as T?;
        } else if (T == double) {
          final stringValue = await _secureStorage?.read(key: key);
          value = double.tryParse(stringValue ?? '') as T?;
        } else if (T == Map<String, dynamic>) {
          final jsonString = await _secureStorage?.read(key: key);
          value = jsonString != null ? jsonDecode(jsonString) as T? : null;
        } else if (T == List<String>) {
          final jsonString = await _secureStorage?.read(key: key);
          final list = jsonString != null ? jsonDecode(jsonString) as List<dynamic> : null;
          value = list?.cast<String>() as T?;
        } else if (T == List<Map<String, dynamic>>) {
          final jsonString = await _secureStorage?.read(key: key);
          final list = jsonString != null ? jsonDecode(jsonString) as List<dynamic> : null;
          value = list?.cast<Map<String, dynamic>>() as T?;
        } else {
          throw Exception('EasyCache - Unsupported type');
        }
      } catch (e) {
        _consolePrint('WARN: EasyCache error getting "$key": "$e"');
        rethrow;
      }
    }

    if (value != null) {
      _consolePrint('EasyCache Hit (secure storage) for "$key"');
    }

    return value;
  }

  /// Clear everything from cache
  /// TIP: Don't forget to AWAIT!
  Future<void> purge(
      {bool includeAppSession = true, bool includeAppInstall = true, bool includeSecureStorage = true}) async {
    await _initIfNeeded();
    if (includeAppSession) _purgeAppSession();
    if (includeAppInstall) await _purgeAppInstall();
    if (includeSecureStorage) await _purgeSecureStorage();
  }

  /// Clear everything from cache with the AppSession policy
  Future<void> _purgeAppSession() async {
    _inMemoryCache.clear();
    _consolePrint('EasyCache app session cache was purged');
  }

  /// Clear everything from cache with the AppInstall policy
  Future<void> _purgeAppInstall() async {
    await _preferences?.clear();
    _consolePrint('EasyCache app install cache was purged');
  }

  /// Clear everything from cache with the Secure policy
  Future<void> _purgeSecureStorage() async {
    await _secureStorage?.deleteAll();
    _consolePrint('EasyCache secure storage cache was purged');
  }

  // PRIVATE METHODS

  /// lazily init dependencies because we can't use async in the constructor
  Future<void> _initIfNeeded() async {
    // init shared preferences with 'easy_cache.' as the key prefix
    if (_preferences == null) {
      SharedPreferences.setPrefix('easy_cache');
      _preferences = await SharedPreferences.getInstance();
    }

    // init secure storage
    if (_secureStorage == null) {
      const aOptions = AndroidOptions(
        encryptedSharedPreferences: true,
      );
      const iOptions = IOSOptions(
        accessibility: KeychainAccessibility.unlocked,
        synchronizable: true, // will sync across iCloud to other devices
      );
      _secureStorage = const FlutterSecureStorage(
        aOptions: aOptions,
        iOptions: iOptions,
      );
    }
  }

  void _assertTypeSupport<T>(dynamic value) {
    // 1 - check if a type was provided for T
    if (T == dynamic) {
      throw ArgumentError('EasyCache: Specify a type for T');
    }

    bool isSupported = false;
    // 2 - check if the type is supported, had to write tests this way due to some limitation of Dart
    // each test had to be on it's own line using equality operator not isA
    if (T == List<String>) {
      isSupported = true;
    }
    if (T == Map<String, dynamic>) {
      isSupported = true;
    }
    if (T == List<Map<String, dynamic>>) {
      isSupported = true;
    }

    // 3 - if isSupported is false, check if the type is a primitive, else throw
    if (T != String && T != int && T != bool && T != double && !isSupported) {
      throw ArgumentError(
          'EasyCache - Unsupported type $T. Only primitives, List<String>, Map<String, dynamic>, and List<Map<String, dynamic>> are supported.');
    }

    // 4 - if value is not null, check if the type will cast to type T
    if (value != null) {
      final castValue = value as T?;
      if (castValue == null) {
        throw Exception('EasyCache - Type mismatch. ${value.runtimeType} is not a $T');
      }
    }
  }

  /// Initializes the shared preferences + Flutter secure storage packages with mock values for testing.
  /// With this you can directly
  ///
  /// If the singleton instance has been initialized already, it is nullified.
  @visibleForTesting
  static void setMockInitialValues(Map<String, String> values) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(values);
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterSecureStorage.setMockInitialValues(values);
  }

  void _consolePrint(String msg) {
    if (_loggingEnabled) debugPrint(msg);
  }
}
