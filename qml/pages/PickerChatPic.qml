/*
 * Copyright (C) 2019 Tim Süberkrüb <dev@timsueberkrueb.io>
 * Copyright (C) 2023  Lothar Ketterer
 *
 * Originally from the app Webber by <Tim Süberkrüb <dev@timsueberkrueb.io>>,
 * this file has been modified to be part of the app "DeltaTouch".
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
import QtQuick 2.0
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.2
import QtQuick.Controls.Suru 2.2
import Lomiri.Components 1.3
import Lomiri.Content 1.3

import DeltaHandler 1.0

Page {
    id: picPickerPage

    header: PageHeader {
        id: picPickerHeader
        title: i18n.tr("Select Group Image")
    }


    property url source
    property var activeTransfer: null

    ContentPeerPicker {
        id: peerPicker
        //height: picPickerPage.height - picPickerHeader.height - cancelButton.height - units.gu(6)

        anchors {
            top: picPickerHeader.bottom
            topMargin: units.gu(2)
            bottom: cancelButton.top
            bottomMargin: units.gu(2)
            left: picPickerPage.left
            right: picPickerPage.right
        }

        contentType: ContentType.Pictures
        handler: ContentHandler.Source
        showTitle: false

        onPeerSelected: {
            peer.selectionType = ContentTransfer.Single
            picPickerPage.activeTransfer = peer.request()
        }
    }

    Button {
        id: cancelButton
        anchors {
            bottom: parent.bottom
            bottomMargin: units.gu(2)
            right: parent.right
            rightMargin: units.gu(4)
        }
        text: "Cancel"
        onClicked: layout.removePages(picPickerPage)
    }

    Connections {
        target: picPickerPage.activeTransfer
        onStateChanged: {
            if (picPickerPage.activeTransfer.state === ContentTransfer.Charged) {
                if (picPickerPage.activeTransfer.items.length > 0) {
                    picPickerPage.source = picPickerPage.activeTransfer.items[0].url;
                    DeltaHandler.setGroupPic(picPickerPage.source)
                }
                layout.removePages(picPickerPage)
            }
        }
    }
}
