#!/bin/sh
# export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

ME=$(basename $0)
DEBUG=0
log () {
	logger -t "$ME" "$@"
}
debug () {
	if [ $DEBUG -eq 1 ]; then
		log $@
	fi
}
warn () {
	log -p "user.warn" "$@"
}
alias read_log='logread | grep -E "hotplug.d|update_network|switch_network|rc.common"'

alias is_3g='grep -qe "sw1.*in  hi" /sys/kernel/debug/gpio'
alias is_wisp='grep -qe "sw2.*in  hi" /sys/kernel/debug/gpio'
alias is_ap='is_3g && is_wisp'
STATE_3G=1
STATE_WISP=2
STATE_AP=3
get_slider_state () {
	if is_ap; then
		return $STATE_AP
	fi
	if is_3g; then
		return $STATE_3G
	fi
	if is_wisp; then
		return $STATE_WISP
	fi
	return 0
}
write_state_to_uci () {
	if ! uci -q get system.slider > /dev/null; then
		debug "Adding slider config to uci"
		uci set system.slider=slider
	fi
	log "Writing slider state to uci"
	get_slider_state
	uci set system.slider.state="$?"
	uci commit system
}
get_state_from_uci () {
	if ! uci -q get system.slider > /dev/null; then
		write_state_to_uci
		get_slider_state
		return $?
	fi
	return $(uci get system.slider.state)
}

CONFIGURATION_PATH="/etc/config"
set_network_configuration () {
	# TODO: Rewrite to use UCI commands for uci batch
	get_slider_state
	case "$?" in
		$STATE_3G)
			STATE="3g"
			;;
		$STATE_WISP)
			STATE="wisp"
			;;
		$STATE_AP)
			STATE="ap"
			;;
		*)
			STATE="default"
			;;
	esac
	STATE_CONFIGURATION="$CONFIGURATION_PATH/$STATE"
	log "Setting configuration to $STATE_CONFIGURATION"
	if [ -d "$STATE_CONFIGURATION" ]; then
		cp $STATE_CONFIGURATION/wireless $CONFIGURATION_PATH
		cp $STATE_CONFIGURATION/network $CONFIGURATION_PATH
	else
		warn "Configuration for $STATE isn't available"
	fi
}
commit_network_configuration () {
	# TODO: Rewrite to use UCI commands for uci batch
	get_state_from_uci
	case "$?" in
		$STATE_3G)
			STATE="3g"
			;;
		$STATE_WISP)
			STATE="wisp"
			;;
		$STATE_AP)
			STATE="ap"
			;;
		*)
			STATE="default"
			;;
	esac
	STATE_CONFIGURATION="$CONFIGURATION_PATH/$STATE"
	log "Committing configuration to $STATE_CONFIGURATION"
	if [ ! -d "$STATE_CONFIGURATION" ]; then
		mkdir -p "$STATE_CONFIGURATION"
	fi
	cp $CONFIGURATION_PATH/wireless $STATE_CONFIGURATION
	cp $CONFIGURATION_PATH/network $STATE_CONFIGURATION
}
switch_configuration () {
	commit_network_configuration
	set_network_configuration
}
