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
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import QtMultimedia 5.12
//import "../delegates"

import DeltaHandler 1.0

Page {
    id: chatViewPage
    anchors.fill: parent

    property string chatname: DeltaHandler.chatName()
    property bool currentlyQuotingMessage: false
    property bool attachmentMode: false


    signal leavingChatViewPage()

    function messageJump(jumpIndex) {
        view.positionViewAtIndex(jumpIndex, ListView.End)

    }

    Component.onCompleted: {
        chatViewPage.leavingChatViewPage.connect(DeltaHandler.chatViewIsClosed)
        if (DeltaHandler.chatmodel.hasDraft) {
            messageEnterField.text = DeltaHandler.chatmodel.getDraft()

            if (DeltaHandler.chatmodel.draftHasQuote) {
                currentlyQuotingMessage = true;
                quotedMessageLabel.text = DeltaHandler.chatmodel.getDraftQuoteSummarytext()
                quotedUser.text = DeltaHandler.chatmodel.getDraftQuoteUsername()
            }
        }
    }

    Component.onDestruction: {
        messageAudio.stop()
        DeltaHandler.chatmodel.setDraft(messageEnterField.text)
        // TODO is this signal needed? Could be used
        // to unref currentMessageDraft
        leavingChatViewPage()
    }

    Connections {
        target: DeltaHandler.chatmodel
        onJumpToMsg: {
            messageJump(myindex)
        }

        onDraftHasQuoteChanged: {
            if (DeltaHandler.chatmodel.draftHasQuote) {
                currentlyQuotingMessage = true
                quotedMessageLabel.text = DeltaHandler.chatmodel.getDraftQuoteSummarytext()
                quotedUser.text = DeltaHandler.chatmodel.getDraftQuoteUsername()
                // TODO: Currently, quotes are only possible for text messages, so
                // when setting a quote, the possibility to attach something is
                // removed. Maybe change it? This would probably mean that 
                // message drafts will show attachments, too (similar as
                // DC Desktop does)
                attachmentMode = false
            } else {
                currentlyQuotingMessage = false
            }
        }
    }

    header: PageHeader {
        id: header
        title: chatname
    }

    Image {
        id: backgroundImage
        anchors.fill: parent
        opacity: 0.05
        source: root.darkmode ? Qt.resolvedUrl('../../assets/background_dark.svg') : Qt.resolvedUrl('../../assets/background_bright.svg')
        fillMode: Image.PreserveAspectFit
    }

    ListItemActions {
        id: leadingMsgAction
        actions: Action {
            iconName: "delete"
            onTriggered: {
                // the index is passed as parameter and can
                // be accessed via 'value'
                PopupUtils.open(
                    Qt.resolvedUrl('ConfirmMsgDeletion.qml'),
                    null,
                    { 'msgArrayIndex': value, }
                )
            }
        }
    }

    ListItemActions {
        id: trailingMsgActions
        actions: [
            Action {
                iconName: "mail-reply"
                onTriggered: {
                    DeltaHandler.chatmodel.setQuote(value)
                }
            },
            Action {
                iconName: "navigation-menu"
                onTriggered: {
                    PopupUtils.open(
                        Qt.resolvedUrl('MessageInfosActions.qml'),
                        null,
                        { messageIndex: value }
                    )
                }
            },
            Action {
                iconName: "mail-forward"
                onTriggered: {
                    DeltaHandler.chatmodel.prepareForwarding(value)
                    layout.addPageToCurrentColumn(chatViewPage, Qt.resolvedUrl('ForwardMessage.qml'))
                }
            }
        ]
    }
    Component {
        id: delegateListItem


        ListItem {
            id: messageListItem
            height: delegLoader.height
            divider.visible: false
            width: parent.width

            Loader {
                id: delegLoader
                // TODO rename
                property int parentWidth: parent.width
                property Audio msgAudio: messageAudio
                height: childrenRect.height // TODO: QML complains about a binding loop for property "height"
                anchors.right: model.isSelf ? parent.right : undefined
                anchors.left: model.isSelf ? undefined : parent.left
                source: 
                    if (model.isSelf) {
                        messageListItem.leadingActions = leadingMsgAction
                        messageListItem.trailingActions = trailingMsgActions

                        switch (model.msgViewType) {
                            case DeltaHandler.TextType:
                                return "../delegates/delegSelfTextMsg.qml"
                                break;
                            case DeltaHandler.ImageType:
                                return "../delegates/delegSelfImage.qml"
                                break;
                            case DeltaHandler.AudioType:
                            case DeltaHandler.VoiceType:
                                return "../delegates/delegSelfAudio.qml"
                                break;
                            default:
                                return "../delegates/delegSelfUnknown.qml"
                                break;
                        }
                        
                    } // end if (model.isSelf)
                    else if (model.isUnreadMsgsBar){
                        return "../delegates/delegUnreadMsgsBar.qml"
                    } else { // message is not from self and not the "Unread Messages" bar
                        messageListItem.leadingActions = leadingMsgAction
                        messageListItem.trailingActions = trailingMsgActions

                        switch (model.msgViewType) {
                            case DeltaHandler.TextType:
                                return "../delegates/delegOtherTextMsg.qml"
                                break;
                            case DeltaHandler.ImageType:
                                return "../delegates/delegOtherImage.qml"
                                break;
                            case DeltaHandler.AudioType:
                            case DeltaHandler.VoiceType:
                                return "../delegates/delegOtherAudio.qml"
                                break;
                            default:
                                return "../delegates/delegOtherUnknown.qml"
                        }
                    } // end message is not from self
                asynchronous: false
            }
        } // end ListItem id: messageListItem
    } // end Component id: delegateListItem

    ListView {
        id: view
        clip: true
        anchors.top: header.bottom
        topMargin: units.gu(1)
        width: parent.width
        height: chatlistPage.height - (header.height) - units.gu(1) - (messageCreatorBox.visible ? messageCreatorBox.height : requestReactionRect.height)
        model: DeltaHandler.chatmodel
        delegate: delegateListItem
        verticalLayoutDirection: ListView.BottomToTop
        spacing: units.gu(1)
        // TODO: check if this works now with the newer version
        // of QtQuick? Then we might not need to reverse the index
        //Component.onCompleted: positionViewAtEnd()

        Component.onCompleted: {
            if (DeltaHandler.chatmodel.getUnreadMessageBarIndex() > 0) {
                view.positionViewAtIndex(DeltaHandler.chatmodel.getUnreadMessageBarIndex(), ListView.Center)
            }
        }

    }

    UbuntuShape {
        id: toBottomButton
        anchors {
            right: view.right
            rightMargin: units.gu(4)
            bottom: view.bottom
            bottomMargin: units.gu(4)
        }
        backgroundColor: "#F7F7F7"
        opacity: 0.5
        visible: isScrolled

        property bool isScrolled: view.visibleArea.heightRatio + view.visibleArea.yPosition < 1.0

        width: units.gu(5)
        height: width

            Icon {
                id: toBottomIcon
                width: parent.width - units.gu(1)
                height: width
                name: "go-down"
                anchors{
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                color: root.darkmode ? "white" : "black"
                opacity: 0.5
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    view.positionViewAtBeginning()
                }
            }
    } // end UbuntuShape id: toBottomButton

    Rectangle {
        id: messageCreatorBox
        height: messageEnterField.height + (quotedMessageBox.visible ? quotedMessageBox.height + units.gu(2) : 0) + units.gu(1)
        width: parent.width
        color: theme.palette.normal.background
        anchors{
            left: parent.left
            right: parent.right
            top: view.bottom
            topMargin: units.gu(1)
        }
        visible: !DeltaHandler.chatIsContactRequest

        Rectangle {
            id: quotedMessageBox
            height: quotedMessageLabel.contentHeight + units.gu(0.5) + quotedUser.contentHeight
            width: parent.width

            color: theme.palette.normal.background

            anchors {
                left: parent.left
                top: parent.top
            }
            visible: currentlyQuotingMessage

            Rectangle {
                id: quoteRectangle
                height: quotedUser.contentHeight + units.gu(0.5) + quotedMessageLabel.contentHeight
                width: units.gu(0.5)
                anchors {
                    top: parent.top
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                color: root.darkmode ? "white" : "black"
            }

            Label {
                id: quotedMessageLabel
                width: parent.width - units.gu(2) - quoteRectangle.width - units.gu(1) - cancelQuoteShape.width - units.gu(1)
                anchors { 
                    top: parent.top
                    left: quoteRectangle.left
                    leftMargin: units.gu(1)
                }
                text: "hier nur ein erster Test, der einen ziemlich langen Text darstellt und deshalb nicht ganz reinpasst"
                clip: true
            }

            Label {
                id: quotedUser
                width: parent.width - units.gu(2) - quoteRectangle.width - units.gu(1) - cancelQuoteShape.width - units.gu(1)
                anchors {
                    top: quotedMessageLabel.bottom
                    topMargin: units.gu(0.5)
                    left: quoteRectangle.left
                    leftMargin: units.gu(1)
                }
                text: "testuser"
                font.bold: true
                fontSize: "x-small"
            }

            UbuntuShape {
                id: cancelQuoteShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width

                anchors {
                    top: parent.top
                    right: parent.right
                    rightMargin: units.gu(0.5)
                }

                Icon {
                    id: cancelQuoteIcon
                    width: parent.width - units.gu(1)
                    height: width
                    name: "close"
                    anchors{
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            DeltaHandler.chatmodel.unsetQuote()
                        }
                        enabled: currentlyQuotingMessage
                    }
                }
            }
        }

        Rectangle {
            id: attachIconCage
            height: messageEnterField.height
            width: currentlyQuotingMessage ? 0 : attachIconShape.width + units.gu(1)

            anchors {
                left: parent.left
                top: quotedMessageBox.visible ? quotedMessageBox.bottom : parent.top
                topMargin: quotedMessageBox.visible ? units.gu(2) : 0
            }

            color: theme.palette.normal.background

            UbuntuShape{
                id: attachIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width

                anchors{
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                visible: currentlyQuotingMessage ? false : true

                Icon{
                    id: attachIcon
                    width: parent.width - units.gu(1)
                    height: width
                    name: attachmentMode ? "close" : "add"
                    anchors{
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    visible: currentlyQuotingMessage ? false : true

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // TODO
                            attachmentMode = !attachmentMode
                        }
                        enabled: currentlyQuotingMessage ? false : true
                    }
                }
            } // end UbuntuShape id: attachIconShape
        } // end Rectangle id: attachIconCage
        
        TextArea {
            id: messageEnterField
            width: parent.width - sendIcon.width
            anchors{
                left: attachIconCage.right
                leftMargin: currentlyQuotingMessage ? units.gu(1) : 0
                right: sendIconCage.left
                top: quotedMessageBox.visible ? quotedMessageBox.bottom : parent.top
                topMargin: quotedMessageBox.visible ? units.gu(2) : 0
            }
            autoSize: true
            maximumLineCount: 5
            visible: !attachmentMode
        }

        // TODO: why is this Rectangle needed?
        Rectangle {
            id: sendIconCage
            height: messageEnterField.height
            width: sendIconShape.width + units.gu(1)
            anchors {
                right: parent.right
                top: quotedMessageBox.visible ? quotedMessageBox.bottom : parent.top
                topMargin: quotedMessageBox.visible ? units.gu(2) : 0
            }
            visible: !attachmentMode
            color: theme.palette.normal.background

            UbuntuShape {
                id: sendIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width
                anchors{
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

                Icon {
                    id: sendIcon
                    width: parent.width - units.gu(1)
                    height: width
                    name: "send"
                    anchors{
                        verticalCenter: parent.verticalCenter
                        horizontalCenter: parent.horizontalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // without removing the focus from the TextArea,
                            // the text passed to DeltaHandler.sendMessage
                            // may be incomplete
                            messageEnterField.focus = false
                            DeltaHandler.chatmodel.sendMessage(messageEnterField.text)
                            // clear() does not work as we are using the TextArea
                            // from Ubuntu.Components, not the one from
                            // QtQuickControls
                            //messageEnterField.clear()
                            messageEnterField.text = ''
                        }

                        enabled: messageEnterField.text != ""
                    }
                } // end Icon id: sendIcon
            } // end UbuntuShape id: sendIconShape
        } // end Rectangle id: sendIconCage

        Rectangle {
            id: filetypeToSendCage
            height: messageEnterField.height
            width: (sendImageIconShape.width + units.gu(2))*3
            anchors {
                right: messageCreatorBox.right
                rightMargin: units.gu(1)
                top: messageCreatorBox.top
                topMargin: units.gu(0.5)
            }

            color: theme.palette.normal.background

            visible: attachmentMode

            UbuntuShape{
                id: sendImageIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width

                anchors{
                    right: filetypeToSendCage.right
                    verticalCenter: parent.verticalCenter
                }

                Icon{
                    id: imageIcon
                    width: parent.width - units.gu(1)
                    height: width
                    name: "stock_image"
                    anchors{
                        horizontalCenter: sendImageIconShape.horizontalCenter
                        verticalCenter: sendImageIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            layout.addPageToCurrentColumn(chatViewPage, Qt.resolvedUrl('PickerImageToSend.qml'))
                            attachmentMode = false
                        }
                        enabled: true
                    }
                }
            } // end UbuntuShape id: sendImageIconShape

            UbuntuShape{
                id: sendAudioIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width

                anchors{
                    right: sendImageIconShape.left
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                Icon{
                    id: audioIcon
                    width: parent.width - units.gu(1)
                    height: width
                    name: "stock_music"
                    anchors{
                        horizontalCenter: sendAudioIconShape.horizontalCenter
                        verticalCenter: sendAudioIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            layout.addPageToCurrentColumn(chatViewPage, Qt.resolvedUrl('PickerAudioToSend.qml'))
                            attachmentMode = false
                        }
                        enabled: true
                    }
                }
            } // end UbuntuShape id: sendAudioIconShape

            UbuntuShape{
                id: sendFileIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width

                anchors{
                    right: sendAudioIconShape.left
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                Icon{
                    id: attachmentIcon
                    width: parent.width - units.gu(1)
                    height: width
                    name: "attachment"
                    anchors{
                        horizontalCenter: sendFileIconShape.horizontalCenter
                        verticalCenter: sendFileIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            layout.addPageToCurrentColumn(chatViewPage, Qt.resolvedUrl('PickerFileToSend.qml'))
                            attachmentMode = false
                        }
                        enabled: true
                    }
                }
            } // end UbuntuShape id: sendFileIconShape
        } // end Rectangle id: filetypeToSendCage
    } // end Rectangle id: messageCreatorBox

    Rectangle {
        id: requestReactionRect
        height: 3* acceptRequestButton.height + units.gu(8)
        width: parent.width
        color: theme.palette.normal.background
        anchors{
            left: parent.left
            right: parent.right
            top: view.bottom
            topMargin: units.gu(1)
        }
        visible: DeltaHandler.chatIsContactRequest

        Button {
            id: acceptRequestButton
            width: parent.width - units.gu(4)
            anchors {
                top: requestReactionRect.top
                topMargin: units.gu(2)
                horizontalCenter: parent.horizontalCenter
            }
            text: i18n.tr('Accept')
            color: theme.palette.normal.positive

            onClicked: {
                DeltaHandler.chatAcceptContactRequest()
            }
        }

        Button {
            id: deleteRequestButton
            width: parent.width - units.gu(4)
            anchors {
                top: acceptRequestButton.bottom
                topMargin: units.gu(2)
                horizontalCenter: parent.horizontalCenter
            }
            text: i18n.tr('Delete')
            onClicked: {
                DeltaHandler.chatDeleteContactRequest()
                layout.removePages(chatViewPage)
            }
        }

        Button {
            id: blockRequestButton
            width: parent.width - units.gu(4)
            anchors {
                top: deleteRequestButton.bottom
                topMargin: units.gu(2)
                horizontalCenter: parent.horizontalCenter
            }
            text: i18n.tr('Block')
            onClicked: {
                DeltaHandler.chatBlockContactRequest()
                layout.removePages(chatViewPage)
            }
        }

    } // end Rectangle id: requestReactionRect

    Audio {
        id: messageAudio
    }

    function millisecsToString(time) {
        // Algorithm in this function copied from Recorder app:
        // https://github.com/luksus42/recorder/blob/master/Recorder/ui/HomePage.qml
        // Originally: Copyright (C) 2016  DawnDIY <dawndiy.dev@gmail.com>
        // Forked by Luksus42

        var time_str
        var record_time = Math.ceil(time/1000)
        var sec = record_time % 60
        var min = Math.floor(record_time / 60) % 60
        var hr = Math.floor(record_time / 3600)
        if (hr > 0) {
            time_str = hr + ":"
            time_str += new Array(2-String(min).length+1).join("0") + min + ":"
            time_str += new Array(2-String(sec).length+1).join("0") + sec
        } else {
            time_str = new Array(2-String(min).length+1).join("0") + min + ":"
            time_str += new Array(2-String(sec).length+1).join("0") + sec
        }
        return time_str
    }

    UbuntuShape {
        id: audioPlayerShape
        height: units.gu(5)
        width: units.gu(1) + audioPlayIcon.width + units.gu(1) + audioStopIcon.width + units.gu(1) + durationLabel.contentWidth + units.gu(1)

        anchors {
            top: header.bottom
            topMargin: units.gu(2)
            horizontalCenter: chatViewPage.horizontalCenter
        }
        backgroundColor: root.darkmode ? "white" : "black"
        visible: messageAudio.playbackState === Audio.PlayingState || messageAudio.playbackState === Audio.PausedState

        Icon {
            id: audioPlayIcon
            height: units.gu(4)
            anchors {
                left: audioPlayerShape.left
                leftMargin: units.gu(1)
                verticalCenter: audioPlayerShape.verticalCenter
            }
            name: messageAudio.playbackState === Audio.PlayingState ? "media-playback-pause" : "media-playback-start"

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (messageAudio.playbackState === Audio.PlayingState) {
                        messageAudio.pause()
                    } else {
                        messageAudio.play()
                    }
                }
            }
        } // end Icon id: audioPlayIcon

        Icon {
            id: audioStopIcon
            height: units.gu(4)
            anchors {
                left: audioPlayIcon.right
                leftMargin: units.gu(1)
                verticalCenter: audioPlayerShape.verticalCenter
            }
            name: "media-playback-stop"

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (messageAudio.playbackState === Audio.PlayingState || messageAudio.playbackState === Audio.PausedState) {
                        messageAudio.stop()
                    }
                }
            }
        }

        Label {
            id: durationLabel
            anchors {
                left: audioStopIcon.right
                leftMargin: units.gu(1)
                verticalCenter: audioPlayerShape.verticalCenter
            }
            text: millisecsToString(messageAudio.position) + " / " + millisecsToString(messageAudio.duration)
            color: root.darkmode ? "black" : "white"
        }
    } // end UbuntuShape id: audioPlayerShape
} // end Page id: chatViewPage
