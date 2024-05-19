/*
 * Copyright (C) 2024  Lothar Ketterer
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
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Dialog {
    id: dialog

    property string qrInviteLink

    title: i18n.tr("QR Invite Code")

    // TODO: offer a share to app function, similar as on Ubuntu Touch
    
    Label {
        // not using dialog.text, but a separate Label
        // to be able to set the wrapMode
        id: qrLabel
        text: qrInviteLink
        wrapMode: Text.WrapAnywhere
    }

    Button {
        id: clipboardButton
        onClicked: {
            let tempcontent = Clipboard.newData()
            tempcontent = qrInviteLink
            Clipboard.push(tempcontent)

            // Don't close directly, but show for 2 secs
            // that the url has been copied to the clipboard
            qrLabel.visible = false
            dialog.text = i18n.tr("Copied QR url to clipboard")
            title = ""
            cancelButton.visible = false
            clipboardButton.visible = false
            closeTimer.start()

        }
        text: i18n.tr("Copy to Clipboard")
        color: theme.palette.normal.positive
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(dialog)
        }
    }

    Timer {
        id: closeTimer
        interval: 2000
        repeat: false
        triggeredOnStart: false
        onTriggered: PopupUtils.close(dialog)
    }
}
