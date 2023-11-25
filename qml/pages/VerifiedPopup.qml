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
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Dialog {
    id: dialog

    property bool protectionEnabled: true
    property string chatuser

    signal learnMore()
    signal scanQr()

    text: protectionEnabled ? i18n.tr('It is now guaranteed that all messages in this chat are end-to-end encrypted.\n\nEnd-to-end encryption keeps messages private between you and your chat partners. Not even your email provider can read them.') : i18n.tr('End-to-end encryption cannot be guaranteed anymore, likely because %1 reinstalled Delta Chat or sent a message from another device.\n\nYou may meet them in person and scan their QR code again to reestablish guaranteed end-to-end encryption.').arg(chatuser)

    Button {
        text: i18n.tr('OK')
        color: protectionEnabled ? theme.palette.normal.positive : theme.palette.normal.negative
        onClicked: {
            PopupUtils.close(dialog)
        }
    }

    Button {
        text: i18n.tr('Scan QR Code')
        visible: !protectionEnabled
        onClicked: {
            PopupUtils.close(dialog)
            scanQr()
        }
    }

    Button {
        text: i18n.tr('Learn More')
        iconSource: root.darkmode ? "../assets/external-link-black.svg" : "../assets/external-link-white.svg"
        onClicked: {
            PopupUtils.close(dialog)
            learnMore()
        }
    }
}
