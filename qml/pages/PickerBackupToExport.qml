/*
 * Copyright (C) 2016 Stefano Verzegnassi
 * Copyright (C) 2019 Joan CiberSheep
 * Copyright (C) 2023  Lothar Ketterer
 *
 * Originally from the app Gelek by Joan CiberSheep
 * (see https://gitlab.com/cibersheep/gelek/-/blob/master/qml/ExportPage.qml),
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
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: picker
    property var activeTransfer

    property string url: StandardPaths.locate(StandardPaths.CacheLocation, DeltaHandler.getUrlToExport())
    property var handler
    property var contentType

    //signal cancel()
    //signal imported(string fileUrl)

    header: PageHeader {
        title: i18n.tr("Select")
    }

    ContentPeerPicker {
        anchors {
            fill: parent
            topMargin: picker.header.height
        }

        visible: parent.visible
        showTitle: false
        contentType: ContentType.All
        handler: ContentHandler.Destination

        onPeerSelected: {
            picker.activeTransfer = peer.request()
            picker.activeTransfer.stateChanged.connect(function() {
                //console.log('in connected function, picker.activeTransfer.state is: ', picker.activeTransfer.state)
                if (picker.activeTransfer.state === ContentTransfer.InProgress) {
                //    console.log("Export: In progress, url is:", url);
                    picker.activeTransfer.items = [ resultComponent.createObject(parent, {"url": url}) ];
                    picker.activeTransfer.state = ContentTransfer.Charged;
                    DeltaHandler.removeTempExportFile()
                    layout.removePages(picker)
                }
            })
        }

        onCancelPressed: {
            layout.removePages(picker)
        }
    }

    ContentTransferHint {
        id: transferHint
        anchors.fill: parent
        activeTransfer: picker.activeTransfer
    }

    Component {
        id: resultComponent

        ContentItem {}
    }
}
