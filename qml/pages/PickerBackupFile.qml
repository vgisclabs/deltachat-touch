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
import Lomiri.Components.Popups 1.3
import Lomiri.Content 1.3

import DeltaHandler 1.0

Page {
    id: backupPickerPage

    header: PageHeader {
        id: backupPickerHeader
        title: i18n.tr("Restore from Backup")
    }


    property url source
    property var activeTransfer: null

    ContentPeerPicker {
        id: peerPicker
        //height: backupPickerPage.height - backupPickerHeader.height - cancelButton.height - units.gu(6)

        anchors {
            top: backupPickerHeader.bottom
            topMargin: units.gu(2)
            bottom: cancelButton.top
            bottomMargin: units.gu(2)
            left: backupPickerPage.left
            right: backupPickerPage.right
        }

        contentType: ContentType.All
        handler: ContentHandler.Source
        showTitle: false

        onPeerSelected: {
            peer.selectionType = ContentTransfer.Single
            backupPickerPage.activeTransfer = peer.request()
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
        onClicked: layout.removePages(backupPickerPage)
    }

    Connections {
        target: backupPickerPage.activeTransfer
        onStateChanged: {
            if (backupPickerPage.activeTransfer.state === ContentTransfer.Charged) {
                if (backupPickerPage.activeTransfer.items.length > 0) {
                    // CAVE: The file in the HubIncoming dir has to be copied
                    // to another location in the cache as the file
                    // in HubIncoming will be deleted right after the call
                    // to isBackupFile() via finalize() below. Any subsequent work
                    // has to be done with the copy in the cache, not with the file
                    // in HubIncoming.
                    backupPickerPage.source = DeltaHandler.copyToCache(backupPickerPage.activeTransfer.items[0].url)
                    if (DeltaHandler.isBackupFile(backupPickerPage.source)) {
                        // Actual import will be started in the popup.
                        PopupUtils.open(progressBackupImport)
                    } else {
                        PopupUtils.open(errorMessage)
                    }
                    // to delete the temporary file in HubIncoming
                    backupPickerPage.activeTransfer.finalize()

                } else {
                    layout.removePages(backupPickerPage)
                }
            }
        }
    }

    Component {
        id: errorMessage
        ErrorMessage {
            title: i18n.tr('Error')
            text: i18n.tr('The selected file is not a valid backup file.') // new i18n string needed
        }
    }

    Component {
        id: progressBackupImport
        ProgressBackupImport {
            title: i18n.tr('Restore from Backup')
        }
    }
}
