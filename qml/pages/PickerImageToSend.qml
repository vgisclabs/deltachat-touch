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
    id: imageToSendPage

    header: PageHeader {
        id: imageToSendHeader
        title: i18n.tr("Select")
    }


    property url source
    property var activeTransfer: null

    ContentPeerPicker {
        id: peerPicker
        //height: imageToSendPage.height - imageToSendHeader.height - cancelButton.height - units.gu(6)

        anchors {
            top: imageToSendHeader.bottom
            topMargin: units.gu(2)
            bottom: cancelButton.top
            bottomMargin: units.gu(2)
            left: imageToSendPage.left
            right: imageToSendPage.right
        }

        contentType: ContentType.Pictures
        handler: ContentHandler.Source
        showTitle: false

        onPeerSelected: {
            peer.selectionType = ContentTransfer.Single
            imageToSendPage.activeTransfer = peer.request()
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
        onClicked: layout.removePages(imageToSendPage)
    }

    Connections {
        target: imageToSendPage.activeTransfer
        onStateChanged: {
            if (imageToSendPage.activeTransfer.state === ContentTransfer.Charged) {
                if (imageToSendPage.activeTransfer.items.length > 0) {
                    imageToSendPage.source = imageToSendPage.activeTransfer.items[0].url;
                    console.log('Setting image attachment: ', imageToSendPage.source)
                    if (DeltaHandler.chatmodel.isGif(imageToSendPage.source)) {
                        DeltaHandler.chatmodel.setAttachment(imageToSendPage.source, DeltaHandler.GifType)
                    } else {
                        DeltaHandler.chatmodel.setAttachment(imageToSendPage.source, DeltaHandler.ImageType)
                    }
                }
                layout.removePages(imageToSendPage)
            }
        }
    }
}
