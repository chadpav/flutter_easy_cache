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
  static final FlutterEasyCache shared = FlutterEasyCache.create();

  Map<String, dynamic> inMemoryCache = {};
  SharedPreferences? preferences;
  FlutterSecureStorage? secureStorage;
  bool enalbeLogging;

  FlutterEasyCache({this.preferences, this.secureStorage, this.enalbeLogging = false});

  factory FlutterEasyCache.create() {
    return FlutterEasyCache(
      preferences: null,
      secureStorage: null,
    );
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
    inMemoryCache[key] = value;
    _consolePrint('FlexCache addOrUpdate $key=$value with AppSession Policy');
  }

  Future<void> _addOrUpdateAppInstall<T>({required String key, required T value}) async {
    await _initIfNeeded();

    if (value is String) {
      await preferences!.setString(key, value);
    } else if (value is bool) {
      await preferences!.setBool(key, value);
    } else if (value is int) {
      await preferences!.setInt(key, value);
    } else if (value is double) {
      await preferences!.setDouble(key, value);
    } else if (value is Map<String, dynamic>) {
      String jsonString = jsonEncode(value);
      await preferences!.setString(key, jsonString);
    } else if (value is List<String>) {
      await preferences!.setStringList(key, value);
    } else if (value is List<Map<String, dynamic>>) {
      final jsonStringList = value.map((e) => jsonEncode(e)).toList(growable: false);
      await preferences!.setStringList(key, jsonStringList);
    }
    _consolePrint('FlexCache addOrUpdate $key=$value with AppInstall Policy');
  }

  Future<void> _addOrUpdateSecureStorage<T>({required String key, required T value}) async {
    await _initIfNeeded();

    if (value is String) {
      await secureStorage?.write(key: key, value: value);
    } else if (value is bool) {
      await secureStorage?.write(key: key, value: value.toString());
    } else if (value is int) {
      await secureStorage?.write(key: key, value: value.toString());
    } else if (value is double) {
      await secureStorage?.write(key: key, value: value.toString());
    } else if (value is Map<String, dynamic>) {
      String jsonString = jsonEncode(value);
      await secureStorage?.write(key: key, value: jsonString);
    } else if (value is List<String>) {
      String jsonString = jsonEncode(value);
      await secureStorage?.write(key: key, value: jsonString);
    } else if (value is List<Map<String, dynamic>>) {
      String jsonString = jsonEncode(value);
      await secureStorage?.write(key: key, value: jsonString);
    }
    _consolePrint('FlexCache addOrUpdate $key=$value with Secure Policy');
  }

  /// Remove a value from cache
  /// Returns true if the value was removed
  /// TIP: Don't forget to AWAIT!
  Future<void> remove({required String key}) async {
    await _initIfNeeded();
    inMemoryCache.remove(key);
    await secureStorage?.delete(key: key);
    await preferences?.remove(key);
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
      _consolePrint('FlexCache Miss for $key');
    }

    return (value is T) ? value : null;
  }

  Future<T?> _getInMemoryValue<T>({required String key}) async {
    T? value;

    if (inMemoryCache.containsKey(key)) {
      value = inMemoryCache[key] as T?;
    }

    if (value != null) {
      _consolePrint('FlexCache Hit (in-memory) for $key');
    }

    return value;
  }

  Future<T?> _getPreferencesValue<T>({required String key}) async {
    await _initIfNeeded();

    T? value;

    if (preferences?.containsKey(key) == true) {
      try {
        if (T == String) {
          value = preferences?.getString(key) as T?;
        } else if (T == int) {
          value = preferences?.getInt(key) as T?;
        } else if (T == bool) {
          value = preferences?.getBool(key) as T?;
        } else if (T == double) {
          value = preferences?.getDouble(key) as T?;
        } else if (T == Map<String, dynamic>) {
          final jsonString = preferences?.getString(key);
          value = jsonString != null ? jsonDecode(jsonString) as T? : null;
        } else if (T == List<String>) {
          value = preferences?.getStringList(key) as T?;
        } else if (T == List<Map<String, dynamic>>) {
          final stringList = preferences?.getStringList(key) as List<String>;
          value = stringList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList() as T?;
        } else {
          throw Exception('FlexCache - Unsupported type');
        }
      } catch (e) {
        _consolePrint('WARN: FlexCache error getting $key: "$e"');
        rethrow;
      }
    }

    if (value != null) {
      _consolePrint('FlexCache Hit (preferences) for $key');
    }

    return value;
  }

  Future<T?> _getSecureValue<T>({required String key}) async {
    await _initIfNeeded();
    T? value;

    if (await secureStorage?.containsKey(key: key) == true) {
      try {
        if (T == String) {
          value = await secureStorage?.read(key: key) as T?;
        } else if (T == bool) {
          final stringValue = await secureStorage?.read(key: key);
          value = bool.tryParse(stringValue ?? '', caseSensitive: false) as T?;
        } else if (T == int) {
          final stringValue = await secureStorage?.read(key: key);
          value = int.tryParse(stringValue ?? '') as T?;
        } else if (T == double) {
          final stringValue = await secureStorage?.read(key: key);
          value = double.tryParse(stringValue ?? '') as T?;
        } else if (T == Map<String, dynamic>) {
          final jsonString = await secureStorage?.read(key: key);
          value = jsonString != null ? jsonDecode(jsonString) as T? : null;
        } else if (T == List<String>) {
          final jsonString = await secureStorage?.read(key: key);
          final list = jsonString != null ? jsonDecode(jsonString) as List<dynamic> : null;
          value = list?.cast<String>() as T?;
        } else if (T == List<Map<String, dynamic>>) {
          final jsonString = await secureStorage?.read(key: key);
          final list = jsonString != null ? jsonDecode(jsonString) as List<dynamic> : null;
          value = list?.cast<Map<String, dynamic>>() as T?;
        } else {
          throw Exception('FlexCache - Unsupported type');
        }
      } catch (e) {
        _consolePrint('WARN: FlexCache error getting $key: "$e"');
        rethrow;
      }
    }

    if (value != null) {
      _consolePrint('FlexCache Hit (secure storage) for $key');
    }

    return value;
  }

  /// Clear everything from cache
  /// TIP: Don't forget to AWAIT!
  Future<void> purgeAll() async {
    await _initIfNeeded();
    await purgeAppSession();
    await purgeAppInstall();
    await purgeSecureStorage();
  }

  /// Clear everything from cache with the AppSession policy
  /// TIP: Don't forget to AWAIT!
  Future<void> purgeAppSession() async {
    await _initIfNeeded();
    inMemoryCache.clear();
    _consolePrint('FlexCache app session cache was purged');
  }

  /// Clear everything from cache with the AppInstall policy
  /// TIP: Don't forget to AWAIT!
  Future<void> purgeAppInstall() async {
    await _initIfNeeded();
    await preferences?.clear();
    _consolePrint('FlexCache app install cache was purged');
  }

  /// Clear everything from cache with the Secure policy
  /// TIP: Don't forget to AWAIT!
  Future<void> purgeSecureStorage() async {
    await _initIfNeeded();
    await secureStorage?.deleteAll();
    _consolePrint('FlexCache secure storage cache was purged');
  }

  // PRIVATE METHODS

  /// lazily init dependencies because we can't use async in the constructor
  Future<void> _initIfNeeded() async {
    // init shared preferences which returns a Future
    preferences ??= await SharedPreferences.getInstance();

    // init secure storage
    if (secureStorage == null) {
      const aOptions = AndroidOptions(
        encryptedSharedPreferences: true,
      );
      const iOptions = IOSOptions(
        accessibility: KeychainAccessibility.unlocked,
        synchronizable: true, // will sync across iCloud to other devices
      );
      secureStorage = const FlutterSecureStorage(
        aOptions: aOptions,
        iOptions: iOptions,
      );
    }
  }

  void _assertTypeSupport<T>(dynamic value) {
    // 1 - check if a type was provided for T
    if (T == dynamic) {
      throw ArgumentError('FlexCache: Specify a type for T');
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
          'FlexCache - Unsupported type $T. Only primitives, List<String>, Map<String, dynamic>, and List<Map<String, dynamic>> are supported.');
    }

    // 4 - if value is not null, check if the type will cast to type T
    if (value != null) {
      final castValue = value as T?;
      if (castValue == null) {
        throw Exception('FlexCache - Type mismatch. ${value.runtimeType} is not a $T');
      }
    }
  }

  void _consolePrint(String msg) {
    if (enalbeLogging) debugPrint(msg);
  }
}
