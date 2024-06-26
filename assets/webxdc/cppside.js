/*
 * Copyright (C) 2024 Lothar Ketterer
 *
 * This file is part of the app "DeltaTouch".
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * deltatouch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * This file is based on the blog article
 * https://decovar.dev/blog/2018/07/14/html-from-qml-over-webchannel-websockets/#webengineview---direct-webchannel
 * licensed under GPLv3, and modified by Lothar Ketterer.
 */

var cppside = {
    selfName: "<cppside uninitialized state>",
};

new QWebChannel(qt.webChannelTransport, function(channel) {
    cppside = channel.objects.intJsApi
})
