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

import DeltaHandler 1.0

Dialog {
    id: confirmAccountDel

    property int accountArrayIndex
    property string accountAddr

    Component.onCompleted: {
        accountAddr = DeltaHandler.accountsmodel.getAddressOfIndex(accountArrayIndex)
    }

    title: i18n.tr("Delete Account")

    Label {
        id: confirmLabel1
        text: i18n.tr('Are you sure you want to delete your account data?')
        wrapMode: Text.Wrap
    }

    Label {
        id: confirmLabel2
        text: i18n.tr('All account data of \"%1\" on this device will be deleted, including your end-to-end encryption setup, contacts, chats, messages and media. This action cannot be undone.').arg(accountAddr)
        wrapMode: Text.Wrap
    }

    Button {
        id: okButton
        text: i18n.tr("Delete Account")
        color: theme.palette.normal.negative
        onClicked: {
            DeltaHandler.accountsmodel.deleteAccount(accountArrayIndex)
            PopupUtils.close(confirmAccountDel)
        }
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(confirmAccountDel)
        }
    }
}
