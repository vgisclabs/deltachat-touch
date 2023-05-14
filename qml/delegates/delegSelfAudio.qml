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
import QtMultimedia 5.12

import DeltaHandler 1.0

UbuntuShape {
    id: msgbox
    height: units.gu(1) + (forwardLabel.visible ? forwardLabel.contentHeight + units.gu(0.5) : 0) + (quoteLabel.visible ? quoteLabel.contentHeight + quoteUser.contentHeight + units.gu(1) : 0) + playShape.height + (msgLabel.visible ? units.gu(1) + msgLabel.contentHeight : 0) + units.gu(0.5) + msgDate.contentHeight + units.gu(0.5)
    width: {
        let a = (padlock.visible ? padlock.width + units.gu(0.5) : 0) + msgDate.contentWidth  + statusIcon.width
        let b = msgLabel.contentWidth
        let c = playShape.width + units.gu(1) + playLabel.contentWidth
        let d = quoteLabel.visible ? ((quoteUser.contentWidth > quoteLabel.contentWidth ? quoteUser.contentWidth : quoteLabel.contentWidth ) + units.gu(1) + quoteRectangle.width) : 0
        let e = forwardLabel.visible ? forwardLabel.contentWidth : 0
        
        let x = a > b ? a : b
        let y = (c > d ? c : d) > e ? (c > d ? c : d) : e

        return units.gu(1) + (x > y ? x : y) + units.gu(1)
    }
    anchors {
        right: parent.right
        rightMargin: units.gu(1)
        bottom: parent.bottom
    }
    backgroundColor: {
        switch (model.messageState) {
            case DeltaHandler.StatePending:
                return root.selfMessagePendingBackgroundColor;
                break;
            case DeltaHandler.StateDelivered:
                return root.selfMessageSentBackgroundColor;
                break;
            case DeltaHandler.StateReceived:
                return root.selfMessageSeenBackgroundColor;
                break;
            // TODO: different layout for failed messages?
            case DeltaHandler.StateFailed:
                return root.selfMessagePendingBackgroundColor;
                break;
        }
    }
    backgroundMode: UbuntuShape.SolidColor
    aspect: UbuntuShape.Flat
    radius: "medium"

    // idea taken from fluffychat
    Rectangle {
        id: squareCorner
        height: units.gu(2)
        width: units.gu(2)
        anchors {
            right: msgbox.right
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
        font.bold: true
        color: msgLabel.color
        visible: model.isForwarded
    }

    Rectangle {
        id: quoteRectangle
        width: units.gu(0.5)
        height: quoteUser.contentHeight + quoteLabel.contentHeight
        anchors {
            left: msgbox.left
            leftMargin: units.gu(1)
            top: forwardLabel.visible ? forwardLabel.bottom : msgbox.top
            topMargin: forwardLabel.visible ? units.gu(0.5) : units.gu(1)
        }
        color: msgLabel.color
        visible: quoteLabel.visible
    }

    Label {
        id: quoteLabel
        width: parentWidth - units.gu(5) - units.gu(1.5)
        anchors {
            left: quoteRectangle.right
            leftMargin: units.gu(1)
            top: quoteRectangle.top
        }
        text: model.quotedText
        wrapMode: Text.Wrap
        color: msgLabel.color
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

        fontSize: "x-small"
        font.bold: true
        color: msgLabel.color
        visible: quoteLabel.visible
    }

    UbuntuShape {
        id: playShape
        height: units.gu(4)
        width: height
        anchors {
            left: msgbox.left
            leftMargin: units.gu(1)
            top: quoteLabel.visible ? quoteUser.bottom : (forwardLabel.visible ? forwardLabel.bottom : msgbox.top)
            topMargin: quoteLabel.visible ? units.gu(1) : (forwardLabel.visible ? units.gu(0.5) : units.gu(1))
        }
        backgroundColor: "#F7F7F7"
        opacity: 0.5

        Icon {
            width: parent.width - units.gu(1)
            anchors.centerIn: parent
            name: "media-playback-start"
            //color: root.darkmode ? "white" : "black"
            color: msgLabel.color
            //opacity: 0.5
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (messageAudio.playbackState === Audio.PlayingState || messageAudio.playbackState === Audio.PausedState) {
                    msgAudio.stop()
                }
                msgAudio.source = Qt.resolvedUrl(StandardPaths.locate(StandardPaths.CacheLocation, model.audiofilepath))
                msgAudio.play()
            }
        }

    }

    Label {
        id: playLabel
        anchors {
            left: playShape.right
            leftMargin: units.gu(1)
            verticalCenter: playShape.verticalCenter
        }
        text: (model.msgViewType === DeltaHandler.AudioType ? i18n.tr("Audio") : i18n.tr("Voice Message")) + " " + model.duration
        color: msgLabel.color
    }

    Label {
        id: msgLabel
        width: parentWidth - units.gu(5)
        anchors {
            left: msgbox.left
            leftMargin: units.gu(1)
            top: playShape.bottom
            topMargin: units.gu(0.5)
        }
        visible: model.text != ""
        text: model.text
        color: model.messageSeen ? root.selfMessageSeenTextColor : root.selfMessageSentTextColor
        wrapMode: Text.Wrap
    }

    Icon {
        id: padlock
        height: msgDate.contentHeight * 0.9
        anchors {
            right: msgDate.left
            rightMargin: units.gu(0.5)
            bottom: msgDate.bottom
        }
        visible: model.hasPadlock
        name: "lock"
        color: msgLabel.color
        
    }

    Label {
        id: msgDate
        anchors {
            right: statusIcon.left
            bottom: parent.bottom
            bottomMargin: units.gu(0.5)
        }
        //textSize: Label.Small
        text: model.date
        fontSize: "x-small"
        color: msgLabel.color
    }

    Icon {
        id: statusIcon
        height: msgDate.contentHeight * 0.8
        width: height * 2
        anchors {
            right: parent.right
            rightMargin: units.gu(1)
            bottom: msgDate.bottom
        }
        source: //model.messageSeen ? (root.darkmode ? Qt.resolvedUrl('../../assets/read_white.svg') : Qt.resolvedUrl('../../assets/read_black.svg')) : Qt.resolvedUrl('../../assets/sent_black.svg')
            switch (model.messageState) {
                case DeltaHandler.StatePending:
                    return Qt.resolvedUrl('../../assets/dotted_circle_black.svg');
                    break;
                case DeltaHandler.StateDelivered:
                    return Qt.resolvedUrl('../../assets/sent_black.svg');
                    break;
                case DeltaHandler.StateReceived:
                    if (root.darkmode) {
                        return Qt.resolvedUrl('../../assets/read_white.svg');
                        break;
                    } else {
                        return Qt.resolvedUrl('../../assets/read_black.svg');
                        break;
                    }
                case DeltaHandler.StateFailed:
                    return Qt.resolvedUrl('../../assets/circled_x_red.svg');
                    break;
            }
    }
} // end UbuntuShape id: msgbox
