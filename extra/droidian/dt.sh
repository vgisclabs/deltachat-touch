#!/bin/sh
cd /home/lk/bin/deltatouch
env OPEN_OSK_VIA_DBUS=1 QML2_IMPORT_PATH=/home/droidian/bin/deltatouch/lib/aarch64-linux-gnu LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/droidian/bin/deltatouch/lib/aarch64-linux-gnu /home/droidian/bin/deltatouch/deltatouch $@
