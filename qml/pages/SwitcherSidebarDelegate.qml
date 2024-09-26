/*
 * Copyright (C) 2024  Lothar Ketterer
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
import Qt.labs.platform 1.1
import Lomiri.Components.Popups 1.3

import DeltaHandler 1.0

Rectangle {
    id: switcherDelegRect

    property int switcherMsgCount: model.freshMsgCount + (root.notifyContactRequests ? model.chatRequestCount : 0)
    property bool mouseHovers: hoverMouse.containsMouse

    //color: (model.isCurrentActiveAccount) ? theme.palette.highlighted.focus : (model.isConfigured && mouseHovers ? theme.palette.focused.background : "transparent")
    color: (model.isCurrentActiveAccount) ? root.selfMessageSeenBackgroundColor : (model.isConfigured && mouseHovers ? root.selfMessageSentBackgroundColor : "transparent")

    LomiriShape {
        id: switcherProfilePic
        height: parent.height - units.gu(2)
        width: height
        anchors.centerIn: parent

        color: model.color

        source: (model.profilePic !== "" || !(model.isConfigured)) ? switcherImage : undefined
        
        Image {
            id: switcherImage
            anchors.fill: parent
            source: model.profilePic == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, model.profilePic)
            visible: false
        }


        Label {
            id: avatarInitialLabel
            visible: !(model.profilePic !== "" || !(model.isConfigured))
            text: model.username === "" ? "#" : model.username.charAt(0).toUpperCase()
            font.pixelSize: parent.height * 0.6
            color: "white"
            anchors.centerIn: parent
        }

        sourceFillMode: LomiriShape.PreserveAspectCrop
        aspect: LomiriShape.Flat
    }


    Label {
        id: switcherConfigStatusLabel
        text: '!'
        font.bold: true
        color: theme.palette.normal.negative 
        anchors {
            top: parent.top
            right: parent.right
            rightMargin: units.gu(0.25)
        }
        //textSize: Label.XLarge
        font.pixelSize: parent.height / 2
        visible: !model.isConfigured
    }


    Icon {
        id: switcherMutedIcon
        height: parent.height / 3
        width: height
        color: "black"
        anchors {
            left: parent.left
            leftMargin: units.gu(1.5)
            top: parent.top
            topMargin: units.gu(1.5)
        }
        //name: "audio-speakers-muted-symbolic"
        source: "qrc:///assets/suru-icons/audio-speakers-muted-symbolic.svg"
        visible: model.isMuted
    }

    LomiriShape {
        id: switcherNewMsgCounter

        height: switcherProfilePic.height * (2/5)
        width: height
        anchors {
            left: switcherProfilePic.left
            leftMargin: switcherProfilePic.width - (width * 0.75)
            top: switcherProfilePic.top
            topMargin: switcherProfilePic.height - (height - units.gu(0.5))
        }
        color: model.isMuted ? (root.darkmode ? "#c0c0c0" : "#505050") : root.unreadMessageCounterColor
        visible: model.isConfigured && switcherMsgCount > 0

        Label {
            anchors{
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            color: model.isMuted ? "black" : "white"
            font.bold: true
            fontSize: root.scaledFontSizeSmaller
            text: switcherMsgCount > 99 ? "…" : switcherMsgCount
        }
    }

    MouseArea {
        id: hoverMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (model.isConfigured) {
                let accID = DeltaHandler.accountsmodel.getIdOfAccount(index)
                DeltaHandler.selectAccount(accID)
            } else {
                PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"),
                switcherDelegRect,
                { "title": i18n.tr("Error"), "text": i18n.tr("Account is not configured.") })      
            }
        }
    }
}
