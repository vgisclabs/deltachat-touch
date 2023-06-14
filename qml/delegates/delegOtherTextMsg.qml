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
//import QtQuick 2.7
import Ubuntu.Components 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Item {
    id: delegItem
    height: msgbox.height
    width: parentWidth
    anchors {
        left: parent.left
        top: parent.top
    }

    UbuntuShape {
        id: avatarShape
        height: model.isSameSenderAsNextMsg ? 0 : width
        width: units.gu(5.5)
        anchors {
            left: parent.left
            leftMargin: units.gu(1)
            bottom: parent.bottom
        }

        source: model.profilePic == "" ? undefined : avatarPic
            Image {
                id: avatarPic
                visible: false
                source: StandardPaths.locate(StandardPaths.AppConfigLocation, model.profilePic)
            }

        Label {
            id: avatarInitialLabel
            text: model.avatarInitial
            fontSize: "x-large"
            color: "white"
            visible: !model.isSameSenderAsNextMsg && model.profilePic == ""
            anchors.centerIn: parent
        }
        
        color: model.avatarColor

        sourceFillMode: UbuntuShape.PreserveAspectCrop
    }

    UbuntuShape {
        id: msgbox
        width: {
            let a = msgLabel.contentWidth
            let b = quoteLabel.visible ? ((quoteUser.contentWidth > quoteLabel.contentWidth ? quoteUser.contentWidth : quoteLabel.contentWidth ) + units.gu(1) + quoteRectangle.width) : 0
            let c = username.contentWidth + msgDate.contentWidth + (padlock.visible ? padlock.width : 0)
            let d = forwardLabel.visible ? forwardLabel.contentWidth : 0

            let x = a > b ? a : b
            let y = c > d ? c : d
           
            return units.gu(1) + (x > y ? x : y) + units.gu(1)
        }
        height: units.gu(1) + (forwardLabel.visible ? forwardLabel.contentHeight + units.gu(0.5) : 0) +  (quoteLabel.visible ? quoteLabel.contentHeight + quoteUser.contentHeight + units.gu(1) : 0) + msgLabel.contentHeight + units.gu(0.5) + msgDate.contentHeight + units.gu(0.5)
        anchors {
            left: avatarShape.right
            leftMargin: units.gu(1)
            top: parent.top
        }
        backgroundColor: model.isSearchResult ? root.searchResultMessageColor : root.otherMessageBackgroundColor
        backgroundMode: UbuntuShape.SolidColor
        aspect: UbuntuShape.Flat
        radius: "medium"

        // TODO idea taken from fluffychat
        Rectangle {
            id: squareCorner
            width: units.gu(2)
            height: units.gu(2)
            anchors {
                left: msgbox.left
                bottom: msgbox.bottom
            }
            color: msgbox.backgroundColor
            opacity: msgbox.opacity
            visible: !model.isSameSenderAsNextMsg
        }

        Label {
            id: forwardLabel
            anchors {
                left: parent.left
                leftMargin: units.gu(1)
                top: msgbox.top
                topMargin: units.gu(1)
            }
            text: i18n.tr("Forwarded Message")
            color: msgLabel.color
            font.bold: true
            visible: model.isForwarded
        }

        Rectangle {
            id: quoteRectangle
            width: units.gu(0.5)
            height: quoteUser.contentHeight + quoteLabel.contentHeight
            anchors {
                left: parent.left
                leftMargin: units.gu(1)
                top: forwardLabel.visible ? forwardLabel.bottom : msgbox.top
                topMargin: forwardLabel.visible ? units.gu(0.5) : units.gu(1)
            }
            color: root.darkmode ? "white" : "black"
            visible: quoteLabel.visible
        }

        Label {
            id: quoteLabel
            width: parentWidth - (avatarShape.width + units.gu(5) + units.gu(1.5))
            anchors {
                left: quoteRectangle.right
                leftMargin: units.gu(1)
                top: quoteRectangle.top
            }
            text: model.quotedText
            color: msgLabel.color
            wrapMode: Text.Wrap
            visible: text != ""

            MouseArea {
                id: msgJumpArea
                anchors.fill: parent
                onClicked: {
                    DeltaHandler.chatmodel.initiateQuotedMsgJump(index)
                }
            }
        }

        Label {
            id: quoteUser
            anchors {
                left: quoteRectangle.right
                leftMargin: units.gu(1)
                top: quoteLabel.bottom
            }

            text: {
                if (model.quoteUser == "") {
                    return i18n.tr("Unknown")
                } else {
                    return model.quoteUser
                }
            }
            
            color: msgLabel.color
            fontSize: "x-small"
            font.bold: true
            visible: quoteLabel.visible
        }

        Label {
            id: msgLabel
            width: parentWidth - avatarShape.width - units.gu(5)
            anchors {
                left: parent.left
                leftMargin: units.gu(1)
                top: quoteLabel.visible ? quoteUser.bottom : (forwardLabel.visible ? forwardLabel.bottom : msgbox.top)
                topMargin: quoteLabel.visible ? units.gu(1) : (forwardLabel.visible ? units.gu(0.5) : units.gu(1))
            }
            text: model.text
            color: model.isSearchResult ? "black" : theme.palette.normal.foregroundText
            wrapMode: Text.Wrap
            onLinkActivated: Qt.openUrlExternally(link)
        }

        Label {
            id: username
            anchors {
                left: msgbox.left
                leftMargin: units.gu(1)
                bottom: parent.bottom
                bottomMargin: units.gu(0.5)
            }
            text: model.username + "  "
            fontSize: "x-small"
            font.bold: true
            color: model.avatarColor
        }

        Label {
            id: msgDate
            anchors {
                left: username.right
                bottom: username.bottom
            }
            //textSize: Label.Small
            color: msgLabel.color
            fontSize: "x-small"
            text: model.date
        }

        Icon {
            id: padlock
            height: msgDate.contentHeight
            anchors {
                left: msgDate.right
                bottom: username.bottom
            }
            visible: model.hasPadlock
            name: "lock"
            color: msgDate.color
            
        }
    } // end UbuntuShape id: msgbox
}
