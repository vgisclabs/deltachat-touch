/*
 * Copyright (C) 2019 Tim Süberkrüb <dev@timsueberkrueb.io>
 * Copyright (C) 2023, 2024  Lothar Ketterer
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

// File is only available on Ubuntu Touch, see
// the QQmlFileSelector in main.cpp

Page {
    id: fileImportPage

    header: PageHeader {
        id: fileToSendHeader
        title: i18n.tr("Select")
    }

    property var conType: DeltaHandler.FileType
    property var activeTransfer: null

    signal fileSelected(string fileUrl)
    signal cancelled()

    ContentPeerPicker {
        id: peerPicker

        anchors {
            top: fileToSendHeader.bottom
            topMargin: units.gu(2)
            bottom: cancelButton.top
            bottomMargin: units.gu(2)
            left: fileImportPage.left
            right: fileImportPage.right
        }

        contentType: {
            switch (conType) {
                case DeltaHandler.AudioType:
                    return ContentType.Music
                    break
                case DeltaHandler.ImageType:
                    return ContentType.Pictures
                    break
                case DeltaHandler.FileType: // fallthrough
                default:
                    return ContentType.All
                    break
            }
        }

        handler: ContentHandler.Source
        showTitle: false

        onPeerSelected: {
            peer.selectionType = ContentTransfer.Single
            fileImportPage.activeTransfer = peer.request()
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
        text: i18n.tr("Cancel")
        onClicked: {
            layout.removePages(fileImportPage)
            cancelled()
        }
    }

    Connections {
        target: fileImportPage.activeTransfer
        onStateChanged: {
            if (fileImportPage.activeTransfer.state === ContentTransfer.Charged) {
                if (fileImportPage.activeTransfer.items.length > 0) {
                    let fileUrl = DeltaHandler.copyToCache(fileImportPage.activeTransfer.items[0].url);
                    console.log('Selected file via ContentHub: ', fileUrl)
                    fileSelected(fileUrl)
                }
                fileImportPage.activeTransfer.finalize()
                layout.removePages(fileImportPage)
            }
        }
    }
}
