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
import Lomiri.Components 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
//import Qt.labs.settings 1.0
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: forwardMessagePage
    anchors.fill: parent

    signal textHasChanged(string query)

    Component.onCompleted: {
        forwardMessagePage.textHasChanged.connect(DeltaHandler.chatmodel.chatlistmodel.updateQuery)
    }

    header: PageHeader {
        id: header

        title: i18n.tr("Forward to…")

        // disable the "back" icon
        leadingActionBar.actions: undefined

        trailingActionBar.actions: [
            Action {
                iconName: 'close'
                text: i18n.tr('Close')
                onTriggered: {
                    layout.removePages(forwardMessagePage)
                    DeltaHandler.chatmodel.forwardingFinished()
                }
            }
        ]
    } //PageHeader id:header


    TextField {
        id: searchField
        width: parent.width < units.gu(45) ? parent.width - units.gu(8) : units.gu(37)
        anchors {
            left: parent.left
            leftMargin: units.gu(2)
            top: header.bottom
            topMargin: units.gu(1)
        }
        onDisplayTextChanged: {
            forwardMessagePage.textHasChanged(displayText)
        }
        placeholderText: i18n.tr("Search")
    }


    Component {
        id: delegateListItem

        ListItem {
            id: chatListItem
            // shall specify the height when Using ListItemLayout inside ListItem
            height: chatlistLayout.height //+ (divider.visible ? divider.height : 0)
            divider.visible: true
            onClicked: {
                let chatID = DeltaHandler.chatmodel.chatlistmodel.getChatID(index)
                DeltaHandler.chatmodel.forwardMessage(chatID)
                layout.removePages(forwardMessagePage)
                DeltaHandler.chatmodel.forwardingFinished()
            }


            ListItemLayout {
                id: chatlistLayout
                title.text: model.chatname
                title.font.bold: true
                subtitle.text: model.msgPreview

                LomiriShape {
                    id: chatPicShape
                    SlotsLayout.position: SlotsLayout.Leading
                    height: units.gu(6)
                    width: height
                    
                    source: model.chatPic == "" ? undefined : chatPicImage
                    Image {
                        id: chatPicImage
                        visible: false
                        source: StandardPaths.locate(StandardPaths.AppConfigLocation, model.chatPic)
                    }

                    Label {
                        id: avatarInitialLabel
                        visible: model.chatPic == ""
                        text: model.avatarInitial
                        fontSize: "x-large"
                        color: "white"
                        anchors.centerIn: parent
                    }

                    color: model.avatarColor

                    sourceFillMode: LomiriShape.PreserveAspectCrop
                }

                Rectangle {
                    id: dateAndMsgCount
                    SlotsLayout.position: SlotsLayout.Trailing
                    width: timestamp.contentWidth + units.gu(1)
                    height: units.gu(6)
                    color: chatListItem.color 

                    Label {
                        id: timestamp
                        text: model.timestamp
                        anchors {
                            right: dateAndMsgCount.right
                            top: dateAndMsgCount.top
                            topMargin: units.gu(0.2)
                        }
                        fontSize: "small"
                    }

                } // Rectangle id: dateAndMsgCount
            } // end ListItemLayout id: chatlistLayout
        } // end ListItem id: chatListItem
    } // end Compoment id: delegateListItem

    ListView {
        id: view
        clip: true
        anchors {
            top: searchField.bottom
            topMargin: units.gu(1)
        }
        width: parent.width
        height: chatlistPage.height - header.height
        model: DeltaHandler.chatmodel.chatlistmodel
        delegate: delegateListItem
    }
} // end of Page id: forwardMessagePage
