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
    id: dialog

    property int indexToUnblock: -1

    signal unblockContact(int index)

    Label {
        text: i18n.tr("Unblock this contact? You will then be able to receive messages from them.")
        wrapMode: Text.Wrap
    }

    Button {
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(dialog)
        }
    }
    Button {
        text: i18n.tr('Unblock Contact')
        color: theme.palette.normal.positive
        onClicked: {
            dialog.unblockContact(indexToUnblock)
            PopupUtils.close(dialog)
        }
    }

    Component.onCompleted: {
        dialog.unblockContact.connect(DeltaHandler.blockedcontactsmodel.unblockContact)
    }

}
