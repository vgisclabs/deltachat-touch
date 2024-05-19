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

import DeltaHandler 1.0

Dialog {
    id: dialog

    signal cancelled()
    signal confirmed()

    Component.onCompleted: {
    }

    // TODO string not translated yet
    title: i18n.tr("Really encrypt the database?")

    Label {
        id: confirmLabel1
        // TODO string not translated yet
        text: DeltaHandler.numberOfAccounts() > 0 ?  i18n.tr("• Database encryption is experimental, use at your own risk. Backup your accounts or add a second device first.\n\n• It will only cover text messages and username/password of mail accounts. Pictures, voice messages, files etc. will remain unencrypted.\n\n• If the phassphrase is lost, your data will be lost as well.\n\n• You will have to enter the phassphrase upon each startup of the app.") : i18n.tr("• Database encryption is experimental, use at your own risk.\n\n• It will only cover text messages and username/password of mail accounts. Pictures, voice messages, files etc. will remain unencrypted.\n\n• If the phassphrase is lost, your data will be lost as well.\n\n• You will have to enter the phassphrase upon each startup of the app.")
        wrapMode: Text.WordWrap
    }

    Button {
        id: okButton
        text: i18n.tr("Continue")
        color: theme.palette.normal.positive
        onClicked: {
            PopupUtils.close(dialog)
            confirmed()
        }
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(dialog)
            cancelled()
        }
    }
}
