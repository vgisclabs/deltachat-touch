/*
 * Copyright (C) 2023  Lothar Ketterer
 *
 * This file is part of the app "DeltaTouch".
 *
 * DeltaTouch is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * DeltaTouch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.12
import Ubuntu.Components 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0

import DeltaHandler 1.0

// Unread Messages bar, Teleports style
Rectangle {
    id: msgbox
    height: msgLabel.contentHeight + units.gu(0.5)
    width: parentWidth
    anchors {
        // needs to be anchored to the left, see the parent.left
        // definition for the Loader in ChatView.qml. Centering
        // won't work (except if the centers are set for the Loader?)
        left: parent.left
        top: parent.top
    }
    color: root.unreadMessageCounterColor

    Label {
        id: msgLabel
        anchors {
            horizontalCenter: msgbox.horizontalCenter
            verticalCenter: msgbox.verticalCenter
        }
        // TODO: this string has no translations!
        text: i18n.tr("Unread Messages")
        //color: "#e7fcfd"
    }
} // end Rectangle id: msgbox
