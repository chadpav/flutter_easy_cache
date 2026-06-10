# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`flutter_easy_cache` is a Flutter package that provides a simple, unified caching layer with three storage policies:
- **appSession**: In-memory cache (cleared on app restart)
- **appInstall**: Disk-based cache using `shared_preferences` (persists across sessions but cleared on uninstall)
- **secure**: Keychain/Keystore storage using `flutter_secure_storage` (persists across app installations)

The entire implementation is in a single file: `lib/flutter_easy_cache.dart`

## Key Commands

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/flutter_easy_cache_app_session_test.dart
flutter test test/flutter_easy_cache_app_install_test.dart
flutter test test/flutter_easy_cache_secure_test.dart

# Run tests with coverage
flutter test --coverage
```

### Linting
```bash
# Analyze code
flutter analyze

# Format code
dart format .
```

### Building
```bash
# Check package health
flutter pub publish --dry-run
```

## Architecture

### Single File Design
All logic lives in `lib/flutter_easy_cache.dart` (~375 lines). The class uses:
- **Singleton pattern**: `FlutterEasyCache.shared` for consistent access
- **Lazy initialization**: Dependencies (`SharedPreferencesWithCache`, `FlutterSecureStorage`) are initialized on first use via `_initIfNeeded()`
- **Three-layer cache lookup**: `getValueOrNull<T>()` checks in-memory → shared preferences → secure storage in order

### Supported Data Types
The cache enforces type safety and only supports:
- Primitives: `String`, `int`, `double`, `bool`
- Collections: `List<String>`, `Map<String, dynamic>`, `List<Map<String, dynamic>>`

Type checking happens in `_assertTypeSupport<T>()` which throws `ArgumentError` for unsupported types.

### Storage Implementation Details
- All shared preferences and secure storage keys carry the `easyCache.` prefix (`_keyPrefix`), so `purge()` deletes only cache-owned keys
- **appSession**: Stored in the `_inMemoryCache` map; values are deep-copied on write and read so the cache never shares mutable state with callers
- **appInstall**: Uses `SharedPreferencesWithCache` API, JSON encoding for complex types
- **secure**: Uses `FlutterSecureStorage` API; every value is a JSON envelope (`__easy_cache_type__` + `__easy_cache_value__`) so reads can enforce type safety

### Legacy Data Migration (pre-0.1.0)
Versions before 0.1.0 stored values under unprefixed keys, and secure values as untyped strings. Read paths fall back to the legacy key, parse leniently (old behavior), and migrate to the new format on first successful read. `remove()` deletes both prefixed and legacy keys. `purge()` does not cover unmigrated legacy values.

### Web Support
For web platform, `_initIfNeeded()` sets `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()` once, before first initialization.

## Testing Patterns

All tests follow this setup/teardown pattern:

```dart
setUp(() {
  FlutterEasyCache.setMockInitialValues();
  cache = FlutterEasyCache.shared;
});

tearDown(() async {
  await FlutterEasyCache.resetStatic();
});
```

**Important**: Always use `setMockInitialValues()` before accessing the singleton in tests, and `resetStatic()` in teardown to prevent test pollution.

## Development Notes

- The package intentionally fails silently on read errors (returns `null` instead of throwing)
- Debug logging can be enabled via `cache.enableLogging = true` (only prints in debug builds)
- `addOrUpdate()` always calls `remove()` first to clear keys across all storage layers
- The secure storage on iOS uses `synchronizable: true`, meaning values sync across devices via iCloud
- Web platform uses in-memory storage for `SharedPreferences` as persistent storage isn't available
