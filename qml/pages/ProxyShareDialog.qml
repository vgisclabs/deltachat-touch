/*
 * Copyright (C) 2024 Lothar Ketterer
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

import QtQuick 2.7
import Lomiri.Components 1.3
// didn't work without the qualifier, does Qt.labs.platform interfere with dialog?
import Lomiri.Components.Popups 1.3 as LCP
import Qt.labs.platform 1.1

import DeltaHandler 1.0

LCP.Dialog {
    id: proxyShareDialog

    property string proxyUrl: ""

    Image {
        id: qrImage
        width: parent.width
        fillMode: Image.PreserveAspectFit
        source: StandardPaths.locate(StandardPaths.CacheLocation, DeltaHandler.createQrInCache(proxyUrl))
    }

    Label {
        id: proxyLabel
        text: proxyUrl
        fontSize: root.scaledFontSizeSmaller
    }

    Label {
        id: infoLabel
        text: i18n.tr("Your friends can add this proxy by scanning the QR code.")
        wrapMode: Text.Wrap
        fontSize: root.scaledFontSize
    }

    Button {
        id: clipboardButton
        iconSource: "qrc:///assets/edit-copy-white.svg"
        onClicked: {
            let tempcontent = Clipboard.newData()
            tempcontent = proxyUrl
            Clipboard.push(tempcontent)

            // Don't close directly, but show for 2 secs
            // that the url has been copied to the clipboard
            qrImage.visible = false
            proxyLabel.visible = false
            infoLabel.visible = false
            proxyShareDialog.text = i18n.tr("Copied QR url to clipboard")
            okButton.visible = false
            clipboardButton.visible = false
            shareButton.visible = false
            closeTimer.start()

        }
        text: i18n.tr("Copy to Clipboard")
        font.pixelSize: scaledFontSizeInPixels
    }

//    Button {
//        // TODO: How to correctly share a proxy url? Qt.openUrlExternally doesn't work
//        id: shareButton
//        iconSource: "qrc:///assets/suru-icons/share.svg"
//        text: i18n.tr("Share")
//        font.pixelSize: scaledFontSizeInPixels
//        onClicked: {
//            let retval = Qt.openUrlExternally(proxyUrl)
//            if (retval) {
//                // According to Qt documentation, a return value of true just means
//                console.log("Qt.openUrlExternally(", proxyUrl, ") returned true")
//            } else {
//                console.log("Qt.openUrlExternally(", proxyUrl, ") returned false")
//            }
//        }
//    }

    Button {
        id: okButton
        text: i18n.tr("OK")
        font.pixelSize: scaledFontSizeInPixels
        color: theme.palette.normal.positive
        onClicked: {
            PopupUtils.close(proxyShareDialog)
        }
    }

    Timer {
        id: closeTimer
        interval: 1000
        repeat: false
        triggeredOnStart: false
        onTriggered: PopupUtils.close(proxyShareDialog)
    }
}
