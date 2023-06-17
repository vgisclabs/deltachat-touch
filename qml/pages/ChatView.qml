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
import Qt.labs.platform 1.1
import QtMultimedia 5.12
//import "../delegates"

import DeltaHandler 1.0

Page {
    id: chatViewPage
    anchors.fill: parent

    property string chatname: DeltaHandler.chatName()
    property bool currentlyQuotingMessage: false
    property bool attachmentMode: false
    property bool audioRecordMode: false


    signal leavingChatViewPage()

    signal messageQueryTextChanged(string query)
    signal searchJumpRequest(int posType)

    function messageJump(jumpIndex) {
        view.positionViewAtIndex(jumpIndex, ListView.End)

    }

    function updateSearchStatusLabel(current, total) {
        searchStatusLabel.text = current + "/" + total
       
    }

    Component.onCompleted: {
        chatViewPage.leavingChatViewPage.connect(DeltaHandler.chatViewIsClosed)
        chatViewPage.leavingChatViewPage.connect(DeltaHandler.chatmodel.chatViewIsClosed)
        if (DeltaHandler.chatmodel.hasDraft) {
            messageEnterField.text = DeltaHandler.chatmodel.getDraft()

            if (DeltaHandler.chatmodel.draftHasQuote) {
                currentlyQuotingMessage = true;
                quotedMessageLabel.text = DeltaHandler.chatmodel.getDraftQuoteSummarytext()
                quotedUser.text = DeltaHandler.chatmodel.getDraftQuoteUsername()
            }
        }

        chatViewPage.messageQueryTextChanged.connect(DeltaHandler.chatmodel.updateQuery)
        DeltaHandler.chatmodel.searchCountUpdate.connect(updateSearchStatusLabel)
        chatViewPage.searchJumpRequest.connect(DeltaHandler.chatmodel.searchJumpSlot)
    }

    Component.onDestruction: {
        messageAudio.stop()
        messageQueryField.text = "" 

        if (audioRecordMode) {
            audioRecordBox.stopAndCleanupVoiceRecording()
        }

        DeltaHandler.chatmodel.setDraft(messageEnterField.text)
        // TODO is this signal needed? Could be used
        // to unref currentMessageDraft
        leavingChatViewPage()
    }

    Connections {
        target: DeltaHandler.chatmodel
        onChatDataChanged: {
            leadingVerifiedAction.visible = DeltaHandler.chatIsVerified()
            leadingEphemeralAction.visible = DeltaHandler.getChatEphemeralTimer(-1) != 0
            trailingEphemeralAction.visible = DeltaHandler.getChatEphemeralTimer(-1) == 0
        }
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
 
        leadingActionBar.numberOfSlots: 3
        leadingActionBar.actions: [
            Action {
                id: leadingVerifiedAction
                iconSource: Qt.resolvedUrl("../../assets/verified.png")
                text: i18n.tr("Verified Contact")
                visible: DeltaHandler.chatIsVerified()
            },

            Action {
                id: leadingEphemeralAction
                iconName: "timer"
                text: i18n.tr("Disappearing Messages")
                visible: DeltaHandler.getChatEphemeralTimer(-1) != 0
                onTriggered: {
                    PopupUtils.open(Qt.resolvedUrl("EphemeralTimerSettings.qml"))
                }
            },

            Action {
                iconName: "go-previous"
                text: i18n.tr("Back")
                onTriggered: {
                    layout.removePages(chatViewPage)
                }
            }
        ]

        trailingActionBar.actions: [
            Action {
                id: trailingEphemeralAction
                iconName: "timer"
                text: i18n.tr("Disappearing Messages")
                visible: DeltaHandler.getChatEphemeralTimer(-1) == 0
                onTriggered: {
                    PopupUtils.open(Qt.resolvedUrl("EphemeralTimerSettings.qml"))
                }
            },

            Action {
                iconName: 'edit'
                text: i18n.tr("Edit Group")
                onTriggered: {
                    DeltaHandler.startEditGroup(-1)
                    layout.addPageToCurrentColumn(chatViewPage, Qt.resolvedUrl("CreateOrEditGroup.qml"), { "createNewGroup": false })
                }
                visible: {
                    if (DeltaHandler.chatIsGroup(-1)) {
                        if (DeltaHandler.selfIsInGroup(-1)) {
                            return true
                        }
                    }
                    return false
                }
            },

            Action {
                iconName: 'find'
                text: i18n.tr("Search")
                onTriggered: {
                    if (searchRect.visible) {
                        messageQueryField.text = ""
                        searchRect.visible = false
                    } else {
                        searchRect.visible = true
                        messageQueryField.focus = true
                    }
                }
            }
        ]
    }

    Rectangle {
        id: searchRect
        width: chatViewPage.width
        height: units.gu(1) + messageQueryField.height + units.gu(1) + dividerItem.height
        anchors {
            top: header.bottom
            left: chatViewPage.left
        }
        color: theme.palette.normal.background
        visible: false

        TextField {
            id: messageQueryField
            width: parent.width - units.gu(3) - skipToLastRect.width - units.gu(1) - nextMsgRect.width - units.gu(1) - (searchStatusLabel.visible ? searchStatusLabel.contentWidth + units.gu(1) : 0) - prevMsgRect.width - units.gu(1) - skipToFirstIcon.width - units.gu(1)
            anchors {
                left: parent.left
                leftMargin: units.gu(2)
                top: searchRect.top
                topMargin: units.gu(1)
            }

            // Without inputMethodHints set to Qg.ImhNoPredictiveText, the
            // clear button only works in x86_64, but not aarch64 and armhf.
            // For the latter two, if the displayed text does not contain a
            // blank, it just doesn't vanish when the button is pressed, but
            // cannot be removed by backspace either. Pressing another
            // character will then clear the field and the pressed character
            // will appear.
            inputMethodHints: Qt.ImhNoPredictiveText
            onDisplayTextChanged: {
                messageQueryTextChanged(displayText)            }
            placeholderText: i18n.tr("Search")
        }

        Rectangle {
            id: skipToFirstRect
            width: units.gu(2.5)
            height: searchRect.height

            anchors {
                right: prevMsgRect.left
                rightMargin: units.gu(1)
                top: searchRect.top
            }
            color: searchRect.color
            visible: messageQueryField.text != ""
    
            Icon {
                id: skipToFirstIcon
                name: "media-skip-backward"
                width: units.gu(2.5)
                anchors{
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                color: root.darkmode ? "white" : "black"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    messageQueryField.focus = false
                    searchJumpRequest(DeltaHandler.PositionFirst)
                }
            }
        }

        Rectangle {
            id: prevMsgRect
            width: units.gu(2.5)
            height: searchRect.height

            anchors {
                right: searchStatusLabel.visible ? searchStatusLabel.left : nextMsgRect.left
                rightMargin: units.gu(1)
                top: searchRect.top
            }
            color: searchRect.color
            visible: messageQueryField.text != ""
    
            Icon {
                id: prevMsgIcon
                name: "media-playback-start-rtl"
                width: units.gu(2.5)
                anchors{
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                color: root.darkmode ? "white" : "black"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    messageQueryField.focus = false
                    searchJumpRequest(DeltaHandler.PositionPrev)
                }
            }
        }

        Label {
            id: searchStatusLabel
            anchors {
                right: nextMsgRect.left
                rightMargin: units.gu(1)
                verticalCenter: searchRect.verticalCenter
            }
            text: "0/0"
            visible: messageQueryField.text != ""
        }

        Rectangle {
            id: nextMsgRect
            width: units.gu(2.5)
            height: searchRect.height

            anchors {
                right: skipToLastRect.left
                rightMargin: units.gu(1)
                top: searchRect.top
            }
            color: searchRect.color
            visible: messageQueryField.text != ""
    
            Icon {
                id: nextMsgIcon
                name: "media-playback-start"
                width: units.gu(2.5)
                anchors{
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                color: root.darkmode ? "white" : "black"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    messageQueryField.focus = false
                    searchJumpRequest(DeltaHandler.PositionNext)
                }
            }
        }

        Rectangle {
            id: skipToLastRect
            width: units.gu(2.5)
            height: searchRect.height

            anchors {
                right: searchRect.right
                rightMargin: units.gu(1)
                top: searchRect.top
            }
            color: searchRect.color
            visible: messageQueryField.text != ""
    
            Icon {
                id: skipToLastIcon
                name: "media-skip-forward"
                width: units.gu(2.5)
                anchors{
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                color: root.darkmode ? "white" : "black"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    messageQueryField.focus = false
                    searchJumpRequest(DeltaHandler.PositionLast)
                }
            }
        }

        ListItem {
            id: dividerItem
            height: divider.height
            anchors {
                top: messageQueryField.bottom
                topMargin: units.gu(1)
            }
            divider.visible: true
        }
        
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
                property Page chatPage: chatViewPage
                property bool anchorToRight: {
                    if (!model.isUnreadMsgsBar) {
                        if (model.isInfo) {
                            return false
                        } else {
                            return model.isSelf
                        }
                    } else {
                        return false
                    }
                }
                height: childrenRect.height // TODO: QML complains about a binding loop for property "height"
                anchors.right: anchorToRight ? parent.right : undefined
                anchors.left: anchorToRight ? undefined : parent.left
                source: 
                    if (model.isUnreadMsgsBar){
                        return "../delegates/delegUnreadMsgsBar.qml"
                    } else if (model.isInfo) {
                        return "../delegates/delegInfoMsg.qml"
                    } else if (model.isSelf) {
                        messageListItem.leadingActions = leadingMsgAction
                        messageListItem.trailingActions = trailingMsgActions

                        if (model.isDownloaded) {
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
                                case DeltaHandler.StickerType:
                                case DeltaHandler.GifType:
                                    return "../delegates/delegSelfAnimatedImage.qml"
                                    break;
                                default:
                                    return "../delegates/delegSelfUnknown.qml"
                                    break;
                            }
                        } else {
                                return "../delegates/delegSelfToDownload.qml"
                        }
                    } // end if (model.isSelf)
                    else { // message is not from self and not the "Unread Messages" bar
                        messageListItem.leadingActions = leadingMsgAction
                        messageListItem.trailingActions = trailingMsgActions

                        if (model.isDownloaded) {
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
                                case DeltaHandler.StickerType:
                                case DeltaHandler.GifType:
                                    return "../delegates/delegOtherAnimatedImage.qml"
                                    break;
                                default:
                                    return "../delegates/delegOtherUnknown.qml"
                            }
                        } else {
                                return "../delegates/delegOtherToDownload.qml"
                        }
                    } // end message is not from self
                asynchronous: false
            }
        } // end ListItem id: messageListItem
    } // end Component id: delegateListItem

    ListView {
        id: view
        clip: true
        anchors.top: searchRect.visible ? searchRect.bottom : header.bottom
        topMargin: units.gu(1)
        width: parent.width
        height: chatlistPage.height - header.height - (searchRect.visible ? searchRect.height : 0) - units.gu(1) - (messageCreatorBox.visible ? messageCreatorBox.height : requestReactionRect.height)
        model: DeltaHandler.chatmodel
        delegate: delegateListItem
        verticalLayoutDirection: ListView.BottomToTop
        spacing: units.gu(1)
        cacheBuffer: 0

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
        height: audioRecordMode ? audioRecordBox.height : messageEnterField.height + (quotedMessageBox.visible ? quotedMessageBox.height + units.gu(2) : 0) + units.gu(1)
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
                color: theme.palette.normal.overlay

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
                color: theme.palette.normal.overlay

                anchors{
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                visible: audioRecordMode ? false : currentlyQuotingMessage ? false : true

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
            visible: !attachmentMode && !audioRecordMode
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
            visible: !attachmentMode && !audioRecordMode
            color: theme.palette.normal.background

            UbuntuShape {
                id: sendIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width
                color: theme.palette.normal.overlay
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
                } // end Icon id: sendIcon
            } // end UbuntuShape id: sendIconShape

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
        } // end Rectangle id: sendIconCage

        Rectangle {
            id: filetypeToSendCage
            height: messageEnterField.height
            width: (sendImageIconShape.width + units.gu(2))*3
            anchors {
                right: messageCreatorBox.right
                rightMargin: units.gu(1)
                top: messageCreatorBox.top
            }

            color: theme.palette.normal.background

            visible: attachmentMode && !audioRecordMode

            UbuntuShape{
                id: sendImageIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width
                color: theme.palette.normal.overlay

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
                color: theme.palette.normal.overlay

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

            UbuntuShape {
                id: sendFileIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width
                color: theme.palette.normal.overlay

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

            UbuntuShape {
                id: voiceMessageIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width
                color: theme.palette.normal.overlay

                anchors{
                    right: sendFileIconShape.left
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                Icon{
                    id: voiceMessageIcon
                    width: parent.width - units.gu(1)
                    height: width
                    name: "audio-input-microphone-symbolic"
                    anchors{
                        horizontalCenter: voiceMessageIconShape.horizontalCenter
                        verticalCenter: voiceMessageIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            messageAudio.stop()
                            DeltaHandler.prepareAudioRecording(root.voiceMessageQuality)
                            attachmentMode = false
                            audioRecordMode = true
                        }
                        enabled: true
                    }
                }
            } // end UbuntuShape id: voiceMessageIconShape
        } // end Rectangle id: filetypeToSendCage
        

    /* ======================================================
       ============== Voice Message Recording ===============
       ====================================================== */

        UbuntuShape {
            // separate close icon at (almost) the same position as
            // the regular one, just to reduce the complexity of the
            // statements for "enabled" and "onClicked"
            id: leaveRecIconShape
            width: FontUtils.sizeToPixels("x-large") * 1.2
            height: width
            color: theme.palette.normal.overlay

            visible: audioRecordMode
            opacity: !audioRecordBox.isRecording && !audioRecordBox.recordIsPlaying ? 1 : 0.5

            anchors{
                left: messageCreatorBox.left
                leftMargin: units.gu(1)
                bottom: parent.bottom
                bottomMargin: units.gu(1)
            }

            Icon {
                width: parent.width - units.gu(1)
                height: width
                name: "close"
                anchors{
                    horizontalCenter: leaveRecIconShape.horizontalCenter
                    verticalCenter: leaveRecIconShape.verticalCenter
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (audioRecordBox.hasRecord) {
                            PopupUtils.open(popoverComponentConfirmLeavingRecording, leaveRecIconShape)
                        } else {
                            // need to call dismiss even if hasRecord is false because a recording
                            // might have been finished, but deleted afterwards, in which case the
                            // QAudioRecorder object in C++ has been created
                            DeltaHandler.dismissAudioRecording()
                            audioRecordMode = false
                        }
                    }
                    enabled: audioRecordMode && !audioRecordBox.isRecording && !audioRecordBox.recordIsPlaying
                }
            }
        } // end UbuntuShape id: sendRecIconShape

        UbuntuShape {
            // separate send icon at (almost) the same position as
            // the regular one, just to reduce the complexity of the
            // statements for "enabled" and "onClicked"
            id: sendRecIconShape
            width: FontUtils.sizeToPixels("x-large") * 1.2
            height: width
            color: theme.palette.normal.overlay

            visible: audioRecordMode
            opacity: audioRecordBox.hasRecord && !audioRecordBox.isRecording && !audioRecordBox.recordIsPlaying ? 1 : 0.5

            anchors{
                right: messageCreatorBox.right
                rightMargin: units.gu(1)
                bottom: parent.bottom
                bottomMargin: units.gu(1)
            }

            Icon {
                width: parent.width - units.gu(1)
                height: width
                name: "send"
                anchors{
                    horizontalCenter: sendRecIconShape.horizontalCenter
                    verticalCenter: sendRecIconShape.verticalCenter
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        DeltaHandler.sendAudioRecording(audioRecordBox.voiceMessageFile)
                        audioRecordBox.stopAndCleanupVoiceRecording()
                        audioRecordMode = false
                    }
                    enabled: audioRecordMode && audioRecordBox.hasRecord && !audioRecordBox.isRecording && !audioRecordBox.recordIsPlaying
                }
            }
        } // end UbuntuShape id: sendRecIconShape

        UbuntuShape {
            id: floatingInfoRecordingShape
            height: units.gu(10)
            width: height

            anchors {
                bottom: audioRecordBox.top
                bottomMargin: units.gu(10)
                horizontalCenter: parent.horizontalCenter
            }

            color: root.darkmode? "white" : "black"
            visible: audioRecordBox.isRecording

            Icon{
                width: parent.width - units.gu(1)
                height: width
                name: "media-record"
                anchors{
                    horizontalCenter: floatingInfoRecordingShape.horizontalCenter
                    verticalCenter: floatingInfoRecordingShape.verticalCenter
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite
                running: true
                PropertyAnimation {
                    target: floatingInfoRecordingShape
                    property: "opacity"
                    to: 1
                    duration: 1000
                }
                PropertyAnimation {
                    target: floatingInfoRecordingShape
                    property: "opacity"
                    to: 0.3
                    duration: 1000
                }
            }
        }

        Rectangle {
            id: audioRecordBox
            height: startRecIconShape.height + units.gu(2)
            width: units.gu(1) + deleteRecIconShape.width + units.gu(1) + startRecIconShape.width + units.gu(1) + stopRecIconShape.width + units.gu(1) + playRecIconShape.width + units.gu(1)

            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }

            visible: audioRecordMode
            border.color: "grey" //root.darkmode ? "white" : "black"
            border.width: units.gu(0.1)
            color: theme.palette.normal.background

            property bool isRecording: false
            property bool hasRecord: false
            property bool recordIsPlaying: false
            property string voiceMessageFile: ""

            function stopVoiceRecordingOrPlaying() {
                if (audioRecordBox.isRecording) {
                    DeltaHandler.stopAudioRecording()
                    audioRecordBox.isRecording = false
                } else if (audioRecordBox.recordIsPlaying) {
                    recordedAudio.stop()
                }
            }

            function stopAndCleanupVoiceRecording() {
                if (audioRecordBox.isRecording) {
                    DeltaHandler.stopAudioRecording()
                    audioRecordBox.isRecording = false
                } else if (audioRecordBox.recordIsPlaying) {
                    recordedAudio.stop()
                }
                DeltaHandler.dismissAudioRecording()
                audioRecordBox.hasRecord = false
            }

            Connections {
                target: recordedAudio

                onPlaybackStateChanged: {
                    if (recordedAudio.playbackState === Audio.PlayingState) {
                        audioRecordBox.recordIsPlaying = true
                    } else {
                        audioRecordBox.recordIsPlaying = false
                    }
                }
            }

            UbuntuShape {
                id: deleteRecIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width
                color: theme.palette.normal.overlay

                opacity: audioRecordBox.hasRecord && !audioRecordBox.isRecording && !audioRecordBox.recordIsPlaying ? 1 : 0.5

                anchors{
                    left: parent.left
                    leftMargin: units.gu(1)
                    bottom: parent.bottom
                    bottomMargin: units.gu(1)
                }

                Icon {
                    width: parent.width - units.gu(1)
                    height: width
                    name: "delete"
                    anchors{
                        horizontalCenter: deleteRecIconShape.horizontalCenter
                        verticalCenter: deleteRecIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // TODO: delete the file in the cache?
                            //DeltaHandler.deleteAudioRecording()
                            PopupUtils.open(popoverComponentConfirmDeletion, deleteRecIconShape)
                        }
                        enabled: audioRecordBox.hasRecord && !audioRecordBox.isRecording && !audioRecordBox.recordIsPlaying
                    }
                }
            } // end UbuntuShape id: deleteRecIconShape

            UbuntuShape {
                id: startRecIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width
                color: theme.palette.normal.overlay

                opacity: !audioRecordBox.hasRecord && !audioRecordBox.isRecording ? 1 : 0.5

                anchors{
                    left: deleteRecIconShape.right
                    leftMargin: units.gu(1)
                    bottom: parent.bottom
                    bottomMargin: units.gu(1)
                }

                Icon{
                    width: parent.width - units.gu(1)
                    height: width
                    name: "media-record"
                    anchors{
                        horizontalCenter: startRecIconShape.horizontalCenter
                        verticalCenter: startRecIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            audioRecordBox.voiceMessageFile = DeltaHandler.startAudioRecording()
                            audioRecordBox.isRecording = true
                        }
                        enabled: !audioRecordBox.hasRecord && !audioRecordBox.isRecording
                    }
                }
            } // end UbuntuShape id: startRecIconShape

            UbuntuShape {
                id: stopRecIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width
                color: theme.palette.normal.overlay

                opacity: (audioRecordBox.isRecording || audioRecordBox.recordIsPlaying) ? 1 : 0.5

                anchors{
                    left: startRecIconShape.right
                    leftMargin: units.gu(1)
                    bottom: parent.bottom
                    bottomMargin: units.gu(1)
                }

                Icon{
                    width: parent.width - units.gu(1)
                    height: width
                    name: "media-playback-stop"
                    anchors{
                        horizontalCenter: stopRecIconShape.horizontalCenter
                        verticalCenter: stopRecIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (audioRecordBox.isRecording) {
                                DeltaHandler.stopAudioRecording()
                                audioRecordBox.isRecording = false
                                audioRecordBox.hasRecord = true
                            } else if (audioRecordBox.recordIsPlaying) {
                                recordedAudio.stop()
                            }
                        }
                        enabled: (audioRecordBox.isRecording || audioRecordBox.recordIsPlaying)
                    }
                }
            } // end UbuntuShape id: startRecIconShape

            UbuntuShape {
                id: playRecIconShape
                width: FontUtils.sizeToPixels("x-large") * 1.2
                height: width
                color: theme.palette.normal.overlay

                opacity: audioRecordBox.hasRecord && !audioRecordBox.isRecording && !audioRecordBox.recordIsPlaying ? 1 : 0.5

                anchors{
                    left: stopRecIconShape.right
                    leftMargin: units.gu(1)
                    bottom: parent.bottom
                    bottomMargin: units.gu(1)
                }

                Icon{
                    width: parent.width - units.gu(1)
                    height: width
                    name: "media-playback-start"
                    anchors{
                        horizontalCenter: playRecIconShape.horizontalCenter
                        verticalCenter: playRecIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            recordedAudio.source = Qt.resolvedUrl(StandardPaths.locate(StandardPaths.CacheLocation, audioRecordBox.voiceMessageFile))
                            console.log("============== voiceMessageFile is: ", audioRecordBox.voiceMessageFile)
                            recordedAudio.play()
                        }
                        enabled: audioRecordBox.hasRecord && !audioRecordBox.isRecording && !audioRecordBox.recordIsPlaying
                    }
                }
            } // end UbuntuShape id: playRecIconShape
        } // end UbuntuShape id: audioRecordBox

    /* ============ End Voice Message Recording ============= */

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
        onPlaying: {
            audioRecordBox.stopVoiceRecordingOrPlaying()
        }
    }

    Audio {
        id: recordedAudio
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

    Component {
        id: popoverComponentConfirmLeavingRecording
        Popover {
            id: popoverConfirmLeavingRecording
            Column {
                id: containerLayoutLeavingRecording
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                }
                ListItem {
                    height: layout31.height
                    // should be automatically be themed with something like
                    // theme.palette.normal.overlay, but this
                    // doesn't seem to work for Ambiance (and importing
                    // Ubuntu.Components.Themes 1.3 doesn't solve it). 
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout31
                        // TODO string not translated yet
                        title.text: i18n.tr("Click to leave without sending")
                    }
                    onClicked: {
                        audioRecordBox.stopAndCleanupVoiceRecording()
                        audioRecordMode = false
                        PopupUtils.close(popoverConfirmLeavingRecording)
                    }
                }
            }
        }
    } // end Component id: popoverComponentConfirmLeavingRecording

    Component {
        id: popoverComponentConfirmDeletion
        Popover {
            id: popoverConfirmDeletion
            Column {
                id: containerLayoutDeletion
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                }
                ListItem {
                    height: layout1.height
                    // should be automatically be themed with something like
                    // theme.palette.normal.overlay, but this
                    // doesn't seem to work for Ambiance (and importing
                    // Ubuntu.Components.Themes 1.3 doesn't solve it). 
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout1
                        // TODO string not translated yet
                        title.text: i18n.tr("Click to delete")
                    }
                    onClicked: {
                        audioRecordBox.hasRecord = false
                        audioRecordBox.voiceMessageFile = ""
                        PopupUtils.close(popoverConfirmDeletion)
                    }
                }
            }
        }
    } // end Component id: popoverComponentConfirmDeletion
} // end Page id: chatViewPage
