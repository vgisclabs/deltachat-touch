#!/bin/sh
cd /home/droidian/bin/deltatouch
#export QT_IM_MODULE=qtvirtualkeyboard
QT_QPA_PLATFORMTHEME=qt5ct OPEN_OSK_VIA_DBUS=1 QML2_IMPORT_PATH=/usr/lib/aarch64-linux-gnu/ ./deltatouch 
