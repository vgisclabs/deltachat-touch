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

Item {
    height: msgbox.height
    width: parent.width
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

        MouseArea {
            anchors.fill: parent
            onClicked: layout.addPageToCurrentColumn(chatPage, Qt.resolvedUrl("../pages/ProfileOther.qml"), { "contactID": model.contactID })
        }

        color: model.avatarColor

        sourceFillMode: UbuntuShape.PreserveAspectCrop
    }

    Item {
        id: msgbox

        // TODO 2 lines
        height: messageShape.height
        width: messageShape.width

        anchors {
            left: avatarShape.right
            leftMargin: units.gu(1)
            top: parent.top
        }
        // no background for the msgbox in case of images

        UbuntuShape {
            id: messageShape

            width: {
                let a = playShape.width + units.gu(1) + playLabel.contentWidth
                let b = msgLabel.contentWidth
                let c = username.contentWidth + msgDate.contentWidth + (padlock.visible ? padlock.width : 0)
                let d = quoteLabel.visible ? ((quoteUser.contentWidth > quoteLabel.contentWidth ? quoteUser.contentWidth : quoteLabel.contentWidth ) + units.gu(1) + quoteRectangle.width) : 0
                let e = forwardLabel.visible ? forwardLabel.contentWidth : 0

                let x = a > b ? a : b
                let y = ((c > d ? c : d) > e ? (c > d ? c : d): e)

                return units.gu(1) + (x > y ? x : y) + units.gu(1)
            }
            height: units.gu(1) + (forwardLabel.visible ? forwardLabel.contentHeight + units.gu(0.5) : 0) + (quoteLabel.visible ? quoteUser.contentHeight + quoteLabel.contentHeight + units.gu(1) : 0) + playShape.height + units.gu(0.5) + msgDate.height + units.gu(0.5) + (msgLabel.visible ? msgLabel.contentHeight + units.gu(0.5) : 0)

            anchors {
                left: parent.left
                bottom: parent.bottom
            }

            backgroundMode: UbuntuShape.SolidColor
            backgroundColor: model.isSearchResult ? root.searchResultMessageColor : root.otherMessageBackgroundColor
            aspect: UbuntuShape.Flat

            Rectangle {
                id: squareCornerBL
                height: units.gu(2)
                width: units.gu(2)
                anchors {
                    left: messageShape.left
                    bottom: messageShape.bottom
                }
                color: messageShape.backgroundColor
                opacity: messageShape.opacity
                visible: !model.isSameSenderAsNextMsg
            }

            Label {
                id: forwardLabel
                anchors {
                    left: parent.left
                    leftMargin: units.gu(1)
                    top: messageShape.top
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
                    top: forwardLabel.visible ? forwardLabel.bottom : messageShape.top
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

            UbuntuShape {
                id: playShape
                height: units.gu(4)
                width: height
                anchors {
                    left: parent.left
                    leftMargin: units.gu(1)
                    top: quoteLabel.visible ? quoteUser.bottom : (forwardLabel.visible ? forwardLabel.bottom : messageShape.top)
                    topMargin: quoteLabel.visible ? units.gu(1) : (forwardLabel.visible ? units.gu(0.5) : units.gu(1))
                }
                backgroundColor: "#F7F7F7"
                opacity: 0.5

                Icon {
                    width: parent.width - units.gu(1)
                    anchors.centerIn: parent
                    name: "media-playback-start"
                    color: root.darkmode ? "white" : "black"
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
                // duration as queried via dc_msg_get_duration() is 0 in most cases, omit for now
                text: (model.msgViewType === DeltaHandler.AudioType ? i18n.tr("Audio") : i18n.tr("Voice Message"))// + " " + model.duration
                color: msgLabel.color
            }

            Label {
                id: msgLabel
                width: parentWidth - avatarShape.width - units.gu(5)
                anchors {
                    left: messageShape.left
                    leftMargin: units.gu(1)
                    top: playShape.bottom
                    topMargin: units.gu(0.5)
                }
                visible: model.text != ""
                text: model.text
                color: model.isSearchResult ? "black" : theme.palette.normal.foregroundText
                linkColor: model.isSearchResult ? "#0000ff" : root.otherMessageLinkColor
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
        } // end UbuntuShape id: messageShape
    } // end Item id: msgbox
} // end Item
