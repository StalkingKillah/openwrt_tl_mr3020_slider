#!/bin/sh
chmod a+x usr/local/sbin/* etc/init.d/slider etc/hotplug.d/button/00-button

echo "Copying to lib"
mkdir -p /usr/local/lib
cp usr/local/lib/* /usr/local/lib
echo "Copying to sbin"
mkdir -p /usr/local/sbin
cp usr/local/sbin/* /usr/local/sbin
echo "Copying to hotplug.d"
mkdir -p /etc/hotplug.d/button
cp etc/hotplug.d/button/00-button /etc/hotplug.d/button
echo "Copying to init.d"
cp etc/init.d/slider /etc/init.d

if [[ ! -x "$(command -v flock)" ]]; then
	echo "Installing dependencies"
	opkg update
	opkg install flock
fi

echo "Creating network configurations from current network configuration"
for mode in 3g wisp ap default; do
	echo "Creating configuration for $mode"
	mkdir -p /etc/config/$mode
	cp /etc/config/network /etc/config/$mode
	cp /etc/config/wireless /etc/config/$mode
done
echo "Enabling slider init.d"
/etc/init.d/slider enable

echo "Executing uci batch"
BATCH_BUTTONS="add system button
set system.@button[-1].button=3g
set system.@button[-1].hw_button=BTN_0
set system.@button[-1].pressed=/usr/local/sbin/switch_network
add system button
set system.@button[-1].button=wisp
set system.@button[-1].hw_button=BTN_1
set system.@button[-1].pressed=/usr/local/sbin/switch_network
add system button
set system.@button[-1].button=ap
set system.@button[-1].hw_button=BTN_0
set system.@button[-1].pressed=/usr/local/sbin/switch_network
add system button
set system.@button[-1].button=wps
set system.@button[-1].hw_button=wps
set system.@button[-1].pressed=/usr/local/sbin/commit_network
set system.@button[-1].hold=/usr/local/sbin/wifionoff
set system.@button[-1].hold_min=5
set system.@button[-1].hold_max=10"
echo "Batch job:"
echo "$BATCH_BUTTONS"
echo "$BATCH_BUTTONS" | uci batch > /dev/null
echo "Changes:"
uci changes system
while true; do
    read -p "Commit changes?[y/n]" yn
    case $yn in
        [Yy]* )
					uci commit system
					echo "Rebooting..."
					reboot
					exit
					;;
        [Nn]* ) 
					uci revert system
					exit
					;;
        * ) echo "Please answer yes or no.";;
    esac
done
