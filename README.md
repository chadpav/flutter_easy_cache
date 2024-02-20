A don't overthink it, easy-to-use caching layer for Flutter. Supports in-memory, disk, and secure storage caching.

Works with iOS, Android.

## Features

- Simple API
- In-memory cache scoped to the current app session
- Disk cache scoped to the current app installation (using `shared_preferences` package)
- Secure storage cache scoped to the live across app installations (using `flutter_secure_storage` package)

## Getting started

1. Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_easy_cache: ^0.0.1
```

2. Use it in your code

```dart
import 'package:flutter_easy_cache/flutter_easy_cache.dart';

void main() {
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
    
    print(cachedValue); // 'a string value'
    print(cachedDictValue); // {'name': 'Chad'}
}
```

## Usage

TODO: Include short and useful examples for package users. 

## Additional information

I've been dragging this package around for a while, and I've been using it in my projects. I decided to publish it to help others who need a simple caching layer for their Flutter apps.

My goal was to create a simple API that would allow me to cache data in memory, on disk, or encrypted in secure storage that ensures the same API and behavior across all storage types. It wraps the `shared_preferences` and `flutter_secure_storage` packages to provide a simple and consistent API. This is meant as a consolidation of the two packages, and unifying their API, not a replacement. I've intentionally left out some of the more advanced features of these packages to keep the API simple and consistent.

I make not guarantees about the performance of this package. If you are dealing with large amounts of data you should be looking into a proper data store like SQLite or Hive or ISAR.
