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
