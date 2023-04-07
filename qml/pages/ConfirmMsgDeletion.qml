/*
 * Copyright (C) 2022  Lothar Ketterer
 *
 * This file is part of the app "rounds".
 *
 * rounds is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * rounds is distributed in the hope that it will be useful,
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
    id: confirmMsgDel

    property int msgArrayIndex
    property string msgText

    Component.onCompleted: {
        // TODO: andere Methode aufrufen
        msgText = DeltaHandler.chatmodel.getMessageSummarytext(msgArrayIndex)
    }

    title: i18n.tr("Delete Message")

    Label {
        id: confirmLabel1
        text: i18n.tr('Are you sure you want to delete \"%1\"?').arg(msgText)
        wrapMode: Text.Wrap
    }

    Button {
        id: okButton
        text: i18n.tr("Delete Message")
        color: theme.palette.normal.negative
        onClicked: {
            DeltaHandler.chatmodel.deleteMessage(msgArrayIndex)
            PopupUtils.close(confirmMsgDel)
        }
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(confirmMsgDel)
        }
    }
}
