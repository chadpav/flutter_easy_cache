## 0.2.0

Dependency upgrade: `flutter_secure_storage` 9.x → 10.x. Secure values written by earlier versions stay readable — see migration notes below.

* **CHANGED**: Upgraded `flutter_secure_storage` to ^10.3.1. On Android, the plugin replaces Google's deprecated EncryptedSharedPreferences with its own AES-GCM cipher and migrates existing values automatically on first access. iOS keychain items are untouched; the same accessibility and iCloud-sync options apply.
* **CHANGED**: Secure storage no longer wipes itself when a value fails to decrypt (`resetOnError: false`). A failed read now returns `null`, matching this package's fail-silent contract, instead of erasing data meant to survive reinstalls.
* **CHANGED**: Minimum requirements are now Dart 3.9 / Flutter 3.35, Android API 23 (Android 6.0), iOS 12, and macOS 10.14. Android builds require Java 17 and compileSdk 36.
* **ADDED**: iOS and macOS now install via Swift Package Manager (through `flutter_secure_storage_darwin`); CocoaPods continues to work.
* **CHANGED**: Upgraded `shared_preferences` to ^2.5.5 and `shared_preferences_platform_interface` to ^2.4.2 (no API changes).

Do not skip from 9.x straight to a future `flutter_secure_storage` 11.x: version 11 removes the legacy ciphers, so Android data must pass through 10.x to be migrated.

## 0.1.0

Storage format change: cache keys now carry an `easyCache.` prefix, and secure storage values carry a type tag. Values written by earlier versions stay readable and migrate to the new format on first read — no action needed.

* **FIXED**: Secure storage now enforces type safety. Reading a key under a different type than it was written returns `null`. Previously an `int` read as `double` returned the converted number, and a `bool` read as `String` returned `"true"`.
* **FIXED**: Reading a secure `List<String>` or `List<Map<String, dynamic>>` under the wrong element type returns `null`. Previously it returned a lazily-cast list that threw `TypeError` in caller code on first element access.
* **FIXED**: `appSession` values are deep-copied on write and read. Mutating a value after caching it, or mutating a retrieved value, no longer changes the cache.
* **FIXED**: `purge()` deletes only keys owned by this cache. Previously it cleared all of the app's shared preferences and every keychain/keystore entry, including values written by other code. Legacy values that were never read (and therefore never migrated) are not covered by `purge()`; `remove(key:)` clears both legacy and new keys.
* **FIXED**: `resetStatic()` now awaits its internal `purge()`, removing a race in test teardown.
* Fixed the web platform replacing its in-memory preferences store on every cache call.
* Fixed the `repository` URL in pubspec.

## 0.0.6

* **CRITICAL BUG FIX**: Added missing `await` keywords in `addOrUpdate()` switch statement - ensures async operations complete before returning
* **CRITICAL BUG FIX**: Changed `int.parse()` to `int.tryParse()` in secure storage to prevent exceptions on missing keys
* **CRITICAL BUG FIX**: Fixed null pointer exception when reading non-existent `List<Map<String, dynamic>>` from preferences
* Fixed typo: renamed `enalbeLogging` parameter to `enableLogging` in factory method

## 0.0.5

* Added support for web platform using shared preferences
* Updated dependencies to latest versions
* Fixed package dependencies for pub.dev publishing

## 0.0.1

* Initial development release
