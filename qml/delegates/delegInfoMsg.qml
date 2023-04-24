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
//import Qt.labs.settings 1.0

import DeltaHandler 1.0


UbuntuShape {
    id: msgbox
    height: units.gu(0.5) + msgLabel.contentHeight + msgDate.contentHeight + units.gu(0.5)
    width: units.gu(3) + (msgDate.contentWidth > msgLabel.contentWidth ? msgDate.contentWidth : msgLabel.contentWidth) + units.gu(3)

    anchors {
        left: parent.left
        leftMargin: (parentWidth - width)/2
        bottom: parent.bottom
    }
    backgroundColor: root.darkmode ? "#c0c0c0" : "#505050"
    aspect: UbuntuShape.Flat
    radius: "large"

    // idea taken from fluffychat

    Label {
        id: msgLabel
        width: parentWidth - units.gu(10)
        anchors {
            left: parent.left
            leftMargin: (parent.width - contentWidth)/2
            top: parent.top
            topMargin: units.gu(0.5)
        }
        text: model.text
        color: root.darkmode ? "black" : "white"
        wrapMode: Text.Wrap
    }


    Label {
        id: msgDate
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: units.gu(0.5)
        }
        //textSize: Label.Small
        text: model.date
        fontSize: "x-small"
        color: msgLabel.color
    }
}
