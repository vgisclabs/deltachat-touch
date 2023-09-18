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
import Ubuntu.Components 1.3
import Ubuntu.Content 1.3

import DeltaHandler 1.0

Page {
    id: audioToSendPage

    header: PageHeader {
        id: audioToSendHeader
        title: i18n.tr("Select")
    }


    property url source
    property var activeTransfer: null

    ContentPeerPicker {
        id: peerPicker
        //height: audioToSendPage.height - audioToSendHeader.height - cancelButton.height - units.gu(6)

        anchors {
            top: audioToSendHeader.bottom
            topMargin: units.gu(2)
            bottom: cancelButton.top
            bottomMargin: units.gu(2)
            left: audioToSendPage.left
            right: audioToSendPage.right
        }

        contentType: ContentType.Music
        handler: ContentHandler.Source
        showTitle: false

        onPeerSelected: {
            peer.selectionType = ContentTransfer.Single
            audioToSendPage.activeTransfer = peer.request()
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
        onClicked: layout.removePages(audioToSendPage)
    }

    Connections {
        target: audioToSendPage.activeTransfer
        onStateChanged: {
            if (audioToSendPage.activeTransfer.state === ContentTransfer.Charged) {
                if (audioToSendPage.activeTransfer.items.length > 0) {
                    audioToSendPage.source = DeltaHandler.copyToCache(audioToSendPage.activeTransfer.items[0].url);
                    console.log('Trying to send audio: ', audioToSendPage.source)
                    DeltaHandler.chatmodel.setAttachment(audioToSendPage.source, DeltaHandler.AudioType)
                }
                audioToSendPage.activeTransfer.finalize()
                layout.removePages(audioToSendPage)
            }
        }
    }
}
