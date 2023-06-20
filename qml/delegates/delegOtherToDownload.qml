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

    property string stateText: ""

    Component.onCompleted: {
        let downState = model.downloadState
        if (downState === DeltaHandler.DownloadAvailable) {
            stateText = " - <a href=\"%1\">%1</a>".arg(i18n.tr("Download"))
            msgLabel.linkColor = root.darkmode ? "#aaaaf7" : "#0000ff"
        } else if (downState === DeltaHandler.DownloadFailure) {
            stateText = " - <a href=\"%1\">%1</a>".arg(i18n.tr("Download failed"))
            msgLabel.linkColor = root.darkmode ? "#f7aaaa" : "#ff0000"
        } else if (downState === DeltaHandler.DownloadInProgress) {
            stateText = i18n.tr(" - Downloading…")
            msgLabel.linkColor = root.darkmode ? "#aaaaff" : "#0000ff"
        } else {
            stateText = "?"
            msgLabel.linkColor = root.darkmode ? "#aaaaff" : "#0000ff"
        }
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

        MouseArea {
            anchors.fill: parent
            onClicked: layout.addPageToCurrentColumn(chatPage, Qt.resolvedUrl("../pages/ProfileOther.qml"), { "contactID": model.contactID })
        }
        
        color: model.avatarColor

        sourceFillMode: UbuntuShape.PreserveAspectCrop
    }

    UbuntuShape {
        id: msgbox
        width: {
            let a = msgLabel.contentWidth
            let b = username.contentWidth + msgDate.contentWidth

            return units.gu(1) + (a > b ? a : b) + units.gu(1)
        }
        height: units.gu(1) + msgLabel.contentHeight + units.gu(0.5) + msgDate.contentHeight + units.gu(0.5)
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
            id: msgLabel
            width: parentWidth - avatarShape.width - units.gu(5)
            anchors {
                left: parent.left
                leftMargin: units.gu(1)
                top: msgbox.top
                topMargin: units.gu(1)
            }
            text: model.summarytext + delegItem.stateText
            color: model.isSearchResult ? "black" : theme.palette.normal.foregroundText
            onLinkActivated: {
                DeltaHandler.chatmodel.downloadFullMessage(index)
                delegItem.stateText = i18n.tr(" - Downloading…")
                msgLabel.linkColor = root.darkmode ? "#8080f7" : "#0000ff"
            }
            wrapMode: Text.Wrap
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
    } // end UbuntuShape id: msgbox
}
