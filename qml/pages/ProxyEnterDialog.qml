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
import Lomiri.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: enterProxyDialog

    signal proxyEntered(string newproxy)
    signal proxyFromClipboard(string newproxy)
    signal scanRequested()
    signal cancelled()

    Label {
        text: i18n.tr("Add Proxy")
        horizontalAlignment: Text.AlignLeft
        wrapMode: Text.Wrap
        fontSize: root.scaledFontSizeLarger
        visible: text !== ""
    }

    Label {
        text: i18n.tr("Supported proxy types: HTTP(S), SOCKS5 and Shadowsocks.")
        horizontalAlignment: Text.AlignLeft
        wrapMode: Text.Wrap
        fontSize: root.scaledFontSize
        visible: text !== ""
    }

    TextField {
        id: enterProxyField
        placeholderText: i18n.tr("Enter proxy link here")
        font.pixelSize: scaledFontSizeInPixels
        focus: true
        // onAccepted does not accept the Enter itself, so if we would call okButton.clicked(), 
        // the Enter would be propagated to the parent and cause an Enter event there. In the
        // parent (i.e., Proxy.qml), "Add Proxy" is in focus there, so the dialog would
        // directly be opened again. Solution is to give okButton focus so that it consumes
        // the Enter. See also
        // https://cdn2.hubspot.net/hubfs/149513/Roadshow_US/Best_Practices_in_Qt_Quick.pdf
        onAccepted: {
            okButton.focus = true
        }
    }

    Button {
        id: okButton
        text: i18n.tr("Use Proxy")
        color: theme.palette.normal.positive
        font.pixelSize: scaledFontSizeInPixels
        enabled: enterProxyField.displayText !== ""
        onClicked: {
            enterProxyField.focus = false
            let tempprox = enterProxyField.text
            PopupUtils.close(enterProxyDialog)
            proxyEntered(tempprox)
        }
    }

    Button {
        id: pasteButton
        text: i18n.tr("Paste from Clipboard")
        font.pixelSize: scaledFontSizeInPixels
        onClicked: {
            let tempprox = Clipboard.data.text
            if (tempprox !== "") {
                PopupUtils.close(enterProxyDialog)
                proxyFromClipboard(tempprox)
            }
        }
    }

    Button {
        id: scanButton
        text: i18n.tr("Scan QR Code")
        font.pixelSize: scaledFontSizeInPixels
        onClicked: {
            PopupUtils.close(enterProxyDialog)
            scanRequested()
        }
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        font.pixelSize: scaledFontSizeInPixels
        onClicked: {
            PopupUtils.close(enterProxyDialog)
            cancelled()
        }
    }
}
