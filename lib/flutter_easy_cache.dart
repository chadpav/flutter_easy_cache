library flutter_easy_cache;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NOTE: these imports are required for testing SharePreferences (see InitializeMockValues)
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

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

  /// Namespace for keys written to shared preferences and secure storage so
  /// purge() only ever deletes values owned by this cache.
  /// Values written by versions before 0.1.0 used unprefixed keys; they are
  /// migrated to this namespace on first successful read.
  static const String _keyPrefix = 'easyCache.';

  /// Envelope field names for typed secure storage values. Deliberately verbose
  /// to avoid colliding with keys inside user maps stored by the legacy format.
  static const String _envelopeTypeKey = '__easy_cache_type__';
  static const String _envelopeValueKey = '__easy_cache_value__';

  final Map<String, dynamic> _inMemoryCache = {};
  SharedPreferencesWithCache? _preferences;
  FlutterSecureStorage? _secureStorage;
  bool _loggingEnabled;

  /// enables console logging in debug builds only
  set enableLogging(bool value) {
    _loggingEnabled = value;
  }

  FlutterEasyCache._internal(
      {SharedPreferencesWithCache? preferences,
      FlutterSecureStorage? secureStorage,
      bool loggingEnabled = false})
      : _loggingEnabled = loggingEnabled,
        _secureStorage = secureStorage,
        _preferences = preferences;

  factory FlutterEasyCache.create(SharedPreferencesWithCache preferences,
      FlutterSecureStorage secureStorage,
      {bool enableLogging = false}) {
    return FlutterEasyCache._internal(
        preferences: preferences,
        secureStorage: secureStorage,
        loggingEnabled: enableLogging);
  }

  /// Add a value to cache, replacing any existing value
  /// TIP: Don't forget to AWAIT!
  Future<void> addOrUpdate<T>(
      {required String key,
      required T value,
      CachePolicy policy = CachePolicy.appSession}) async {
    _assertTypeSupport<T>(value);

    // clear the key if it already exists
    await remove(key: key);

    switch (policy) {
      case CachePolicy.appSession:
        await _addOrUpdateAppSession<T>(key: key, value: value);
      case CachePolicy.appInstall:
        await _addOrUpdateAppInstall<T>(key: key, value: value);
      case CachePolicy.secure:
        await _addOrUpdateSecureStorage<T>(key: key, value: value);
    }
  }

  Future<void> _addOrUpdateAppSession<T>(
      {required String key, required T value}) async {
    // store a deep copy so later mutations of the caller's value don't change the cache
    _inMemoryCache[key] = _deepCopy(value);
    _consolePrint('EasyCache addOrUpdate "$key" with AppSession Policy');
  }

  Future<void> _addOrUpdateAppInstall<T>(
      {required String key, required T value}) async {
    await _initIfNeeded();
    await _writePreferencesValue<T>(key: _prefixedKey(key), value: value);
    _consolePrint('EasyCache addOrUpdate "$key" with AppInstall Policy');
  }

  Future<void> _writePreferencesValue<T>(
      {required String key, required T value}) async {
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
      final jsonStringList =
          value.map((e) => jsonEncode(e)).toList(growable: false);
      await _preferences!.setStringList(key, jsonStringList);
    }
  }

  Future<void> _addOrUpdateSecureStorage<T>(
      {required String key, required T value}) async {
    await _initIfNeeded();

    // values are stored as a JSON envelope carrying the declared type, so reads
    // can enforce type safety even though secure storage only holds strings
    final envelope = jsonEncode({
      _envelopeTypeKey: _typeTag<T>(),
      _envelopeValueKey: value,
    });
    await _secureStorage?.write(key: _prefixedKey(key), value: envelope);
    _consolePrint('EasyCache addOrUpdate "$key" with Secure Policy');
  }

  /// Remove a value from cache across all storage layers
  /// TIP: Don't forget to AWAIT!
  Future<void> remove({required String key}) async {
    await _initIfNeeded();
    _inMemoryCache.remove(key);
    await _secureStorage?.delete(key: _prefixedKey(key));
    await _secureStorage?.delete(key: key); // legacy pre-0.1.0 unprefixed key
    await _preferences?.remove(_prefixedKey(key));
    await _preferences?.remove(key); // legacy pre-0.1.0 unprefixed key
  }

  /// Get a value from cache, or a default value if the key does not exist
  /// TIP: Don't forget to AWAIT!
  Future<T> getValueOrDefault<T>(
      {required String key, required T defaultIfNull}) async {
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

    try {
      value = _inMemoryCache[key] as T?;
      if (value != null) {
        // return a deep copy so mutations of the returned value don't change the cache
        value = _deepCopy(value) as T?;
      }
    } catch (e) {
      _consolePrint('WARN: EasyCache error getting "$key": "$e"');
      _consolePrint('WARN: EasyCache will return null for "$key"');
      // fall through to always return null value
    }

    if (value != null) {
      _consolePrint('EasyCache Hit (in-memory) for "$key"');
    }

    return value;
  }

  Future<T?> _getPreferencesValue<T>({required String key}) async {
    await _initIfNeeded();

    T? value;

    try {
      value = _readPreferencesValue<T>(_prefixedKey(key));

      if (value == null) {
        // values written before 0.1.0 used unprefixed keys; migrate on first read
        final legacyValue = _readPreferencesValue<T>(key);
        if (legacyValue != null) {
          await _writePreferencesValue<T>(
              key: _prefixedKey(key), value: legacyValue);
          await _preferences?.remove(key);
          _consolePrint(
              'EasyCache migrated "$key" to namespaced preferences key');
        }
        value = legacyValue;
      }
    } catch (e) {
      _consolePrint('WARN: EasyCache error getting "$key": "$e"');
      _consolePrint('WARN: EasyCache will return null for "$key"');
      // fall through to always return null value
    }

    if (value != null) {
      _consolePrint('EasyCache Hit (preferences) for "$key"');
    }

    return value;
  }

  T? _readPreferencesValue<T>(String key) {
    T? value;

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
      final stringList = _preferences?.getStringList(key);
      if (stringList != null) {
        value = stringList
            .map((e) => jsonDecode(e) as Map<String, dynamic>)
            .toList() as T?;
      }
    }

    return value;
  }

  Future<T?> _getSecureValue<T>({required String key}) async {
    await _initIfNeeded();
    T? value;

    try {
      final envelopeJson = await _secureStorage?.read(key: _prefixedKey(key));
      if (envelopeJson != null) {
        value = _decodeSecureEnvelope<T>(envelopeJson);
      } else {
        // values written before 0.1.0 used unprefixed keys and untyped strings;
        // parse leniently (matching the old behavior) and migrate on first read
        final legacyString = await _secureStorage?.read(key: key);
        if (legacyString != null) {
          final legacyValue = _parseLegacySecureValue<T>(legacyString);
          if (legacyValue != null) {
            await _addOrUpdateSecureStorage<T>(key: key, value: legacyValue);
            await _secureStorage?.delete(key: key);
            _consolePrint(
                'EasyCache migrated "$key" to typed secure storage format');
          }
          value = legacyValue;
        }
      }
    } catch (e) {
      _consolePrint('WARN: EasyCache error getting "$key": "$e"');
      _consolePrint('WARN: EasyCache will return null for "$key"');
      // fall through to always return null value
    }

    if (value != null) {
      _consolePrint('EasyCache Hit (secure storage) for "$key"');
    }

    return value;
  }

  T? _decodeSecureEnvelope<T>(String envelopeJson) {
    final decoded = jsonDecode(envelopeJson);
    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey(_envelopeTypeKey)) {
      return null;
    }

    if (decoded[_envelopeTypeKey] != _typeTag<T>()) {
      // stored under a different type; honor the type-safety contract
      return null;
    }

    final raw = decoded[_envelopeValueKey];
    if (raw == null) return null;

    // collections are materialized eagerly so element type mismatches throw
    // here (inside the caller's try/catch) instead of later in user code
    if (T == List<String>) {
      return List<String>.from(raw as List) as T;
    }
    if (T == List<Map<String, dynamic>>) {
      return (raw as List).map((e) => e as Map<String, dynamic>).toList() as T;
    }
    if (T == double) {
      return (raw as num).toDouble() as T;
    }
    return raw as T?;
  }

  T? _parseLegacySecureValue<T>(String stringValue) {
    if (T == String) {
      return stringValue as T;
    }
    if (T == bool) {
      return bool.tryParse(stringValue, caseSensitive: false) as T?;
    }
    if (T == int) {
      return int.tryParse(stringValue) as T?;
    }
    if (T == double) {
      return double.tryParse(stringValue) as T?;
    }
    if (T == Map<String, dynamic>) {
      return jsonDecode(stringValue) as T?;
    }
    if (T == List<String>) {
      return List<String>.from(jsonDecode(stringValue) as List) as T;
    }
    if (T == List<Map<String, dynamic>>) {
      return (jsonDecode(stringValue) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList() as T;
    }
    return null;
  }

  /// Clear everything this cache has stored.
  /// Only keys owned by FlutterEasyCache are deleted; other values your app
  /// keeps in shared preferences or the keychain/keystore are left alone.
  /// NOTE: values written by versions before 0.1.0 that have not been read
  /// (and therefore not yet migrated) are not covered by purge.
  /// TIP: Don't forget to AWAIT!
  Future<void> purge(
      {bool includeAppSession = true,
      bool includeAppInstall = true,
      bool includeSecureStorage = true}) async {
    await _initIfNeeded();
    if (includeAppSession) await _purgeAppSession();
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
    final keys = _preferences?.keys
            .where((key) => key.startsWith(_keyPrefix))
            .toList(growable: false) ??
        const [];
    for (final key in keys) {
      await _preferences!.remove(key);
    }
    _consolePrint('EasyCache app install cache was purged');
  }

  /// Clear everything from cache with the Secure policy
  Future<void> _purgeSecureStorage() async {
    final entries = await _secureStorage?.readAll() ?? const <String, String>{};
    // materialize the key list; readAll() may return a live view of the store
    final keys = entries.keys
        .where((key) => key.startsWith(_keyPrefix))
        .toList(growable: false);
    for (final key in keys) {
      await _secureStorage?.delete(key: key);
    }
    _consolePrint('EasyCache secure storage cache was purged');
  }

  // PRIVATE METHODS

  String _prefixedKey(String key) => '$_keyPrefix$key';

  String _typeTag<T>() {
    if (T == String) return 'String';
    if (T == int) return 'int';
    if (T == double) return 'double';
    if (T == bool) return 'bool';
    if (T == Map<String, dynamic>) return 'Map<String, dynamic>';
    if (T == List<String>) return 'List<String>';
    if (T == List<Map<String, dynamic>>) return 'List<Map<String, dynamic>>';
    throw ArgumentError('EasyCache - Unsupported type $T');
  }

  /// Deep copies supported collection types so the cache never shares mutable
  /// state with callers. Primitives (and unrecognized leaves) are returned as-is.
  dynamic _deepCopy(dynamic value) {
    if (value is List<Map<String, dynamic>>) {
      return value.map((e) => _deepCopy(e) as Map<String, dynamic>).toList();
    }
    if (value is List<String>) {
      return List<String>.from(value);
    }
    if (value is Map<String, dynamic>) {
      return value.map((key, e) => MapEntry(key, _deepCopy(e)));
    }
    if (value is Map) {
      return value.map((key, e) => MapEntry(key, _deepCopy(e)));
    }
    if (value is List) {
      return value.map(_deepCopy).toList();
    }
    return value;
  }

  /// lazily init dependencies because we can't use async in the constructor
  Future<void> _initIfNeeded() async {
    // web has no persistent shared preferences; back it with an in-memory store
    // (only before first init, so repeated calls don't replace the store)
    if (kIsWeb && _preferences == null) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    }

    // init shared preferences
    _preferences ??= await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions());

    // init secure storage
    if (_secureStorage == null) {
      const aOptions = AndroidOptions(
        // Values written by flutter_secure_storage 9.x (EncryptedSharedPreferences)
        // are migrated to the v10 cipher scheme on first access via the
        // migrateOnAlgorithmChange default. resetOnError defaults to true in
        // v10, which wipes the whole store on a decrypt failure; keep it false
        // so errors surface as failed reads (this cache returns null) instead
        // of destroying data whose purpose is to survive app reinstalls.
        resetOnError: false,
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

    // 4 - if a value was provided, make sure it actually is a T
    if (value != null && value is! T) {
      throw ArgumentError(
          'EasyCache - Type mismatch. ${value.runtimeType} is not a $T');
    }
  }

  /// Initializes the shared preferences + Flutter secure storage packages with empty mock values for testing.
  /// Once initialized, you can inject any values you want to test with through the normal cache methods.
  ///
  /// If the singleton instance has been initialized already, it is nullified.
  @visibleForTesting
  static void setMockInitialValues() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});

    // ignore: invalid_use_of_visible_for_testing_member
    FlutterSecureStorage.setMockInitialValues({});
  }

  // Resets the underyling shared preferences to original state for testing
  @visibleForTesting
  static Future<void> resetStatic() async {
    await shared.purge();

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.resetStatic();

    shared._preferences = null;
    shared._secureStorage = null;
  }

  void _consolePrint(String msg) {
    if (_loggingEnabled) debugPrint(msg);
  }
}
