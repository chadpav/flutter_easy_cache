A don't overthink it, easy-to-use caching layer for Flutter. Supports in-memory, disk, and secure storage caching.

Works with iOS, Android.

## Features

- Easy-to-use, clean API
- In-memory cache scoped to the current app session
- Disk cache scoped to the current app installation (using `shared_preferences` package)
- Secure storage cache scoped to live across app installations (using `flutter_secure_storage` package)
- Supports caching of these data types: 
    - Primitives `String`,`int`, `double`, `bool`,
    - Plus `List<String>`, `Map<String, dynamic>`, `List<Map<String, dynamic>>`
    - NOTE: I write `toDictionary` and `fromDictionary` methods for all my models, so I can easily convert them to and from `Map<String, dynamic>` objects. This is a good practice to follow, and it makes it easy to cache your models.

## Getting started

1. Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_easy_cache: ^0.1.0
```

## Usage

```dart
import 'package:flutter_easy_cache/flutter_easy_cache.dart';

Future<void> main() async {
    // Singleton instance of the cache
    final cache = FlutterEasyCache.shared;

    final value = 'a string value';
    final dictValue = {'name': 'Chad'};

    // Add or update a value in the cache
    // Optionally provide a generic type to ensure type safety
    await cache.addOrUpdate<String>(key: 'aKey', value: value);
    await cache.addOrUpdate<Map<String, dynamic>>(key: 'aDictKey', value: dictValue);
    
    // Read from the cache
    final cachedValue = await cache.getValueOrNull<String>(key: 'aKey'); 
    final cachedDictValue = await cache.getValueOrNull<Map<String, dynamic>>(key: 'aDictKey');

    // or Get a value from the cache, or a default value if it doesn't exist
    final cachedValueOrDefault = await cache.getValueOrDefault<String>(key: 'aNewKey', defaultIfNull: 'default value');
    
    print(cachedValue); // 'a string value'
    print(cachedDictValue); // {'name': 'Chad'}

    // Remove a value from the cache
    await cache.remove(key: 'aKey');
    
    // Or all values from the cache (only keys this cache owns; the rest of your
    // app's shared preferences and keychain entries are left alone)
    await cache.purge();

    // Example of caching a model named Credentials into secure storage that has toDictionary() and fromDictionary() methods
    final creds = Credentials(email: 'email', password: 'password');
    // this will store the value encrypted and protected by the device's security (biometrics, etc.)
    await cache.addOrUpdate<Map<String, dynamic>>(
      key: 'CredentialsKey',
      value: creds.toDictionary(),
      policy: CachePolicy.secure,
    );
}
```

In unit tests, you can pass mock values into the cache to test your code without having to mock the library out.
  
  ```dart
  ...
  late FlutterEasyCache cache;

  setUp(() {
    // Set up the cache with mock values first
    FlutterEasyCache.setMockInitialValues();
    // then get the Singleton instance
    cache = FlutterEasyCache.shared;
  });

  tearDown(() async {
    await FlutterEasyCache.resetStatic();
  });
  ...
  ```

## Upgrading to 0.1.0

Version 0.1.0 changed the storage format: keys carry an `easyCache.` prefix, and secure storage values carry a type tag so reads can enforce type safety. Values written by earlier versions migrate automatically the first time they are read — no action needed. Two things to know:

- A legacy value keeps the old lenient typing until its first read, which locks in the type it was read as.
- `purge()` now deletes only keys this cache owns. Legacy values that were never read (and so never migrated) are not covered; `remove(key:)` clears them.

## What's coming

1. Adding support for TTL (time-to-live) on cached values. For example, you could make something work across app sessions but expire after 1 week.
2. Catch all exceptions and return NULL instead of throwing errors. For a simple caching layer, it's better to fail silently and pretend that a value wasn't cached than to throw errors and have to wrap everything in Try/Catches.

## Additional information

I've been dragging this package around for a while, and I've been using it in my projects. I decided to publish it to help others who need a simple caching layer for their Flutter apps.

My goal was to create a simple API that would allow me to cache data in memory, on disk, or encrypted in secure storage that ensures the same API and behavior across all storage types. It wraps the `shared_preferences` and `flutter_secure_storage` packages to provide a simple and consistent API. This is meant as a consolidation of the two packages, and unifying their API, not a replacement. I've intentionally left out some of the more advanced features of these packages to keep the API simple and consistent.

I make no guarantees about the performance of this package. In fact, don't use this if you have large datasets. You should be looking into a proper data store like SQLite or Hive or ISAR. But then... those are more complicated storage API's.
