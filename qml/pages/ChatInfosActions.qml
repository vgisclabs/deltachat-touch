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

import QtQuick 2.12
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: dialog

    property int chatIndex

    property bool isGroup: DeltaHandler.chatIsGroup(chatIndex)
    property bool isDeviceTalk: DeltaHandler.chatIsDeviceTalk(chatIndex)
    property bool isSelfTalk: DeltaHandler.chatIsSelfTalk(chatIndex)
    property bool selfInGroup: false

    Component.onCompleted: {
        if (isGroup) {
            selfInGroup = DeltaHandler.selfIsInGroup(chatIndex)
        }
    }
    
    Connections {
        target: DeltaHandler
        onChatBlockContactDone: {
            PopupUtils.close(dialog)
        }
    }

    Button {
        id: blockContactButton
        text: i18n.tr("Block Contact")
        onClicked: {
            PopupUtils.open(
                Qt.resolvedUrl("BlockContactPopup.qml"),
                null,
                { indexToBlock: chatIndex }
            )
        }
        visible: !isGroup && !(isDeviceTalk || isSelfTalk)
    }

    Button {
        id: editGroupButton
        text: i18n.tr("Edit Group")
        onClicked: {
            DeltaHandler.startEditGroup(chatIndex)
            layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl("CreateOrEditGroup.qml"), { "createNewGroup": false })
            PopupUtils.close(dialog)
        }
        visible: isGroup
        enabled: selfInGroup
    }

    Button {
        id: leaveGroupButton
        text: i18n.tr("Leave Group")
        onClicked: {
            PopupUtils.open(
                Qt.resolvedUrl("ConfirmLeaveGroup.qml"),
                null,
                { indexToLeave: chatIndex }
            )
        }
        visible: isGroup
        enabled: selfInGroup
    }

    Button {
        id: showEncryptionInfoButton
        text: i18n.tr("Show Encryption Info")
        onClicked: {
            let tempString = DeltaHandler.getChatEncInfo(chatIndex)
            PopupUtils.open(
                Qt.resolvedUrl("InfoPopup.qml"),
                null,
                { text: tempString }
            )
        }
        visible: !isDeviceTalk && !isSelfTalk
    }

    Button {
        text: 'OK'
        color: theme.palette.normal.focus
        onClicked: {
            PopupUtils.close(dialog)
        }
    }
}
