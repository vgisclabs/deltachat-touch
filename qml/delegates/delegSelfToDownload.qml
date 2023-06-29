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
import Lomiri.Components 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0

import DeltaHandler 1.0

LomiriShape {
    id: msgbox
    height: units.gu(1) + msgLabel.contentHeight + units.gu(0.5) + msgDate.contentHeight + units.gu(0.5)
    width: {
        let a = msgDate.contentWidth  + statusIcon.width
        let b = msgLabel.contentWidth
    
        return units.gu(1) + (a > b ? a : b) + units.gu(1)
    
    }

    anchors {
        right: parent.right
        rightMargin: units.gu(1)
        top: parent.top
    }

    property string stateText: ""

    Component.onCompleted: {
        let downState = model.downloadState
        if (downState === DeltaHandler.DownloadAvailable) {
            stateText = " - <a href=\"%1\">%1</a>".arg(i18n.tr("Download"))
            msgLabel.linkColor = root.darkmode ? (model.messageSeen ? "#bbbbf7" : "#0000aa") : "#0000ff"
        } else if (downState === DeltaHandler.DownloadFailure) {
            stateText = " - <a href=\"%1\">%1</a>".arg(i18n.tr("Download failed"))
            msgLabel.linkColor = root.darkmode ? (model.messageSeen ? "#f78080" : "#aa0000") : "#ff0000"
        } else if (downState === DeltaHandler.DownloadInProgress) {
            stateText = " - " + i18n.tr("Downloading…")
            msgLabel.linkColor = root.darkmode ? (model.messageSeen ? "#bbbbf7" : "#0000aa") : "#0000ff"
        } else {
            stateText = "?"
            msgLabel.linkColor = root.darkmode ? (model.messageSeen ? "#bbbbf7" : "#0000aa") : "#0000ff"
        }
    }

    backgroundColor: {
        if (model.isSearchResult) {
            return root.searchResultMessageColor
        } else {
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
    }
    backgroundMode: LomiriShape.SolidColor
    aspect: LomiriShape.Flat
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
        id: msgLabel
        width: parentWidth - units.gu(5)
        anchors {
            left: msgbox.left
            leftMargin: units.gu(1)
            top: msgbox.top
            topMargin: units.gu(1)
        }
        text: model.summarytext + msgbox.stateText
        onLinkActivated: {
            DeltaHandler.chatmodel.downloadFullMessage(index)
            msgbox.stateText = " - " + i18n.tr("Downloading…")
            msgLabel.linkColor = root.darkmode ? (model.messageSeen ? "#8080f7" : "#000055") : "#0000ff"
        }
        // TODO: solve with model.messageState instead of model.message.seen?
        color: model.isSearchResult ? "black" : model.messageSeen ? root.selfMessageSeenTextColor : root.selfMessageSentTextColor
        wrapMode: Text.Wrap
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
                    if (root.darkmode && !model.isSearchResult) {
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
} // end LomiriShape id: msgbox
