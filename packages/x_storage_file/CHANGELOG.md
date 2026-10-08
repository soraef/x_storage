## 0.5.0

* **Breaking (behaviour):** `SyncStorageProvider.saveFile` is local-first. It completes once the local file and the durable sync intent are written and no longer waits for the upload; uploads run in a separate, serialized pass. Call `syncPending()` on startup/resume and connectivity recovery.
* Overwriting a file while its previous upload is in flight never marks the newer bytes as synced.
* Added `SyncStorageProvider.clearRemote()`; `verifyStatus` keeps the stored status when `remote.exists` throws (e.g. offline).
* `JsonSyncMetadataStore` serializes updates and replaces its JSON file atomically; `FileStorageProvider` writes through a flushed temporary file and rename.
* Requires `x_storage_core` ^0.5.0.

## 0.4.1

* Implemented `head()` using `File.stat()` (size and last modified) without reading the file
* Added debug logging to `SyncStorageProvider.saveFile` for remote upload results

## 0.4.0

* Added `SyncStorageProvider` for local-first storage with remote sync
* Added `SyncMetadataStore` and `JsonSyncMetadataStore` for sync metadata persistence
* Added `CachingStorageProvider` for automatic local caching of network files with offline support
* Fixed `SyncStorageProvider.setRemote` return type from `void` to `Future<void>`

## 0.2.3

* Fixed: `saveFile()` and `downloadFile()` now automatically create parent directories if they don't exist

## 0.2.0

* **BREAKING CHANGE**: Updated to support x_storage_core 0.2.0
* Migrated to Result type for error handling
* All operations now return Result<T, XStorageException>

## 0.1.0

* **BREAKING CHANGE**: Renamed `FileXStorageDriver` to `FileStorageProvider` for better semantic clarity
* Updated to use x_storage_core 0.1.0
* Improved documentation

## 0.0.4

* Fix bugs

## 0.0.3

* Fix bugs

## 0.0.2

* Fix bugs

## 0.0.1

* Initial release

