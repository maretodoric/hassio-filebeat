# Home Assistant Add-on: Filebeat

This addon is esentially filebeat exporter configured to ship home-assistant.log and/or journal to your configured elasticsearch host.
Possibility of using custom pipeline is also available, refer to addon Documentation for more info.
Addon will keep filebeat running in background while periodically checking for HA Version, if version is changed, filebeat will be restarted so that it can log new HA version to elasticsearch without waiting for user intervention.

## Prerequisites

This addon requires you to have your Time Zone settings configured in Home Assistant, check [here](https://www.home-assistant.io/docs/configuration/basic) for more information.

## Installation

1. Click the button bellow to open this addon in your Home Assistant instance. 

[![Open this add-on in your Home Assistant instance.][addon-badge]][addon]

2. If you already have repo added, it will lead you directly to the Addon page in that case, **skip to next step**, otherwise it will ask you to add the repo first, in that case click on "Add"
3. Click on Install
4. Go to Configuration tab and make the nececarry changes. Click Save at the bottom once done.
5. Go to the Info tab and start Addon
6. Go to Logs tab and check for any errors, report if any.


## Configuration

Below is an example yaml configuration, do not copy the changes, you will need to make changes of your own.

```
es_url: https://es.example.org:9200
es_username: elastic
es_password: securedPassword
es_ssl_verification_mode: full
es_index: hassindex
es_number_of_shards: 1
es_number_of_replicas: 0
es_pipeline_path: ''
enable_journal: true
filebeat_version: 8.2.3
fb_log_level: warning
clear_cache: false
debug_mode: false
```

Bellow is a description for each option.

### Option: `es_url` (required)

URL of Elasticsearch host. For example: `https://es.example.com:9200`

### Option: `es_username` (required)

Username used to ingest data, usually "elastic".

### Option `es_password` (required)

Password for above user

### Option `es_ssl_verification_mode` (required)

Configuration of output.elasticsearch.ssl.verification_mode setting in filebeat.yml.
See [here](https://www.elastic.co/guide/en/beats/filebeat/current/configuration-ssl.html#client-verification-mode) for more information regarding this option.

### Option `es_index` (required)

Index name where to ingest data, can be a template, refer to documentation here: [here](https://www.elastic.co/guide/en/beats/filebeat/current/elasticsearch-output.html#index-option-es)

### Options `es_number_of_shards` and `es_number_of_replicas` (required)

Confgure `index.number_of_replicas` and `index.number_of_shards` for your index template. You can tweak to your liking and need.

### Option `es_pipeline_path` (optional)

Optional path to your custom made ingest pipeline. File can be placed anywhere inside /config and full path needs to be specified here to be loaded.
Additionally, you can use URL here and addon will attempt to download pipeline from that URL and ingest it.
Addon will revert to default pipeline or fail if pipeline is incorrect.

### Option `kibana_url` (optional)

Optional URL to your Kibana Instance. When added, it will load saved searches that will specifically open Home Assistant logs when asked for.

### Option `enable_journal` (optional)

When this option is enabled, filebeat will also ingest journal logs. These logs will contain all logs from OS and addons as well. It may take a long time before journal is indexed depending on it's size so please be patient.

### Option `filebeat_version` (optional)

Select filebeat version to use for this addon. Make sure your filebeat version is compatible with Elasticsearch version. Please check [Product Compatability](https://www.elastic.co/support/matrix) for more information.
NOTE !!!
Please be careful in mixed filebeat versions on same elasticsearch index. Filebeat version 7.x.x cannot write to index if index was previously created by higher filebeat version. Keep filebeat versions same on all home assistant instances for same elasticsearch host.

### Option `fb_log_level` (optional)

Configure log level for filebeat. Keep in mind that "info" log level will produce output from filebeat on every 10 seconds. This may flood your journal and elasticsearch index if journal logging is enabled.

### Option `clear_cache` (optional)

By default set to false, once enabled, upon addon restart it will clear filebeat cache allowing to ingest same log file from scratch again. Due to certain limitations, addon will automatically set this flag to `false` upon running but that will not be reflected in Home Assistant UI (Configuration tab). This may cause confusion but if you don't manually revert this flag in Configuration tab, upon next reboot cache `will not` be cleared. You have to disable then re-enable if you wish to clear the cache again.

### Option `debug_mode` (optional)

It will only run bash infinite loop so that it will allow you to enter docker container and execute commands yourself for troubleshooting purposes.
To enter docker container of this addon, SSH into the home assistant host or attach to console directly, then run command:
```
docker exec -it $(docker container ls | grep filebeat | awk '{print $NF}') bash
```

[addon-badge]: https://my.home-assistant.io/badges/supervisor_addon.svg
[addon]: https://my.home-assistant.io/redirect/supervisor_addon/?addon=d256dda9_filebeat&repository_url=https://github.com/maretodoric/hassio-filebeat
