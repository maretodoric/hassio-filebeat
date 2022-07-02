# Home Assistant Add-on: Filebeat

![Supports armv7 Architecture][armv7-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports aarch64 Architecture][aarch64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports i386 Architecture][i386-shield]

[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[aarch64-shield]: https://raster.shields.io/badge/aarch64-yes-green.png
[armhf-shield]: https://img.shields.io/badge/armhf-no-red.svg
[i386-shield]: https://img.shields.io/badge/i386-no-red.svg

> Whether you’re collecting from security devices, cloud, containers, hosts, or OT, Filebeat helps you keep the simple things simple by offering a lightweight way to forward and centralize logs and files.
~https://www.elastic.co/beats/filebeat

## About

This addon is esentially filebeat exporter configured to ship home-assistant.log and/or journal to your configured elasticsearch host.
Possibility of using custom pipeline is also available, refer to addon Documentation for more info.
Addon will keep filebeat running in background while periodically checking for HA Version, if version is changed, filebeat will be restarted so that it can log new HA version to elasticsearch without waiting for user intervention.

### Please note!

I will not provide documentation or support for Elasticsearch cluster installation and/or configuration.

Addon has access to home assistant API and API is used to gather available domains so that it can update ingest pipeline for better log ingestion.
It's recommended to restart this addon in case you introduce new entity domain so that it can refresh.
Addon also collects:
- Home Assistant Version (from supervisor API)
- Home Assistant UUID
That information is used in order to be ingested with data, in case you have multiple HA instances so that you may differenciate data between instances (by UUID and/or version).

Addon currently only support self-hosted elasticsearch instance, cloud-based support will be added if popular demand is present.

Please read elasticsearch/beats documentation for filebeat-elasticsearch compatability.

### Fields

Folowing fields are added if you're not using your own custom pipeline while parsing home-assistant.log file:
- hass.message - Contains plain message from log file, without timestamp, log level and component for better readability
- hass.component - Contains component enclosed in square brackets in home-assistant log (for example - hhomeassistant.components.sensor)
- hass.components - Same as above but split between dots for better search of specific component when needed.
- hass.integration - Integration name when detected
- hass.entity.name - Full name of entity
- hass.entity.name - Entity domain related to previous entity.name

Following items will be appended to `tags` field, this is an array field:
- deprecation - Will add this tag if word `deprecated` appears in log
- slow - Will add this tage when phrases `timeout`, `took longer`, `is taking over` appears in logs, indicating something is slow
- python class - This will not actually be inside `tags` but will contain a name of python class. This is usually when handled exception occurs and will allow for better tracing of errors

### Disclaimer!

I'm not creator of Filebeat. All rights to Filebeat including Filebeat and Beats logo are owned by Elasticsearch B.V.
