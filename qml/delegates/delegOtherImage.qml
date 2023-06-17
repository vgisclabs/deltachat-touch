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
 * * You should have received a copy of the GNU General Public License
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
    height: msgbox.height
    width: parent.width
    anchors {
        left: parent.left
        top: parent.top
    }

    property bool topRightRectVisible: msgImage.paintedWidth > dateEtcShape.width

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

    Item {
        id: msgbox
        height: msgImage.paintedHeight + dateEtcShape.height
        width: (msgImage.paintedWidth > dateEtcShape ? msgImage.paintedWidth : dateEtcShape.width) + units.gu(2)
        anchors {
            left: avatarShape.right
            leftMargin: units.gu(1)
            top: parent.top
        }
        // no background for the msgbox in case of images

        UbuntuShape {
            id: dateEtcShape
            width: {
                let a = msgLabel.contentWidth
                let b = username.contentWidth + msgDate.contentWidth + (padlock.visible ? padlock.width : 0)
                let c = quoteLabel.visible ? ((quoteUser.contentWidth > quoteLabel.contentWidth ? quoteUser.contentWidth : quoteLabel.contentWidth ) + units.gu(1) + quoteRectangle.width) : 0
                let d = forwardLabel.visible ? forwardLabel.contentWidth : 0

                let x = a > b ? a : b
                let y = c > d ? c : d
           
                return units.gu(1) + (x > y ? x : y) + units.gu(1)
            }
            height: units.gu(0.5) + (forwardLabel.visible ? forwardLabel.contentHeight + units.gu(0.5) : 0) + (quoteLabel.visible ? quoteLabel.contentHeight + quoteUser.contentHeight + units.gu(1) : 0) + msgDate.height + units.gu(0.5) + (msgLabel.visible ? msgLabel.contentHeight + units.gu(1) : 0)

            anchors {
                left: parent.left
                bottom: parent.bottom
            }

            backgroundMode: UbuntuShape.SolidColor
            backgroundColor: model.isSearchResult ? root.searchResultMessageColor : root.otherMessageBackgroundColor
            aspect: UbuntuShape.Flat

            // If it's only the image, the radius has to be smaller as
            // the shape is only framing the small line with sender,
            // date and padlock
            radius: msgLabel.visible ? "medium" : "small"

            Rectangle {
                id: squareCornerBL
                height: units.gu(2)
                width: units.gu(2)
                anchors {
                    left: dateEtcShape.left
                    bottom: dateEtcShape.bottom
                }
                color: dateEtcShape.backgroundColor
                opacity: dateEtcShape.opacity
                visible: !model.isSameSenderAsNextMsg
            }

            Rectangle {
                id: squareCornerTL
                height: units.gu(2)
                width: units.gu(2)
                anchors {
                    left: dateEtcShape.left
                    top: dateEtcShape.top
                }
                color: dateEtcShape.backgroundColor
                opacity: dateEtcShape.opacity
            }

            Rectangle {
                id: squareCornerTR
                height: units.gu(2)
                width: units.gu(2)
                anchors {
                    top: dateEtcShape.top
                    right: dateEtcShape.right
                }
                color: dateEtcShape.backgroundColor
                opacity: dateEtcShape.opacity
                visible: topRightRectVisible 
            }

            Label {
                id: forwardLabel
                anchors {
                    left: parent.left
                    leftMargin: units.gu(1)
                    top: dateEtcShape.top
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
                    top: forwardLabel.visible ? forwardLabel.bottom : dateEtcShape.top
                    topMargin: forwardLabel.visible ? units.gu(0.5) : units.gu(1)
                }
                color: root.darkmode ? "white" : "black"
                visible: quoteLabel.visible
            }

            Label {
                id: quoteLabel
                width: parentWidth - avatarShape.width - units.gu(5) - units.gu(1.5)
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
                    left: dateEtcShape.left
                    leftMargin: units.gu(1)
                    top: quoteLabel.visible ? quoteUser.bottom : (forwardLabel.visible ? forwardLabel.bottom : dateEtcShape.top)
                    topMargin: quoteLabel.visible ? units.gu(1) : (forwardLabel.visible ? units.gu(0.5) : units.gu(1))
                }
                visible: model.text != ""
                color: model.isSearchResult ? "black" : theme.palette.normal.foregroundText
                text: model.text
                // TODO: 'QML Label: Binding loop detected for property "width"'
                //width: contentWidth > parentWidth - units.gu(2) ? parentWidth - units.gu(2) : contentWidth
                wrapMode: Text.Wrap
                onLinkActivated: Qt.openUrlExternally(link)
            }

            Label {
                id: username
                anchors {
                    left: parent.left
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
                    //leftMargin: units.gu(0.5)
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
        } // end UbuntuShape id: dateEtcShape

        Image {
            id: msgImage
            anchors {
                left: parent.left
                top: msgbox.top
            }
            source: StandardPaths.locate(StandardPaths.AppConfigLocation, model.filepath)
            width: model.imagewidth > parentWidth - avatarShape.width - units.gu(5) ? parentWidth - avatarShape.width - units.gu(5) : model.imagewidth
            fillMode: Image.PreserveAspectFit

            MouseArea {
                anchors.fill: parent
                onClicked: layout.addPageToCurrentColumn(chatPage, Qt.resolvedUrl("../pages/ImageViewer.qml"), { "imageSource": msgImage.source })
            }
        }

    } // end Item id: msgbox
} // end Item
