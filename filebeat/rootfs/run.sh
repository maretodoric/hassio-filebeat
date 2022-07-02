#!/usr/bin/with-contenv bashio

export CUSTOM_PIPELINE=false
export FILEBEAT_PID=0

export API_CONFIG
export API_HA_VERSION
export HA_UUID

if bashio::config.true 'debug_mode'; then
	set -x
fi

# Log function alias
function l {
        if [ "$1" == "e" ]; then
                shift
                bashio::log.error ${@}
        elif [ "$1" == "w" ]; then
                shift
		bashio::log.warning ${@}
        else
                bashio::log.info ${@}
        fi
}

function _config_check {
	local pipeline_path es_host kibana_host

	# TZ env pre-check
	if bashio::var.is_empty "${TZ}"; then
		l e "Time zone does not appear to be configured. Please configure Time zone in your Home Assistant - https://www.home-assistant.io/docs/configuration/basic/"
		exit 1
	fi

	# Syntax check
	es_host=$(bashio::config es_url)
	kibana_host=$(bashio::config kibana_url)
	if ! [[ $es_host =~ ^http ]]; then
		l e "Elasticsearch URL does not appear to be in correct format, exiting"
		exit 1
	fi

	if ! [ x"$kibana_host" == "x" ] && ! [[ $kibana_host =~ ^http ]]; then
		l e "Kibana URL does not appear to be in correct format, exiting"
		exit 1
	fi

	# This is to clear the filebeat cache
	if bashio::config.true 'clear_cache'; then
		l "I'm asked to clear filebeat cache, removing..."
		rm -rf /data/filebeat/*
		bashio::addon.option clear_cache false
	fi

	# This one is to ingest custom pipeline if asked
	if bashio::config.has_value es_pipeline_path; then
		pipeline_path=$(bashio::config es_pipeline_path)
		l Custom pipeline requested to be added
		if [[ $pipeline_path =~ ^/config ]]; then
			if [ -f ${pipeline_path} ]; then
				CUSTOM_PIPELINE=true
				l "Found ${pipeline_path} and importing to module config"
				cp ${pipeline_path} /opt/filebeat/module/hass/main/ingest/pipeline.yml
			else
				l w "File not found at: ${pipeline_path}, using default pipeline"
			fi
		elif [[ $pipeline_path =~ ^http ]]; then
			curl -sS --fail-with-body ${pipeline_path} --output /opt/filebeat/module/hass/main/ingest/pipeline.yml
			if [ $? -gt 0 ]; then
				l w "Retrieval of custom pipeline via curl failed with exit code: $?. Using default pipeline."
				rm -rf /opt/filebeat/module/hass/main/ingest/pipeline.yml
			else
				CUSTOM_PIPELINE=true
				l Successfully retrieved pipeline via URL ${pipeline_path}
			fi
		else
			l e "Unknown format of pipeline path, needs to be either local path in /config/... or http|https URL"
		fi
	fi

	# Symlink selected filebeat version
	l "Using Filebeat version $(bashio::config filebeat_version)"
	ln -s /bin/filebeat-$(bashio::config filebeat_version) /bin/filebeat
}

function _write_cfg {
l "Generating filebeat.yml file"

API_HA_VERSION=$(curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/info | jq .data.homeassistant)
HA_UUID=$(jq .data.uuid /config/.storage/core.uuid)
JOURNAL_PATH=$(find /var/log/journal -name system.journal)

l "Got Home Assistant Version: ${API_HA_VERSION}"
l "Got Home Assistant UUID: ${HA_UUID}"

cat << EOF > /opt/filebeat/filebeat.yml
filebeat.modules:
- module: hass
  main:
    enabled: true
  journal:
    enabled: $(bashio::config enable_journal)
    var.paths:
      - ${JOURNAL_PATH}
filebeat.inputs:
- type: filestream
  enabled: false
filebeat.overwrite_pipelines: true

setup.template.overwrite: false
setup.template.name: $(bashio::config es_index)
setup.template.pattern: $(bashio::config es_index)*
setup.template.settings:
  index.number_of_shards: $(bashio::config es_number_of_shards)
  index.number_of_replicas: $(bashio::config es_number_of_replicas)
$(if [[ $(bashio::config filebeat_version) =~ ^7 ]]; then echo -e "setup.ilm.enabled: false\n"; fi)
output.elasticsearch:
  hosts: [ "$(bashio::config es_url)" ]
  username: $(bashio::config es_username)
  password: $(bashio::config es_password)
  $(if [[ $(bashio::config es_url) =~ ^https ]]; then echo -e "ssl.enabled: true\n  ssl.verification_mode: $(bashio::config es_ssl_verification_mode)"; fi)

logging.level: $(bashio::config fb_log_level)
logging.metrics.enabled: false
logging.to_files: false

processors:
  - add_fields:
      target: hass
      fields:
        version: ${API_HA_VERSION}
        uuid: ${HA_UUID}
EOF

cat << EOF > /opt/filebeat/module/hass/main/config/main.yml
type: filestream
paths:
{{ range \$i, \$path := .paths }}
 - {{\$path}}
{{ end }}
id: hass-main-filestream
index: $(bashio::config es_index)
parsers:
  - multiline:
      type: pattern
      pattern: ^(\d+\-?){3}\s(\d+\:?){3}
      match: after
      negate: true
processors:
  - add_locale: ~
  - add_fields:
      target: ''
      fields:
        ecs.version: 1.12.0
EOF

cat << EOF > /opt/filebeat/module/hass/journal/config/journal.yml
type: journald
paths:
{{ range \$i, \$path := .paths }}
 - {{\$path}}
{{ end }}
id: hass-journald
index: $(bashio::config es_index)
processors:
  - add_locale: ~
  - add_fields:
      target: ''
      fields:
        ecs.version: 1.12.0
EOF

if ! $CUSTOM_PIPELINE; then
HA_DOMAINS=$(echo $(curl -sX GET -H "Authorization: Bearer ${HASSIO_TOKEN}" -H "Content-Type: application/json" http://supervisor/core/api/states | jq .[].entity_id | sed 's/"//' | cut -d . -f1 | sort | uniq) | sed 's/ /|/g')
l "Updating domains: ${HA_DOMAINS}"
sed -i "s/CHANGEDOMAINS/'${HA_DOMAINS}'/g" -i /opt/filebeat/module/hass/main/ingest/pipeline.yml
fi
}

function _run {
    l "Attempting test connection to ES host."
    tagline=$(curl -s --user $(bashio::config es_username):$(bashio::config es_password) $(bashio::config es_url) | jq .tagline || true)
    if [ "${tagline}" == '"You Know, for Search"' ]; then
		if bashio::config.has_value kibana_url; then
			l Importing saved search and index pattern...
			sed -i "s|INDEXCHANGEME|$(bashio::config es_index)|g" /opt/filebeat/kibana/7/index-pattern/a95e6e90-f079-11ec-b291-63c17d65b83a.json
			/bin/filebeat setup --path.config /opt/filebeat --path.home /opt/filebeat --path.data /data/filebeat -E setup.kibana.host=$(bashio::config kibana_url) -E logging.level=error -e
		fi
		l Starting filebeat in forked process...
		/bin/filebeat --path.config /opt/filebeat --path.home /opt/filebeat --path.data /data/filebeat -e &
        FILEBEAT_PID=$!
	else
		l e "Elasticsearch host appears to be unavailable/unreachable"
		exit 1
	fi
}

function _restart {
    kill -15 $FILEBEAT_PID
    __now=0
    until [ ! -d /proc/$FILEBEAT_PID ]; do
        if [ $__now -eq 15 ]; then
            l e Timeout waiting for filebeat to quit, stopping addon.
            exit 1
        fi
         l "Waiting for filebeat to quit"
        __now=$((__now+1))
        sleep 2
    done
    source /02-write_cfg.sh
    _run
}

function _run_loop {
	OLD_API_HA_VERSION=$API_HA_VERSION

	while true; do
		if [ $FILEBEAT_PID -eq 0 ]; then
			_run
		else
			if [ -d /proc/$FILEBEAT_PID ]; then
				API_HA_VERSION=$(curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/info | jq .data.homeassistant)
				if [ $API_HA_VERSION != $OLD_API_HA_VERSION ]; then
					l "Home Assistant version was changed - possibly updated. Restarting filebeat to accomodate changes."
					_restart
					OLD_API_HA_VERSION=$API_HA_VERSION
				fi
			else
				l w "Filebeat not running! Could be crashed! Restarting..."
				_run
			fi
		fi
		sleep 60
	done
}
function _loop {
	while true; do
		sleep 2
	done

}

l "Starting run.sh for addon: addon_${HOSTNAME/\-/_}"

l ======== Running Config Check ========
_config_check
l ======== Finished Config Check ========

l ======== Running Write CFG ========
_write_cfg
l ======== Finished  Write CFG ========

if bashio::config.true 'debug_mode'; then
	env > /env
	set > /set
	l "Debug mode requested, not running filebeat."
	l "Current environment saved in /env and /set"
	l "Attach to debug mode using docker exec -it addon_${HOSTNAME/\-/_} bash"
	_loop
else
	l "======== Running Filebeat ========"
	_run_loop
	l "======== Finished Filebeat ========"
fi
