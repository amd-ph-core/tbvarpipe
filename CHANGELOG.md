# amd-ph-core/tbvarpipe: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.2.1 - [2026-05-18]

### `Changed`

- Updated `amd-ph-core` module and subworkflow SHAs to latest pinned commits
- Updated `DISCLAIMER.md` language
- Updated CI `static_assets` path for test pipeline workflow

### `Fixed`

- Updated nf-test snapshots for `picard/sortsam` and default pipeline test

## v1.2.0 - [2026-03-23]

### `Changed`

- Migrated custom modules from `ph-core` to `amd-ph-core` namespace
- Re-imported nf-core modules at pinned SHA (`d090922b`)
- Pipeline container images sourced from `quay.io/us-cdcgov/cdc-amd/*`
- Container overrides loaded from `amd-ph-core/configs`
- Reference files resolved via `static_assets` parameter with lazy GString closures
- Clockwork decontamination enabled by default (matching tb-main-surveillance)
- Updated nf-core template to 3.3.2

### `Added`

- `static_assets` parameter for configurable reference file root (local path or S3)
- `clockwork` parameter toggle for decontamination preprocessing
- snpEff cache delivered via UNTAR module (no large binaries in repo)
- nf-test configuration with nf-core template defaults

### `Fixed`

- snpEff config path resolution for both UNTAR and direct path flows

## v1.2.0 - Initial Public Release

First public release of amd-ph-core/tbvarpipe on GitHub. Based on the internal CDC pipeline
with full module reorganization and public repository references.
