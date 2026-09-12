#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Bluetti2MQTT
# MQTT bridge between Bluetti and Home Assistant
# ==============================================================================

bashio::log.info 'Reading configuration settings...'

MODE=$(bashio::config 'mode')
HA_CONFIG=$(bashio::config 'ha_config')
BT_MAC=$(bashio::config 'bt_mac')
POLL_SEC=$(bashio::config 'poll_sec')
SCAN=$(bashio::config 'scan')

configure_mqtt() {
	# Setup MQTT Auto-Configuration if values are not set.
	if bashio::config.has_value 'mqtt_host'; then
		MQTT_HOST=$(bashio::config 'mqtt_host')
	else
		MQTT_HOST=$(bashio::services "mqtt" "host") || MQTT_HOST=""
	fi

	if bashio::config.has_value 'mqtt_port'; then
		MQTT_PORT=$(bashio::config 'mqtt_port')
	else
		MQTT_PORT=$(bashio::services "mqtt" "port") || MQTT_PORT=""
	fi

	if bashio::config.has_value 'mqtt_username'; then
		MQTT_USERNAME=$(bashio::config 'mqtt_username')
	else
		MQTT_USERNAME=$(bashio::services mqtt "username") || MQTT_USERNAME=""
	fi

	if bashio::config.has_value 'mqtt_password'; then
		MQTT_PASSWORD=$(bashio::config 'mqtt_password')
	else
		MQTT_PASSWORD=$(bashio::services "mqtt" "password") || MQTT_PASSWORD=""
	fi

	if [ -z "${MQTT_HOST}" ]; then
		bashio::log.fatal "MQTT Host is not configured and could not be discovered via Home Assistant services. Please set 'mqtt_host' in the add-on configuration tab."
		exit 1
	fi

	if [ -z "${MQTT_PORT}" ]; then
		MQTT_PORT=1883
	fi
}

if [ $(bashio::config 'debug') == true ]; then
	export DEBUG=true
	bashio::log.info 'Debug mode is enabled.'
fi

args=()
if [ ${SCAN} == true ]; then
	args+=(--scan)
fi

case $MODE in

	mqtt)
		if [ "${SCAN}" == true ]; then
			bluetti-mqtt --scan
			exit $?
		fi
		configure_mqtt
		bashio::log.info 'Starting bluetti-mqtt...'
		args+=( \
			--broker "${MQTT_HOST}" \
			--port "${MQTT_PORT}" \
			--interval "${POLL_SEC}" \
			--ha-config "${HA_CONFIG}" \
		)
		if [ -n "${MQTT_USERNAME}" ]; then
			args+=(--username "${MQTT_USERNAME}")
		fi
		if [ -n "${MQTT_PASSWORD}" ]; then
			args+=(--password "${MQTT_PASSWORD}")
		fi
		if ! bashio::config.true 'ac200l_expansion_packs'; then
			args+=(--ac200l-standalone)
		fi
		args+=(${BT_MAC})
		bluetti-mqtt "${args[@]}"
		;;

	discovery)
		bashio::log.info 'Starting bluetti-discovery...'
		bashio::log.info 'Messages are NOT published to the MQTT broker in discovery mode.'
		mkdir -p /share/bluetti2mqtt/
		args+=( \
			--log /share/bluetti2mqtt/discovery_$(date "+%m%d%y%H%M%S").log \
			${BT_MAC})
		bluetti-discovery ${args[@]}
		;;

	logger)
		bashio::log.info 'Starting bluetti-logger...'
		bashio::log.info 'Messages are NOT published to the MQTT broker in logger mode.'
		if ! bashio::config.true 'ac200l_expansion_packs'; then
			args+=(--ac200l-standalone)
		fi
		mkdir -p /share/bluetti2mqtt/
		args+=( \
			--log /share/bluetti2mqtt/logger_$(date "+%m%d%y%H%M%S").log \
			${BT_MAC})
		bluetti-logger ${args[@]}
		;;

	*)
		bashio::log.warning "No mode selected!  Please choose either 'mqtt', 'discovery', or 'logger'."
		;;

esac
