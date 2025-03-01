/*
 * Copyright (C) 2023, 2024 Lothar Ketterer
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
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: dialog

    property bool isGroup: DeltaHandler.momentaryChatIsGroup()
    property bool isDeviceTalk: DeltaHandler.momentaryChatIsDeviceTalk()
    property bool isSelfTalk: DeltaHandler.momentaryChatIsSelfTalk()
    property bool selfInGroup: false
    property bool isMuted: DeltaHandler.momentaryChatIsMuted()

    Component.onCompleted: {
        if (isGroup) {
            selfInGroup = DeltaHandler.momentaryChatSelfIsInGroup()
        }
    }
    
    Connections {
        target: DeltaHandler
        onChatBlockContactDone: {
            PopupUtils.close(dialog)
        }
    }

    Button {
        id: muteButton
        text: isMuted ? i18n.tr("Unmute") : i18n.tr("Mute Notifications")
        onClicked: {
            if (isMuted) {
                DeltaHandler.momentaryChatSetMuteDuration(0)
                PopupUtils.close(dialog)
            } else {
                PopupUtils.open(popoverComponentMuteDuration, muteButton)
            }
        }
        visible: !isDeviceTalk && !isSelfTalk
    }

    Button {
        id: blockContactButton
        text: i18n.tr("Block Contact")
        onClicked: {
            let popup6 = PopupUtils.open(
                Qt.resolvedUrl('ConfirmDialog.qml'),
                dialog,
                { "dialogTitle": DeltaHandler.getMomentaryChatName(),
                  "dialogText": i18n.tr("Block this contact? You will no longer receive messages from them."),
                  "okButtonText": i18n.tr("Block Contact"),
            })
            popup6.confirmed.connect(function() {
                DeltaHandler.momentaryChatBlockContact()
                PopupUtils.close(dialog)
            })
        }
        visible: !isGroup && !(isDeviceTalk || isSelfTalk)
    }

    Button {
        id: editGroupButton
        text: i18n.tr("Edit Group")
        onClicked: {
            DeltaHandler.momentaryChatStartEditGroup()
            extraStack.push(Qt.resolvedUrl("CreateOrEditGroup.qml"), { "createNewGroup": false, "selfIsInGroup": DeltaHandler.momentaryChatSelfIsInGroup() })
            PopupUtils.close(dialog)
        }
        visible: isGroup
        enabled: selfInGroup
    }

    Button {
        id: leaveGroupButton
        text: i18n.tr("Leave Group")
        onClicked: {
            let popup1 = PopupUtils.open(
                Qt.resolvedUrl('ConfirmDialog.qml'),
                dialog,
                { "dialogTitle": DeltaHandler.getMomentaryChatName(),
                  "dialogText": i18n.tr("Are you sure you want to leave this group?"),
                  "okButtonText": i18n.tr("Leave Group"),
            })
            popup1.confirmed.connect(function() {
                DeltaHandler.momentaryChatLeaveGroup()
                PopupUtils.close(dialog)
            })
        }
        visible: isGroup
        enabled: selfInGroup
    }

    Button {
        id: showEncryptionInfoButton
        text: i18n.tr("Encryption Info")
        onClicked: {
            let tempString = DeltaHandler.getMomentaryChatEncInfo()
            let popup2 = PopupUtils.open(
                Qt.resolvedUrl("InfoPopup.qml"),
                null,
                { text: tempString }
            )
            popup2.done.connect(function() {
                PopupUtils.close(dialog)
            })
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

    Component {
        id: popoverComponentMuteDuration
        Popover {
            id: popoverMuteDuration
            Column {
                id: containerLayoutMuteDuration
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                }
                ListItem {
                    height: layout81.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout81
                        title.text: i18n.tr("Off")
                    }
                    onClicked: {
                        DeltaHandler.momentaryChatSetMuteDuration(0)
                        PopupUtils.close(popoverMuteDuration)
                        PopupUtils.close(dialog)
                    }
                }

                ListItem {
                    height: layout82.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout82
                        title.text: i18n.tr("Mute for 1 hour")
                    }
                    onClicked: {
                        DeltaHandler.momentaryChatSetMuteDuration(3600)
                        PopupUtils.close(popoverMuteDuration)
                        PopupUtils.close(dialog)
                    }
                }

                ListItem {
                    height: layout83.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout83
                        title.text: i18n.tr("Mute for 2 hours")
                    }
                    onClicked: {
                        DeltaHandler.momentaryChatSetMuteDuration(7200)
                        PopupUtils.close(popoverMuteDuration)
                        PopupUtils.close(dialog)
                    }
                }

                ListItem {
                    height: layout84.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout84
                        title.text: i18n.tr("Mute for 1 day")
                    }
                    onClicked: {
                        DeltaHandler.momentaryChatSetMuteDuration(86400)
                        PopupUtils.close(popoverMuteDuration)
                        PopupUtils.close(dialog)
                    }
                }

                ListItem {
                    height: layout85.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout85
                        title.text: i18n.tr("Mute for 7 days")
                    }
                    onClicked: {
                        DeltaHandler.momentaryChatSetMuteDuration(604800)
                        PopupUtils.close(popoverMuteDuration)
                        PopupUtils.close(dialog)
                    }
                }

                ListItem {
                    height: layout86.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout86
                        title.text: i18n.tr("Mute forever")
                    }
                    onClicked: {
                        DeltaHandler.momentaryChatSetMuteDuration(-1)
                        PopupUtils.close(popoverMuteDuration)
                        PopupUtils.close(dialog)
                    }
                }
            } // end Column id: containerLayoutMuteDuration
        } // end Popover id: popoverMuteDuration
    } // end Component id: popoverComponentMuteDuration
}
