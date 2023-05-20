/*
 * Copyright (C) 2022  Lothar Ketterer
 *
 * This file is part of the app "rounds".
 *
 * rounds is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * rounds is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.7
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: confirmDelFromDevice

    property string deleteAfterXSeconds: ""
    property string deleteAfterXTime: ""

    signal confirmed()

    Component.onCompleted: {
    }

    title: i18n.tr("Delete Messages from Device")

    Label {
        id: confirmLabel1
        text: i18n.tr("Do you want to delete %1 messages now and all newly fetched messages \"%2\" in the future?\n\n• This includes all media\n\n• Messages will be deleted whether they were seen or not\n\n• \"Saved messages\" will be skipped from local deletion").arg(DeltaHandler.getDeletionEstimation(deleteAfterXSeconds, 0)).arg(deleteAfterXTime)
        wrapMode: Text.Wrap
    }

    Rectangle {
        width: parent.width
        height: confirmLabel2.contentHeight

        Switch {
            id: confirmSwitch
            anchors.left: parent.left
            checked: false
            onCheckedChanged: {
                okButton.enabled = confirmSwitch.checked
            }
        }

        Label {
            id: confirmLabel2
            width: parent.width - confirmSwitch.width - units.gu(1)
            anchors.left: confirmSwitch.right
            anchors.leftMargin: units.gu(1)
            text: i18n.tr("I understand, delete all these messages")
            wrapMode: Text.Wrap
        }
    }

    Button {
        id: okButton
        text: i18n.tr("OK")
        color: theme.palette.normal.negative
        onClicked: {
            DeltaHandler.setCurrentConfig("delete_device_after", deleteAfterXSeconds)
            confirmed()
        }
        enabled: false
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(confirmDelFromDevice)
        }
    }
}
