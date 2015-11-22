#!/bin/bash
xrandr --setprovideroutputsource 1 0
xrandr --output VGA1 --left-of DVI-0
xrandr --output VGA1 --auto --pos 0x180 --output DVI-0  --auto --pos 1440x0
