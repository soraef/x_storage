# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

XStorage is a Dart/Flutter monorepo providing a unified storage abstraction layer. It uses URI-based file references (`XUri`) with scheme-based routing to abstract over multiple storage backends (local files, Firebase Storage, S3-compatible presigned URLs, Flutter assets).

## Commands

```bash
# Dependencies (uses FVM for Flutter version management)
melos bs                          # Bootstrap all packages
melos run pub_get                 # flutter pub get across all packages

# Analysis
melos run analyze                 # dart analyze with --fatal-infos across all packages
dart analyze lib/                 # Analyze a single package (run from package dir)

# Tests
cd packages/<package> && flutter test          # Run all tests in a package
cd packages/<package> && flutter test test/specific_test.dart  # Single test

# Auto-fix
melos run fix_apply               # dart fix --apply across all packages
```

## Architecture

### Package Dependency Graph

```
x_storage_flutter ──→ x_storage_core
x_storage_file ─────→ x_storage_core
x_storage_firebase ─→ x_storage_core
x_storage_presigned_url → x_storage_core
```

### Core Abstractions (x_storage_core)

- **`XUri`** — Extension type wrapping `Uri`. Format: `scheme:///path/to/file`. Use `XUri.create(scheme, path)` and `uri.changeScheme(newScheme)`.
- **`XStorageProvider`** — Abstract base class all providers implement. Key methods: `saveFile`, `loadFile`, `deleteFile`, `exists`. Each provider declares a `scheme` string.
- **`XStorage`** — Orchestrator that routes operations to registered providers by URI scheme.
- **Provider Mixins** — `NetworkProviderMixin` (provides `getNetworkUrl`), `FileProviderMixin` (provides `getFilePath`), `AssetProviderMixin` (provides `assetName`). These determine behavior in `withResource()` and Flutter widgets.
- **`CachingProviderMixin`** — Interface for cache management (`isCached`, `getCachedFilePath`, `removeCache`, `removeCacheByPrefix`, `clearCache`).

### Caching (x_storage_file)

`CachingStorageProvider` wraps a `NetworkProviderMixin` provider with `FileStorageProvider` as cache backend. It keeps the delegate's scheme so it's a drop-in replacement. `withResource()` and `XStorageImage` automatically use local file paths when cached.

### Error Handling

All storage operations return `Result<T, XStorageException>` from the `type_result` package. Exception types: `FileNotFoundException`, `ProviderNotFoundException`, `UnsupportedOperationException`, `UnknownException`.

### Flutter Widgets (x_storage_flutter)

`XStorageImage` and `XStorageAudioService` use `getStorageType()` / provider mixin checks to determine rendering strategy (asset/network/file). They auto-detect `CachingProviderMixin` to prefer local file paths when cached.

## Conventions

- Packages use `flutter_lints` for analysis
- Local development: switch `x_storage_core` dependency from pub version to `path: ../x_storage_core` in package pubspec.yaml, then revert before publishing
- Presigned URL provider is abstract — must be extended for specific services (e.g., Wasabi S3)
