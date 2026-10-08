# XStorageFile

`FileStorageProvider` stores files in application support storage.
`SyncStorageProvider` adds optional remote synchronization while keeping the
same logical `XUri` for local and remote access.

## Local-first save contract

`await provider.saveFile(uri, bytes)` completes after the local file and durable
sync intent have been written. It does **not** wait for an upload. A successful
save is enough to persist that URI in an entity and display the local image.
Local or metadata write errors are returned as failures.

With no remote, saves are `localOnly`. With a remote, saves are `pendingUpload`
and a separate sync pass is scheduled. A failed/interrupted transfer remains
pending. Call `syncPending()` on application startup/resume and connectivity
recovery; the provider does not run while the application's process is stopped.

- `syncPending()` retries queued uploads and deletions.
- `syncAll()` also uploads `localOnly` files.
- `uploadToRemote(uri)` explicitly uploads one file.
- `setRemote()` / `clearRemote()` configure optional synchronization.
- `loadFile()` prefers local data and caches remote data on a local miss.

Network operations are serialized separately from local writes. Editing a file
while its old upload is in flight does not block the edit or mark the newer
bytes as synced. Use immutable revision URIs when publishing replacements
across multiple devices.

`JsonSyncMetadataStore` serializes updates and atomically replaces its JSON
file. `FileStorageProvider` writes through a flushed temporary file and rename.
Keep one provider/metadata-store owner for a given store within the app; this
is not a cross-process locking protocol.
