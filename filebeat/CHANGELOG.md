# Changelog

## [0.3.12] - 13-08-2022
### CHANGED
- Changed ingest pipeline to adjust for date change in https://github.com/home-assistant/core/pull/74518

## [0.3.11] - 02-07-2022
### CHANGED
- Changed docker registry to self-hosted
- Changed URL in config.yaml to point to repo root
- Moving out of 'experimental'

### FIXED
- Search for Home Assistant Core Logs updated so it doesn't cause endless loop

## [0.3.8] - 02-07-2022
- Initial release
- Option to select filebeat version to be used
- Filebeat binaries included in build rather than being downloaded every run, this will help with faster addon start
- CI pipeline adjusted to help with binary download
- Journal input contains grok ingest pipeline patterns for apparmor, removal of ANSI codes, addon tagging
- Main input ingest pipeline contains few patterns for tagging of deprecated features when mentioned in log file
- Supports armv7, amd64, arm64
