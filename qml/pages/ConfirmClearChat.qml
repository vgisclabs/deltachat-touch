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
    id: confirmMsgDel

    signal finished()

    property string chatName

    Component.onCompleted: {
        chatName = DeltaHandler.getMomentaryChatName()
        let numberOfMsgs = DeltaHandler.chatmodel.getMessageCount()
        if (1 == numberOfMsgs) {
            confirmLabel1.text = i18n.tr("Delete %1 message here and on the server?").arg(numberOfMsgs)
        } else {
            confirmLabel1.text = i18n.tr("Delete %1 messages here and on the server?").arg(numberOfMsgs)
        }
    }

    title: i18n.tr("Clear Chat")

    Label {
        id: confirmLabel1
        wrapMode: Text.Wrap
    }

    Button {
        id: okButton
        text: i18n.tr("Clear Chat")
        color: theme.palette.normal.negative
        onClicked: {
            DeltaHandler.chatmodel.deleteAllMessagesInCurrentChat()
            PopupUtils.close(confirmMsgDel)
            finished()
        }
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(confirmMsgDel)
            finished()
        }
    }
}
