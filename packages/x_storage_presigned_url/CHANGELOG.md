## 0.4.2

* Reuse a single `http.Client` across `head()` / `exists()` / `loadFile()` / `saveFile()` to keep the TCP/TLS connection alive (large latency reduction for repeated metadata requests such as computing download sizes)

## 0.4.1

* Implemented `head()` using an HTTP HEAD request (reads `Content-Length` and `Content-Type`)
* Upload now uses a streamed PUT request (`http.StreamedRequest`) with explicit content length, and omits `Content-Type` when no upload headers are provided
* Expanded automatic MIME type detection to cover audio formats (mp3, m4a, aac, wav, ogg, flac) and fall back to `application/octet-stream`

## 0.4.0

* Added `contentType` and `sizeBytes` parameters to `fetchUploadPresignedUrl`
* Added `uploadHeaders` hook for custom PUT request headers
* Added `onSaveComplete` hook for post-upload actions
* Added automatic MIME type detection from file extension

## 0.2.0

* **BREAKING CHANGE**: Updated to support x_storage_core 0.2.0
* Migrated to Result type for error handling
* All operations now return Result<T, XStorageException>

## 0.1.0

* Initial release
* Implementation of presigned URL storage provider
* Support for S3-compatible storage services

## 0.0.4

* Fix bugs

## 0.0.3

* Fix bugs

## 0.0.2

* Fix bugs

## 0.0.1

* Initial release
* Implementation of XStorage driver for Presigned URL storage
* Support for AWS S3 and other S3-compatible storage services
* File save, load, and existence check functionality
* Custom API client support
