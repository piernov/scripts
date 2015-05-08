#!/bin/bash

xrandr --newmode  "1280x768_60.00"   79.50  1280 1344 1472 1664  768 771 781 798 -hsync +vsync
xrandr --addmode DP2 1280x768_60.00
xrandr --output DP2 --mode 1280x768_60.00
