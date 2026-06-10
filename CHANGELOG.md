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
