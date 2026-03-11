# Changelog

## [1.0.1] - 2026-03-04

### Changed
- Renamed executables to `ufwcheck` and `geoupdate`, config files to `config` and `env`
- Added short aliases `ufc` and `gup` for `ufwcheck` and `geoupdate`

### Added
- Reinstall detection in `install.sh` prompts for confirmation if an existing installation is found
- Null bytes detection in UFW log with a safe cleanup procedure documented in `docs/troubleshooting.md`
- `docs/log-retention.md`: logrotate configuration guide and performance reference

### Removed
- SHA256SUMS integrity verification of downloaded scripts

### Fixed
- Several reliability fixes in `geoupdate`: atomic database replacement, correct error propagation, and safer temporary file handling

### Documentation
- Restructured and corrected `docs/troubleshooting.md`, `docs/installation.md`, `docs/uninstall.md`
- Added `CHANGELOG.md`

---

## [1.0.0] - 2025-12-25

### Added
- Initial public release of the `ufwcheck` suite
- `ufwcheck`: log analysis with flexible filtering, IP geolocation via MaxMind GeoLite2-City, table and JSON output
- `geoupdate`: automated downloader and verifier for the GeoLite2-City database with SHA256 checksum and Tar Slip protection
- `install.sh`: guided installer with dependency checking, XDG-compliant directory structure, and optional cron configuration
