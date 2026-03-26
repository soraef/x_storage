## 0.4.1

* Fixed `XUri.changeScheme` producing double leading slashes (e.g. `////path`) by using `Uri.replace` instead of string concatenation

## 0.4.0

* Added `CachingProviderMixin` for cache management interface
* Added `SyncProviderMixin` for sync status management interface
* Added `SyncStatus` enum (`synced`, `pendingUpload`, `localOnly`, `pendingDelete`)
* `XStorage.withResource()` now auto-detects cached files via `CachingProviderMixin`
* Fixed `AssetProviderMixin.assetName` to strip leading slash

## 0.2.1

* Added export `XStorageException`

## 0.2.0

* **BREAKING CHANGE**: Migrated error handling to use `Result` type from `type_result` package
* **BREAKING CHANGE**: Renamed `XStorageError` to `XStorageException`
* All storage operations now return `Result<T, XStorageException>`
* Improved type safety in error handling
* Added dependency on `type_result: ^3.0.1`

## 0.1.0

* **BREAKING CHANGE**: Renamed `XStorageDriver` to `XStorageProvider` for better semantic clarity
* Renamed all related classes, methods, and documentation to use "Provider" instead of "Driver"
* Updated all mixins to work with `XStorageProvider`
* Improved documentation

## 0.0.4

* Fix bugs

## 0.0.3

* Fix bugs

## 0.0.2

* Add getProviderFromScheme method to XStorage
* Add changeSchema method to XUri

## 0.0.1

* Initial release
* Implementation of basic storage interface
* Various Mixins (Network, File, Asset)
* URI-based file management functionality

