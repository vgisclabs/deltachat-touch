/*
 * Copyright (C) 2023  Lothar Ketterer
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

Dialog {
    id: dialog

    signal done()

    Label {
        horizontalAlignment: Text.LeftAlign
        wrapMode: Text.WordWrap
        text: i18n.tr("Webxdc support is not complete yet.\n\nSome functions such as realtime channels, file import or sending files to other chats (needed for, e.g., the Webxdc Store app) will not work.\n\nDownload apps from webxdc.org and add them to chats as file attachments.")
        fontSize: root.scaledFontSize
    }

    Row {
        id: switchRow
        spacing: units.gu(1)

        Label {
            id: doNotShowAgainLabel
            // Currently, the contentsColumn in the Flickable in Dialog has
            // width of foreground.width - foreground.margins * 2
            // and foreground.margins is currently units.gu(4) => units.gu(8)
            width: dialog.contentWidth - (doNotShowAgainSwitch.width + switchRow.spacing + units.gu(8))
            text: i18n.tr("Do not show again")
            wrapMode: Text.WordWrap
            fontSize: root.scaledFontSize
        }

        Switch {
            id: doNotShowAgainSwitch
            anchors.verticalCenter: doNotShowAgainLabel.verticalCenter
            checked: false
        }
    }

    Button {
        text: 'OK'
        color: theme.palette.normal.focus
        onClicked: {
            if (doNotShowAgainSwitch.checked) {
                root.webxdcTestingEnabled = true
            }

            PopupUtils.close(dialog)
            done()
        }
    }
}
