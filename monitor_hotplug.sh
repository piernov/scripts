#!/usr/bin/env bash


export DISPLAY=:0
export XAUTHORITY=/var/lib/lightdm/.Xauthority

sleep 10

echo "Display unplugged or plugged in" >> /tmp/hotplug_log.sh
sudo -u lightdm /usr/bin/xrandr |& tee -a /tmp/hotplug_log.sh
echo "Autoconfiguring displays…" >> /tmp/hotplug_log.sh
sudo -u lightdm /usr/bin/xrandr --auto |& tee -a /tmp/hotplug_log.sh

