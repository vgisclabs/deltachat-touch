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
    id: fileExportPage
    property var activeTransfer

    property string url: StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.chatmodel.getUrlToExport())
    property var handler
    property var conType: DeltaHandler.FileType

    signal success()
    signal cancelled()

    header: PageHeader {
        title: i18n.tr("Select")
    }

    ContentPeerPicker {
        anchors {
            fill: parent
            topMargin: fileExportPage.header.height
        }

        visible: parent.visible
        showTitle: false
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

        handler: ContentHandler.Destination

        onPeerSelected: {
            fileExportPage.activeTransfer = peer.request()
            fileExportPage.activeTransfer.stateChanged.connect(function() {
                //console.log('in connected function, fileExportPage.activeTransfer.state is: ', fileExportPage.activeTransfer.state)
                if (fileExportPage.activeTransfer.state === ContentTransfer.InProgress) {
                //    console.log("Export: In progress, url is:", url);
                    fileExportPage.activeTransfer.items = [ resultComponent.createObject(parent, {"url": url}) ];
                    fileExportPage.activeTransfer.state = ContentTransfer.Charged;
                    layout.removePages(fileExportPage)
                    success()
                }
            })
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
            layout.removePages(fileExportPage)
            cancelled()
        }
    }

    ContentTransferHint {
        id: transferHint
        anchors.fill: parent
        activeTransfer: fileExportPage.activeTransfer
    }

    Component {
        id: resultComponent

        ContentItem {}
    }
}
