/*
 * Copyright 2014 Canonical Ltd.
 * Copyright (C) 2016 Stefano Verzegnassi
 * Copyright (C) 2019 Joan CiberSheep
 * Copyright (C) 2024  Lothar Ketterer
 *
 * Modified mix of a page of the app Gelek by Joan CiberSheep
 * (see https://gitlab.com/cibersheep/gelek/-/blob/master/qml/ExportPage.qml)
 * and the ContentPeerPicker from BarcodeReaderOverlay.qml in UBports Camera app
 * (https://gitlab.com/ubports/development/apps/lomiri-camera-app/-/blob/e9690a0bade4f166e4fc5deb17b2f690210a4877/BarcodeReaderOverlay.qml),
 * this file has been modified to be part of the app "DeltaTouch".
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License 3 as published by
 * the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see http://www.gnu.org/licenses/.
 */

import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Content 1.3
//import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: stringSharePage
    property var activeTransfer

    property string stringToShare
    property var handler

    header: PageHeader {
        title: i18n.tr("Select")
    }

    // TODO: maybe add an area where the link is shown and a button
    // offers to copy it to the clipboard?

    ContentPeerPicker {
        anchors {
            fill: parent
            topMargin: stringSharePage.header.height
        }

        visible: parent.visible
        showTitle: false
        contentType: ContentType.Text

        handler: ContentHandler.Destination

        onPeerSelected: {
            stringSharePage.activeTransfer = peer.request()
            stringSharePage.activeTransfer.items = [ resultComponent.createObject(parent,
                                                                       { "text": stringSharePage.stringToShare }) ];
            activeTransfer.state = ContentTransfer.Charged;
            layout.removePages(stringSharePage)
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
            layout.removePages(stringSharePage)
        }
    }

    ContentTransferHint {
        id: transferHint
        anchors.fill: parent
        activeTransfer: stringSharePage.activeTransfer
    }

    Component {
        id: resultComponent

        ContentItem {}
    }
}
