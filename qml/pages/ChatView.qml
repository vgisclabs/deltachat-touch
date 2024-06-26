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
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import QtMultimedia 5.12

import DeltaHandler 1.0

import "/jsonrpc.mjs" as JSONRPC

Page {
    id: chatViewPage
    anchors.fill: parent

    property bool currentlyQuotingMessage: false

    property int pageAccID
    property int pageChatID

    property var fullChatJson
    property string chatname
    property string chatImagePath
    property string chatInitial
    property string chatColor

    // determines whether the buttons to add attachments (== true) or
    // the text entry bar are visible (== false)
    property bool attachmentMode: false

    property bool enterFieldChangeUpdatesDraft: true

    property bool attachAnimatedImagePreviewMode: false
    property bool attachImagePreviewMode: false
    property bool attachFilePreviewMode: false
    property bool attachAudioPreviewMode: false
    property bool attachVoicePreviewMode: false
    property string attachAudioPath
    property bool isRecording: false

    property bool chatCanSend: DeltaHandler.chatmodel.chatCanSend()
    property bool isContactRequest: DeltaHandler.chatIsContactRequest
    property bool protectionIsBroken: DeltaHandler.chatmodel.chatIsProtectionBroken()

    property real datelineIconSize: FontUtils.sizeToPixels(root.scaledFontSize) * 0.75

    property bool requestQrScanPage: false

    signal leavingChatViewPage(bool qrScanPageRequested)

    signal messageQueryTextChanged(string query)
    signal searchJumpRequest(int posType)

    function messageJump(jumpIndex) {
        view.positionViewAtIndex(jumpIndex, ListView.End)

    }

    function updateSearchStatusLabel(current, total) {
        searchStatusLabel.text = current + "/" + total
       
    }

    function playAudio(srcUrl) {
         audioPlayLoader.active = true
         audioPlayLoader.startPlaying(srcUrl)
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

    function closeAndStartQr() {
        // Call this method to close this page and go
        // to the QR scan page instead.
        //
        // When the page is closed, onDestruction is called
        // which emits the signal chatViewIsClosed with
        // requestQrScanPage as parameter. The signal
        // is connected to a slot in DeltaHandler which
        // itself emits a similar signal that is connected
        // to Main.qml, again with requestQrScanPage as parameter.
        // If it is true, Main.qml will directly go to the
        // QR Scan page.
        requestQrScanPage = true
        layout.removePages(chatViewPage)
    }


    Loader {
        // Only for non-Ubuntu Touch platforms
        id: momFileExpLoader
    }


    Connections {
        // Only for non-Ubuntu Touch platforms
        target: momFileExpLoader.item
        onFolderSelected: {
            let exportedPath = DeltaHandler.chatmodel.exportMomentaryFileToFolder(urlOfFolder)
            showExportSuccess(exportedPath)
            momFileExpLoader.source = ""
        }
        onCancelled: {
            momFileExpLoader.source = ""
        }
    }


    function showExportSuccess(exportedPath) {
        // Only for non-Ubuntu Touch platforms
        if (exportedPath === "") {
            // error, file was not exported
            PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"),
            chatViewPage,
            // TODO: string not translated yet
            {"text": i18n.tr("File could not be saved") , "title": i18n.tr("Error") })
        } else {
            PopupUtils.open(Qt.resolvedUrl("InfoPopup.qml"),
            chatViewPage,
            // TODO: string not translated yet
            {"text": i18n.tr("Saved file ") + exportedPath })
        }
    }

    
    function exportMomentaryMessageFile() {
        if (DeltaHandler.chatmodel.setUrlToExport()) {
            let tempType

            switch (DeltaHandler.chatmodel.getMomentaryViewType()) {
                case DeltaHandler.GifType:
                    // fallthrough; both ContentHub and FileDialog
                    // don't differentiate between animated and non-animated
                    // images when saving the file
                case DeltaHandler.ImageType:
                    tempType = DeltaHandler.ImageType
                    break;
                    
                case DeltaHandler.AudioType:
                case DeltaHandler.VoiceType:
                    tempType = DeltaHandler.AudioType
                    break;

                default:
                    tempType = DeltaHandler.FileType
                    break;
            }

            // different code depending on platform
            if (root.onUbuntuTouch) {
                // Ubuntu Touch
                extraStack.push(Qt.resolvedUrl('FileExportDialog.qml'), { "url": StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.chatmodel.getUrlToExport()), "conType": tempType })

            } else {
                // non-Ubuntu Touch
                momFileExpLoader.source = "FileExportDialog.qml"

                // TODO: String not translated yet
                momFileExpLoader.item.title = "Choose folder to save " + DeltaHandler.chatmodel.getMomentaryFilenameToExport()
                momFileExpLoader.item.setFileType(tempType)
                momFileExpLoader.item.open()
            }
        }
    }


    Component.onCompleted: {
        DeltaHandler.setChatViewIsShown();

        chatViewPage.leavingChatViewPage.connect(DeltaHandler.chatViewIsClosed)
        chatViewPage.leavingChatViewPage.connect(DeltaHandler.chatmodel.chatViewIsClosed)

        // Hack to correctly size the height of the TextArea. Without
        // it, when resizing, the font will have the size according to
        // scaledFontSize, but the item height will still correlate to
        // "medium".
        // TODO take care of this in two-column mode
        chatViewPage.enterFieldChangeUpdatesDraft = false
        messageEnterField.text = "b\nb"
        messageEnterField.text = ""
        chatViewPage.enterFieldChangeUpdatesDraft = true

        if (DeltaHandler.chatmodel.hasDraft) {
            messageEnterField.text = DeltaHandler.chatmodel.getDraftText()

            if (DeltaHandler.chatmodel.draftHasQuote) {
                currentlyQuotingMessage = true;
                quotedMessageLabel.text = DeltaHandler.chatmodel.getDraftQuoteSummarytext()
                quotedUser.text = DeltaHandler.chatmodel.getDraftQuoteUsername()
            }

            DeltaHandler.chatmodel.checkDraftHasAttachment()
        }

        chatViewPage.messageQueryTextChanged.connect(DeltaHandler.chatmodel.updateQuery)
        DeltaHandler.chatmodel.searchCountUpdate.connect(updateSearchStatusLabel)
        chatViewPage.searchJumpRequest.connect(DeltaHandler.chatmodel.searchJumpSlot)

        let requestString = DeltaHandler.constructJsonrpcRequestString("get_full_chat_by_id", "" + chatViewPage.pageAccID + ", " + chatViewPage.pageChatID)
        let jsonresponse = JSON.parse(DeltaHandler.sendJsonrpcBlockingCall(requestString))
        fullChatJson = jsonresponse.result

        chatname = fullChatJson.name
        chatColor = fullChatJson.color

        if (fullChatJson.profileImage != null) {
            let path = fullChatJson.profileImage
            let lengthToSubtract = ("" + StandardPaths.writableLocation(StandardPaths.AppConfigLocation)).length - 6
            chatImagePath = path.substring(lengthToSubtract)
        } else {
            chatImagePath = ""
        }

        if (fullChatJson.name === "") {
            chatInitial = "#"
        } else {
            chatInitial = fullChatJson.name.charAt(0).toUpperCase()
        }
    }

    Component.onDestruction: {
        messageAudio.stop()
        messageQueryField.text = "" 

        if (isRecording) {
            DeltaHandler.dismissAudioRecording()
        }

        root.chatViewIsOpen = false

        // TODO is this signal needed? Could be used
        // to unref currentMessageDraft
        leavingChatViewPage(requestQrScanPage)
    }

    function updateChatData() {
        let requestString = DeltaHandler.constructJsonrpcRequestString("get_full_chat_by_id", "" + chatViewPage.pageAccID + ", " + chatViewPage.pageChatID)
        let jsonresponse = JSON.parse(DeltaHandler.sendJsonrpcBlockingCall(requestString))
        fullChatJson = jsonresponse.result

        chatname = fullChatJson.name
        chatColor = fullChatJson.color

        if (fullChatJson.profileImage != null) {
            let path = fullChatJson.profileImage
            let lengthToSubtract = ("" + StandardPaths.writableLocation(StandardPaths.AppConfigLocation)).length - 6
            chatImagePath = path.substring(lengthToSubtract)
        } else {
            chatImagePath = ""
        }

        if (fullChatJson.name === "") {
            chatInitial = "#"
        } else {
            chatInitial = fullChatJson.name.charAt(0).toUpperCase()
        }

        chatCanSend = DeltaHandler.chatmodel.chatCanSend()
        protectionIsBroken = DeltaHandler.chatmodel.chatIsProtectionBroken()
        if (!chatCanSend) {
            if (DeltaHandler.chatmodel.chatIsDeviceTalk()) {
                cannotSendLabel.text = i18n.tr("This chat contains locally generated messages; writing is disabled.")
            } else if (DeltaHandler.chatIsGroup(-1) && !DeltaHandler.chatmodel.selfIsInGroup()) {
                cannotSendLabel.text = i18n.tr("You must be in this group to post a message. To join, ask another member.")
            } else {
                cannotSendLabel.text = ""
            }
        }
        isContactRequest = DeltaHandler.chatIsContactRequest
        verifiedIcon.visible = DeltaHandler.chatIsVerified()
        ephemeralIcon.visible = DeltaHandler.getChatEphemeralTimer(-1) != 0
    }

    Connections {
        target: DeltaHandler
        onChatDataChanged: {
            // CAVE: is emitted by both DeltaHandler and ChatModel
            updateChatData()   
        }

        onFontSizeChanged: {
            let tempentry = messageEnterField.text
            chatViewPage.enterFieldChangeUpdatesDraft = false
            messageEnterField.text = "b\nb"
            messageEnterField.text = tempentry
            chatViewPage.enterFieldChangeUpdatesDraft = true
        }
    }

    Connections {
        target: DeltaHandler.chatmodel

        onChatDataChanged: {
            // CAVE: is emitted by both DeltaHandler and ChatModel
            updateChatData()
        }

        onNewChatConfigured: {
            // chatID is from the newChatConfigured signal
            chatViewPage.pageChatID = chatID
            chatViewPage.pageAccID = DeltaHandler.getCurrentAccountId()

            updateChatData()

            // clean up from previous chat
            messageAudio.stop()
            messageQueryField.text = "" 

            messageEnterField.text = ""

            attachmentMode = false

            attachAnimatedImagePreviewMode = false
            attachImagePreviewMode = false
            attachFilePreviewMode = false
            attachAudioPreviewMode = false

            if (isRecording) {
                DeltaHandler.dismissAudioRecording()
            }

            currentlyQuotingMessage = false;

            // set the draft, if present
            if (DeltaHandler.chatmodel.hasDraft) {
                messageEnterField.text = DeltaHandler.chatmodel.getDraftText()

                if (DeltaHandler.chatmodel.draftHasQuote) {
                    currentlyQuotingMessage = true;
                    quotedMessageLabel.text = DeltaHandler.chatmodel.getDraftQuoteSummarytext()
                    quotedUser.text = DeltaHandler.chatmodel.getDraftQuoteUsername()
                }

                DeltaHandler.chatmodel.checkDraftHasAttachment()
            }

            // now re-activate draft handling (pageChatID is sent to double-check
            // whether the chatID is in sync with C++ side)
            DeltaHandler.chatmodel.allowSettingDraftAgain(chatViewPage.pageChatID)

            // jump to the unread message item
            if (DeltaHandler.chatmodel.getUnreadMessageBarIndex() > 0) {
                unreadJumpTimer.start()
            }

            unreadJumpTimer.start()
        }

        onJumpToMsg: {
            messageJump(myindex)
        }

        onDraftHasQuoteChanged: {
            if (DeltaHandler.chatmodel.draftHasQuote) {
                currentlyQuotingMessage = true
                quotedMessageLabel.text = DeltaHandler.chatmodel.getDraftQuoteSummarytext()
                quotedUser.text = DeltaHandler.chatmodel.getDraftQuoteUsername()
                attachmentMode = false
            } else {
                currentlyQuotingMessage = false
            }
        }

        onPreviewImageAttachment: {
            let sourcePath = Qt.resolvedUrl(StandardPaths.locate(StandardPaths.CacheLocation, filepathInCache))

            if (isAnimated) {
                attachPreviewAnimatedImage.source = sourcePath
                attachAnimatedImagePreviewMode = true

            } else {
                attachPreviewImage.source = sourcePath
                attachImagePreviewMode = true
            }
        }

        onPreviewFileAttachment: {
            attachFilePreviewLabel.text = filename;
            attachFilePreviewMode = true
        }

        onPreviewAudioAttachment: {
            // Audio is guaranteed to always be located in the CacheLocation because
            // it won't play if it's in AppConfigLocation due to AppArmor
            attachAudioPath = Qt.resolvedUrl(StandardPaths.locate(StandardPaths.CacheLocation, filepathInCache))
            attachAudioPreviewMode = true
            attachFilePreviewLabel.text = filename;
        }

        // onPreviewVoiceAttachment is NOT emitted by deltahandler
        onPreviewVoiceAttachment: {
            // Audio is guaranteed to always be located in the CacheLocation because
            // it won't play if it's in AppConfigLocation due to AppArmor
            attachAudioPath = Qt.resolvedUrl(StandardPaths.locate(StandardPaths.CacheLocation, filepathInCache))
            attachVoicePreviewMode = true
            attachFilePreviewLabel.text = i18n.tr("Voice Message")
        }
    }

    header: PageHeader {
        id: header
        //title: chatname

        contents: Rectangle {
            anchors.fill: parent
            color: theme.palette.normal.background

            LomiriShape {
                id: headerChatPic
                height: parent.height - units.gu(1)
                width: height

                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                }

                source: chatImagePath === "" ? undefined : chatImage

                Image {
                    id: chatImage
                    visible: false
                    source: StandardPaths.locate(StandardPaths.AppConfigLocation, chatImagePath)

                }

                Label {
                    id: chatInitialLabel
                    text: chatInitial
                    font.pixelSize: headerChatPic.height * 0.6
                    color: "white"
                    visible: chatImagePath === ""
                    anchors.centerIn: parent
                }

                color: chatColor
                sourceFillMode: LomiriShape.PreserveAspectCrop
                aspect: LomiriShape.Flat
            } // end LomiriShape id: headerChatPic

            Label {
                id: chatNameLabel
                anchors {
                    left: headerChatPic.right
                    leftMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                text: chatname
                width: parent.width - headerChatPic.width - units.gu(2) - (verifiedIcon.visible ? (verifiedIcon.width + units.gu(1)) : 0) - (ephemeralIcon.visible ? (ephemeralIcon.width + units.gu(1)) : 0)
                elide: Text.ElideRight
                fontSize: "large"
            }

            Icon {
                id: verifiedIcon
                height: chatNameLabel.height * 0.7
                width: height
                anchors {
                    left: headerChatPic.right
                    leftMargin: units.gu(2) + chatNameLabel.contentWidth
                    verticalCenter: parent.verticalCenter
                }
                source: "qrc:///assets/verified.svg"
                visible: DeltaHandler.chatIsVerified()
            }

            MouseArea {
                // code needs to be above the MouseArea of ephemeralIcon for the latter to work
                anchors.fill: parent
                onClicked: {
                    if (fullChatJson.chatType === DeltaHandler.ChatTypeSingle && !fullChatJson.isSelfTalk) {
                        extraStack.push(Qt.resolvedUrl("../pages/ProfileOther.qml"), { "contactID": fullChatJson.contactIds[0] })

                    } else if (fullChatJson.chatType === DeltaHandler.ChatTypeGroup) {
                        DeltaHandler.setMomentaryChatIdById(chatViewPage.pageChatID)
                        DeltaHandler.momentaryChatStartEditGroup()
                        extraStack.push(Qt.resolvedUrl("CreateOrEditGroup.qml"), { "createNewGroup": false, "selfIsInGroup": DeltaHandler.momentaryChatSelfIsInGroup() })
                        
                    } else {
                        console.log("Header clicked, info: Neither a group nor a single chat, no action defined")
                    }
                }
            }

            Rectangle {
                height: parent.height
                width: verifiedIcon.width
                anchors {
                    left: verifiedIcon.right
                    leftMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                color: theme.palette.normal.background

                Icon {
                    id: ephemeralIcon
                    height: verifiedIcon.height
                    width: height
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    //name: "timer"
                    source: "qrc:///assets/suru-icons/timer.svg"
                    color: root.darkmode ? "white" : "black"
                    visible: DeltaHandler.getChatEphemeralTimer(-1) != 0
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        PopupUtils.open(Qt.resolvedUrl("EphemeralTimerSettings.qml"))
                    }
                }
            }
        }

        leadingActionBar.actions: [
            Action {
                //iconName: "go-previous"
                iconSource: "qrc:///assets/suru-icons/go-previous.svg"
                text: i18n.tr("Back")
                onTriggered: {
                    layout.removePages(chatViewPage)
                }
                visible: !root.hasTwoColumns
            }
        ]

        trailingActionBar.actions: [
            Action {
                //iconName: 'navigation-menu'
                iconSource: "qrc:///assets/suru-icons/navigation-menu.svg"
                // TODO: string not translated (is not shown
                // on phone, but maybe in desktop mode?)
                text: i18n.tr("More Actions")
                onTriggered: {
                    DeltaHandler.setMomentaryChatIdById(DeltaHandler.chatmodel.getCurrentChatId())
                    let popup = PopupUtils.open(Qt.resolvedUrl("ChatInfosActionsChatview.qml"))
                    popup.closeDialogAndLeaveChatView.connect(function() {
                        PopupUtils.close(popup)
                        // see Timer in QrShowScan.qml
                        leaveTimer.start()
                    })
                }
            },

            Action {
                //iconName: 'find'
                iconSource: "qrc:///assets/suru-icons/find.svg"
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
            font.pixelSize: root.scaledFontSizeInPixels

            onFocusChanged: {
                if (root.oskViaDbus) {
                    if (focus) {
                        DeltaHandler.openOskViaDbus()
                    } else {
                        DeltaHandler.closeOskViaDbus()
                    }
                }
            }
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
                //name: "media-skip-backward"
                source: "qrc:///assets/suru-icons/media-skip-backward.svg"
                width: units.gu(2.5)
                anchors {
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
                //name: "media-playback-start-rtl"
                source: "qrc:///assets/suru-icons/media-playback-start-rtl.svg"
                width: units.gu(2.5)
                anchors {
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
            fontSize: root.scaledFontSize
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
                //name: "media-playback-start"
                source: "qrc:///assets/suru-icons/media-playback-start.svg"
                width: units.gu(2.5)
                anchors {
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
                //name: "media-skip-forward"
                source: "qrc:///assets/suru-icons/media-skip-forward.svg"
                width: units.gu(2.5)
                anchors {
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
            //iconName: "delete"
            iconSource: "qrc:///assets/suru-icons/delete.svg"
            text: i18n.tr("Delete")
            onTriggered: {
                // the index is passed as parameter and can
                // be accessed via 'value'
                DeltaHandler.chatmodel.setMomentaryMessage(value)
                PopupUtils.open(Qt.resolvedUrl('ConfirmMsgDeletion.qml'))
            }
        }
    }

    ListItemActions {
        id: trailingInfoMsgActions
        actions: [
            Action {
                //iconName: "navigation-menu"
                iconSource: "qrc:///assets/suru-icons/navigation-menu.svg"
                text: i18n.tr("More Options")
                onTriggered: {
                    DeltaHandler.chatmodel.setMomentaryMessage(value)
                    PopupUtils.open(Qt.resolvedUrl('MessageInfosActions.qml'), chatViewPage, { "isInfoMsg": true })
                }
            }
        ]
    }

    ListItemActions {
        id: trailingMsgActions
        actions: [
            Action {
                //iconName: "mail-reply"
                iconSource: "qrc:///assets/suru-icons/mail-reply.svg"
                text: i18n.tr("Reply")
                onTriggered: {
                    DeltaHandler.chatmodel.setQuote(value)
                }
            },
            Action {
                //iconName: "navigation-menu"
                iconSource: "qrc:///assets/suru-icons/navigation-menu.svg"
                text: i18n.tr("More Options")
                onTriggered: {
                    DeltaHandler.chatmodel.setMomentaryMessage(value)
                    let popup6 = PopupUtils.open(Qt.resolvedUrl('MessageInfosActions.qml'))
                    popup6.startFileExport.connect(exportMomentaryMessageFile)
                }
            },
            Action {
                //iconName: "mail-forward"
                iconSource: "qrc:///assets/suru-icons/mail-forward.svg"
                text: i18n.tr("Forward")
                onTriggered: {
                    if (DeltaHandler.chatmodel.prepareForwarding(value)) {
                        extraStack.push(Qt.resolvedUrl('ForwardMessage.qml'))
                    }
                }
            }
        ]
    }

    ListView {
        id: view
        clip: true
        anchors.top: searchRect.visible ? searchRect.bottom : header.bottom
        topMargin: units.gu(1)
        width: parent.width
        height: chatlistPage.height - header.height - (searchRect.visible ? searchRect.height : 0) - units.gu(0.5) - (messageCreatorBox.visible ? messageCreatorBox.height + units.gu(1) : 0) - (contactRequestRect.visible ? contactRequestRect.height : 0) - (protectionBrokenBox.visible ? protectionBrokenBox.height : 0) - (cannotSendBox.visible ? cannotSendBox.height : 0)
        model: DeltaHandler.chatmodel
        //  Delegate inspired by FluffyChat (C) Christian Pauly,
        //  licensed under GPLv3
        //  https://gitlab.com/KrilleFear/fluffychat
        //  modified by (C) 2023 Lothar Ketterer
        delegate: ListItem {
                id: message

                property bool isUnreadMsgsBar: model.isUnreadMsgsBar
                property bool isInfoMsg: model.isInfo
                property bool isProtectionInfoMsg: model.isProtectionInfo
                property bool isSelf: model.isSelf && !(isUnreadMsgsBar || isInfoMsg)
                property bool isOther: !(isSelf || isUnreadMsgsBar || isInfoMsg)
                property bool isSameSenderAsNext: model.isSameSenderAsNextMsg
                property bool isSearchResult: model.isSearchResult
                property bool messageSeen: model.messageSeen
                property bool isPadlocked: model.hasPadlock
                property bool isDownloaded: model.isDownloaded
                property string msgtext: model.text
                property string quoteText: model.quotedText
                property bool hasQuote: quoteText != ""
                property string profPic: model.profilePic
                property int messageState: model.messageState
                property var msgViewType: model.msgViewType
                property bool unhandledType: {
                    switch (msgViewType) {
                        // fallthrough until false, enter any type
                        // that should not appear in uknownLoader
                        // to the cases that return false
                        case DeltaHandler.TextType:
                        case DeltaHandler.ImageType:
                        case DeltaHandler.GifType:
                        case DeltaHandler.StickerType:
                        case DeltaHandler.AudioType:
                        case DeltaHandler.VoiceType:
                        case DeltaHandler.VideoType:
                        case DeltaHandler.FileType:
                        case DeltaHandler.WebxdcType:
                            return false;
                            break;

                        default:
                            return true;
                            break;
                    }
                }
                property bool hasImageOrGif: msgViewType === DeltaHandler.ImageType || msgViewType === DeltaHandler.GifType || msgViewType === DeltaHandler.StickerType
                property var imageWidth: imageLoader.active ? imageLoader.width : (animatedImageLoader.active ? animatedImageLoader.width : 0)
                property var textColor: {
                    if (isSearchResult) {
                        return "black";
                    } else if (isInfo) {
                        if (root.darkmode) {
                            return "black";
                        } else {
                            return "white";
                        }
                    } else if (isSelf) {
                        if (messageSeen) {
                            return root.selfMessageSeenTextColor;
                        } else {
                            return root.selfMessageSentTextColor;
                        }
                    } else {
                        // valid for both messages from others and the unread message bar
                        return theme.palette.normal.foregroundText;
                    }
                }
                property var reactions: model.reactions
                property var webxdcInfo: (msgViewType === DeltaHandler.WebxdcType) ? JSON.parse(model.webxdcInfo) : null


                onPressAndHold: {
                    if (!isInfo && !isUnreadMsgsBar && chatCanSend) {
                        let popup1 = PopupUtils.open(Qt.resolvedUrl("ReactionsSelectionPopover.qml"), msgbox, {"reactions": reactions })
                        popup1.sendReactions.connect(reactionsLoader.sendReaction)
                    }
                }

                Component.onCompleted: {
                    // already called via onReactionsChanged, also on creation
                    //reactionsLoader.updateReactions()
                }

                onReactionsChanged: {
                    reactionsLoader.updateReactions()
                }

                width: view.width
                height: msgbox.height + (reactionsLoader.active ? (reactionsLoader.height - units.gu(0.2)) : 0) +  (imageLoader.active ? imageLoader.height : (animatedImageLoader.active ? animatedImageLoader.height : 0)) + (protectionIconLoader.active ? protectionIconLoader.height : 0)
                divider.visible: false

                // TODO: implement?
                //onPressAndHold: toast.show ( i18n.tr("Swipe to the left or the right for actions"))

                leadingActions: (isUnreadMsgsBar) ? null : leadingMsgAction
                trailingActions: (isUnreadMsgsBar) ? null : (isInfoMsg ? trailingInfoMsgActions : trailingMsgActions)

                Loader {
                    id: avatarLoader
                    active: isOther && !isSameSenderAsNext
                    height: width
                    width: units.gu(5.5)

                    anchors {
                        left: parent.left
                        leftMargin: units.gu(1)
                        bottom: msgbox.bottom
                    }

                    sourceComponent: LomiriShape {
                        id: avatarShape

                        backgroundColor: model.avatarColor
                        sourceFillMode: LomiriShape.PreserveAspectCrop

                        property bool hasProfPic: profPic != ""

                        source: hasProfPic ? avatarPic : undefined

                        Image {
                            id: avatarPic
                            visible: false
                            source: StandardPaths.locate(StandardPaths.AppConfigLocation, profPic)
                        }

                        Label {
                            id: avatarInitialLabel
                            text: model.avatarInitial
                            fontSize: "x-large" // leave this hardcoded
                            color: "white"
                            visible: !avatarShape.hasProfPic
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: extraStack.push(Qt.resolvedUrl("../pages/ProfileOther.qml"), { "contactID": model.contactID })
                        }
                    } // end LomiriShape id: avatarShape
                } // end Loader id: avatarLoader

                Loader {
                    id: imageLoader
                    active: msgViewType === DeltaHandler.ImageType

                    anchors {
                        right: isSelf ? msgbox.right : undefined
                        left: isOther ? msgbox.left : undefined
                        bottom: msgbox.top
                    }

                    sourceComponent: Image {
                        id: msgImage
                        source: StandardPaths.locate(StandardPaths.AppConfigLocation, model.filepath)
                        width: model.imagewidth > (chatViewPage.width - (isOther ? avatarLoader.width : 0) - units.gu(5)) ? (chatViewPage.width - (isOther ? avatarLoader.width : 0) - units.gu(5)) : (model.imagewidth < root.scaledFontSizeInPixels * 8 ? root.scaledFontSizeInPixels * 8 : model.imagewidth)
                        height: width * (model.imageheight / model.imagewidth)
                        fillMode: Image.PreserveAspectFit
                        autoTransform: true

                        MouseArea {
                            anchors.fill: parent
                            onClicked: imageStack.push(Qt.resolvedUrl("ImageViewer.qml"), { "imageSource": msgImage.source })
                        }
                    }
                }
                
                Loader {
                    id: animatedImageLoader
                    active: (msgViewType === DeltaHandler.GifType) || (msgViewType === DeltaHandler.StickerType)

                    anchors {
                        right: isSelf ? msgbox.right : undefined
                        left: isOther ? msgbox.left : undefined
                        bottom: msgbox.top
                    }

                    sourceComponent: AnimatedImage {
                        id: msgAnimatedImage
                        source: StandardPaths.locate(StandardPaths.AppConfigLocation, model.filepath)
                        width: model.imagewidth > (chatViewPage.width - (isOther ? avatarLoader.width : 0) - units.gu(5)) ? (chatViewPage.width - (isOther ? avatarLoader.width : 0) - units.gu(5)) : (model.imagewidth < root.scaledFontSizeInPixels * 8 ? root.scaledFontSizeInPixels * 8 : model.imagewidth)
                        height: width * (model.imageheight / model.imagewidth)
                        fillMode: Image.PreserveAspectFit
                        autoTransform: true
                        cache: false

                        MouseArea {
                            anchors.fill: parent
                            onClicked: imageStack.push(Qt.resolvedUrl("ImageViewerAnimated.qml"), { "imageSource": msgAnimatedImage.source })
                        }
                    }
                }

                Loader {
                    id: protectionIconLoader
                    active: isInfo && isProtectionInfoMsg
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: msgbox.top
                    }

                    sourceComponent: Rectangle {
                        height: units.gu(9) // one more than the image height
                        width: protectionImage.width
                        color: "transparent"

                            Image {
                            id: protectionImage
                            height: units.gu(8)

                            anchors {
                                bottom: parent.bottom
                                bottomMargin: units.gu(1)
                                verticalCenter: parent.verticalCenter
                            }

                            // TODO: assign empty image if neither InfoProtectionEnabled or InfoProtectionDisabled?
                            source: (DeltaHandler.InfoProtectionEnabled === model.protectionInfoType) ? Qt.resolvedUrl('../assets/verified.svg') : Qt.resolvedUrl('../assets/verified_broken.svg')
                            fillMode: Image.PreserveAspectFit

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    // TODO implement local help
                                    if (DeltaHandler.InfoProtectionEnabled === model.protectionInfoType) {
                                        let popup2 = PopupUtils.open(Qt.resolvedUrl('VerifiedPopup.qml'), chatViewPage, { "protectionEnabled": true })
                                        popup2.learnMore.connect(function() {
                                            Qt.openUrlExternally("https://delta.chat/en/help#e2eeguarantee")
                                        })
                                    } else {
                                        let popup3 = PopupUtils.open(Qt.resolvedUrl('VerifiedPopup.qml'), chatViewPage, { "protectionEnabled": false , "chatuser": chatname })
                                        popup3.scanQr.connect(closeAndStartQr)
                                        popup3.learnMore.connect(function() {
                                            Qt.openUrlExternally("https://delta.chat/en/help#nocryptanymore")
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
                
                LomiriShape {
                    id: msgbox

                    width: contentColumn.width + units.gu(2)
                    height: contentColumn.height  + units.gu(1.5)

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: reactionsLoader.active ? reactionsLoader.height - units.gu(0.2) : 0
                        right: !isOther ? parent.right : undefined
                        rightMargin: (isUnreadMsgsBar || isInfoMsg) ? ((chatViewPage.width - msgbox.width)/2) : units.gu(1)
                        left: isOther ? avatarLoader.right : undefined
                        leftMargin: isOther ? units.gu(1) : undefined
                    }

                    onWidthChanged: {
                        // Re-create the reactions below the message as the max number of
                        // reactions to show depends on the width of msgbox, and
                        // msgbox.width at the time of onCompleted is not final
                        // yet. In tests, the width changed four times until
                        // it reached its final value. It's costly ofc to re-calculate
                        // four times, but the only other way to add reactions against
                        // the final width of msgbox I can think of is a timer, which
                        // will bring its own overhead, and additionally introduces a
                        // visible delay in drawing of reactions.
                        if (reactionsLoader.active) {
                            reactionsLoader.updateReactions()
                        }
                    }

                    backgroundColor: {
                        if (isSearchResult) {
                            return root.searchResultMessageColor;
                        } else if (isOther) {
                            return root.otherMessageBackgroundColor;
                        } else if (isSelf) {
                            switch (messageState) {
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
                        } else if (isUnreadMsgsBar) {
                            return root.unreadMessageBarColor;
                        } else if (isInfoMsg) {
                            if (root.darkmode) {
                                return "#c0c0c0"; 
                            } else {
                                return "#505050";
                            }
                        }
                    }

                    backgroundMode: LomiriShape.SolidColor
                    aspect: LomiriShape.Flat
                    radius: "medium"

                    Loader {
                        id: squareCornerLoader
                        active: !isInfo && !isUnreadMsgsBar && !isSameSenderAsNext

                        anchors {
                            right: isSelf ? parent.right : undefined
                            left: isOther ? parent.left : undefined
                            bottom: parent.bottom
                        }

                        sourceComponent: Rectangle {
                            id: squareCornerBottom
                            height: units.gu(2)
                            width: units.gu(2)
                            color: msgbox.backgroundColor
                        }
                    }

                    Loader {
                        // removes the rounding of the top left corner
                        // in case an image is above the message bubble
                        id: squareCornerTopLeftLoader
                        // Always needed for left-sided messages. For right
                        // sided messages, it depends on whether the image
                        // is wider than the message bubble
                        active: hasImageOrGif && (isOther || imageWidth > msgbox.width)

                        anchors {
                            left: parent.left
                            top: parent.top
                        }

                        sourceComponent: Rectangle {
                            id: squareCornerTL
                            height: units.gu(2)
                            width: units.gu(2)
                            color: msgbox.backgroundColor
                        }
                    }

                    Loader {
                        // see squareCornerTopLeftLoader
                        id: squareCornerTopRightLoader
                        active: hasImageOrGif && (isSelf || imageWidth > msgbox.width)

                        anchors {
                            right: parent.right
                            top: parent.top
                        }

                        sourceComponent: Rectangle {
                            id: squareCornerTR
                            height: units.gu(2)
                            width: units.gu(2)
                            color: msgbox.backgroundColor
                        }
                    }

                    MouseArea {
                        // For info messages. If the message concerns protection
                        // status changes (enabled/disabled), clicks on the message
                        // bubble (and the icon above, see protectionIconLoader)
                        // opens an info popup.
                        // If it is not about protection status, C++ side will check
                        // whether it has a parent message of type webxdc. If yes,
                        // a jump to the parent is triggered in C++.
                        anchors.fill: parent
                        enabled: isInfoMsg
                        onClicked: {
                            // TODO implement local help
                            if (isProtectionInfoMsg && DeltaHandler.InfoProtectionEnabled === model.protectionInfoType) {
                                let popup2 = PopupUtils.open(Qt.resolvedUrl('VerifiedPopup.qml'), chatViewPage, { "protectionEnabled": true })
                                popup2.learnMore.connect(function() {
                                    Qt.openUrlExternally("https://delta.chat/en/help#e2eeguarantee")
                                })
                            } else if (isProtectionInfoMsg) {
                                let popup3 = PopupUtils.open(Qt.resolvedUrl('VerifiedPopup.qml'), chatViewPage, { "protectionEnabled": false , "chatuser": chatname })
                                popup3.scanQr.connect(closeAndStartQr)
                                popup3.learnMore.connect(function() {
                                    Qt.openUrlExternally("https://delta.chat/en/help#nocryptanymore")
                                })
                            } else {
                                DeltaHandler.chatmodel.checkAndJumpToWebxdcParent(index)
                            }
                        }
                    }

                    Column {
                        id: contentColumn
                        width: {
                            let a = msgLabel.contentWidth
                            let b = dateRowLoader.width
                            let c = forwardLabelLoader.width
                            let d = quoteLoader.width
                            let e = audioLoader.width
                            let f = fileLineLoader.width
                            let g = unknownTypeLoader.width
                            let h = toDownloadLoader.width
                            let i = htmlLoader.width
                            let j = webxdcLoader.width

                            let m = a > b ? a : b
                            let n = c > d ? c : d
                            let o = e > f ? e : f
                            let p = g > h ? g : h
                            let q = i > j ? i : j

                            let r = o > p ? o : p

                            let x = m > n ? m : n
                            let y = q > r ? q : r

                            return x > y ? x : y
                        }

                        anchors {
                            bottom: parent.bottom
                            bottomMargin: units.gu(0.5)
                            horizontalCenter: parent.horizontalCenter
                        }

                        spacing: units.gu(0.5)

                        Loader {
                            id: forwardLabelLoader
                            active: model.isForwarded

                            sourceComponent: Label {
                                id: forwardLabel
                                text: i18n.tr("Forwarded Message")
                                font.bold: true
                                color: textColor
                                fontSize: root.scaledFontSize
                            }
                        }

                        Loader {
                            id: quoteLoader
                            active: hasQuote

                            MouseArea {
                                id: msgJumpArea
                                anchors.fill: parent
                                onClicked: {
                                    DeltaHandler.chatmodel.initiateQuotedMsgJump(index)
                                }
                            }

                            sourceComponent: Row {
                                spacing: units.gu(1)

                                Rectangle {
                                    id: quoteRectangle
                                    width: units.gu(0.5)
                                    height: quoteUser.contentHeight + quoteLabel.contentHeight
                                    color: model.quoteAvatarColor != "" ? model.quoteAvatarColor : root.darkmode ? "white" : "black"
                                }

                                Column {
                                    id: quoteTextUserColumn
                                    width: quoteLabel.contentWidth > quoteUser.contentWidth ? quoteLabel.contentWidth : quoteUser.contentWidth

                                    Label {
                                        id: quoteLabel
                                        // TODO
                                        width: isOther ? chatViewPage.width - avatarLoader.width - units.gu(6.5) : chatViewPage.width - units.gu(6.5)
                                        anchors {
                                            left: parent.left
                                        }
                                        text: quoteText
                                        wrapMode: Text.Wrap
                                        color: textColor
                                        fontSize: root.scaledFontSize
            
                                    }
            
                                    Label {
                                        id: quoteUser
                                        anchors {
                                            left: parent.left
                                        }
            
                                        text: {
                                            if (model.quoteUser == "") {
                                                return i18n.tr("Unknown")
                                            } else {
                                                return model.quoteUser
                                            }
                                        }
            
                                        //fontSize: "x-small"
                                        fontSize: root.scaledFontSizeSmaller
                                        font.bold: true
                                        color: quoteRectangle.color
                                    }
                                }
                            }
                        }

                        Loader {
                            id: webxdcLoader
                            active: msgViewType === DeltaHandler.WebxdcType
                            sourceComponent: Column {

                                spacing: units.gu(0.25)

                                LomiriShape {
                                    width: root.scaledFontSizeInPixels * 10
                                    height: width
                                    backgroundColor: msgbox.backgroundColor
                                    sourceFillMode: LomiriShape.PreserveAspectFit

                                    source: Image {
                                        source: model.webxdcImage
                                    }
                                }

                                Label {
                                    id: webxdcNameLabel
                                    text: webxdcInfo.name
                                    wrapMode: Text.Wrap
                                    color: textColor
                                    fontSize: root.scaledFontSize
                                    font.bold: true
                                }

                                Label {
                                    id: webxdcSummaryLabel
                                    text: webxdcInfo.summary
                                    wrapMode: Text.Wrap
                                    color: textColor
                                    fontSize: root.scaledFontSizeSmaller
                                    visible: text !== ""
                                }

                                Rectangle {
                                    height: startWebxdcLabel.height + units.gu(1)
                                    width: startWebxdcLabel.contentWidth
                                    color: msgbox.color

                                    Label {
                                        id: startWebxdcLabel
                                            anchors {
                                                bottom: parent.bottom
                                                bottomMargin: units.gu(0.5)
                                            }
                                        width: isOther ? chatViewPage.width - avatarLoader.width - units.gu(5) : chatViewPage.width - units.gu(5)
                                        text: i18n.tr("Start…")
                                        fontSize: root.scaledFontSize
                                        color: msgLabel.linkColor
                                    }
                                
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (root.webxdcTestingEnabled) {
                                                DeltaHandler.chatmodel.setWebxdcInstance(index)
                                                let tempUsername = DeltaHandler.getCurrentUsername()
                                                let tempEmailAddr = DeltaHandler.getCurrentEmail()
                                                if (tempUsername == "") {
                                                    tempUsername = tempEmailAddr
                                                }
                                                extraStack.push(Qt.resolvedUrl("WebxdcPage.qml"), {
                                                    "headerTitle": webxdcInfo.name,
                                                    "username": tempUsername,
                                                    "useraddress": tempEmailAddr }
                                                )
                                            } else {
                                                PopupUtils.open(Qt.resolvedUrl("InfoPopup.qml"), chatViewPage, { "text": "Webxdc is not implemented yet, sorry" })
                                            }
                                        }
                                    }

                                }
                            }
                        }

                        Loader {
                            id: audioLoader
                            active: msgViewType === DeltaHandler.AudioType || msgViewType === DeltaHandler.VoiceType

                            sourceComponent: Row {
                                id: audioRow
                                spacing: units.gu(1)
                                width: playShape.width + units.gu(1) + playLabel.contentWidth

                                LomiriShape {
                                    id: playShape
                                    height: units.gu(4)
                                    width: height
                                    anchors.verticalCenter: parent.verticalCenter
                                    backgroundColor: "#F7F7F7"
                                    opacity: 0.5

                                    Icon {
                                        width: parent.width - units.gu(1)
                                        anchors.centerIn: parent
                                        //name: "media-playback-start"
                                        source: "qrc:///assets/suru-icons/media-playback-start.svg"
                                        color: textColor
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            // see properties of the Loader delegLoader
                                            playAudio(Qt.resolvedUrl(StandardPaths.locate(StandardPaths.CacheLocation, model.audiofilepath)))
                                        }
                                    }

                                }

                                Label {
                                    id: playLabel
                                    anchors.verticalCenter: playShape.verticalCenter
                                    // duration as queried via dc_msg_get_duration() is 0 in most cases, omit for now
                                    width: (isOther ? chatViewPage.width - avatarLoader.width - units.gu(5) : chatViewPage.width - units.gu(5)) - units.gu(5)
                                    text: (msgViewType === DeltaHandler.AudioType ? model.filename : i18n.tr("Voice Message"))// + " " + model.duration
                                    wrapMode: Text.Wrap
                                    color: textColor
                                    fontSize: root.scaledFontSize
                                }
                            }
                        }

                        Loader {
                            id: unknownTypeLoader
                            active: unhandledType && !isUnreadMsgsBar

                            sourceComponent: Label {
                                id: summaryLabel
                                width: isOther ? chatViewPage.width - avatarLoader.width - units.gu(5) : chatViewPage.width - units.gu(5)
                                text: model.summarytext
                                wrapMode: Text.Wrap
                                color: textColor //model.isSearchResult ? "black" : model.messageSeen ? root.selfMessageSeenTextColor : root.selfMessageSentTextColor
                                font.italic: true
                                fontSize: root.scaledFontSize
                            }

                        }

                        Loader {
                            id: fileLineLoader
                            active: msgViewType === DeltaHandler.FileType || msgViewType === DeltaHandler.VideoType

                            sourceComponent: Row {
                                id: fileRow
                                spacing: units.gu(1)
                                width: fileshape.width + units.gu(1) + fileLabel.contentWidth

                                LomiriShape {
                                    id: fileshape
                                    height: units.gu(4)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: height
                                    backgroundColor: "#F7F7F7"
                                    opacity: 0.5

                                    Icon {
                                        width: parent.width - units.gu(1)
                                        anchors.centerIn: parent
                                        //name: "attachment"
                                        source: "qrc:///assets/suru-icons/attachment.svg"
                                        color: textColor
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            DeltaHandler.chatmodel.setMomentaryMessage(index)
                                            exportMomentaryMessageFile()
                                        }
                                    }
                                }

                                Label {
                                    id: fileLabel
                                    anchors.verticalCenter: fileshape.verticalCenter
                                    width: (isOther ? chatViewPage.width - avatarLoader.width - units.gu(5) : chatViewPage.width - units.gu(5)) - units.gu(5)
                                    text: model.filename
                                    wrapMode: Text.Wrap
                                    color: textColor
                                    font.italic: true
                                    fontSize: root.scaledFontSize
                                }
                            }
                        }

                        Loader {
                            id: toDownloadLoader
                            active: !isDownloaded

                            // Only component of the Row is a Label. When
                            // using the Label directly, toDownloadLoader.width
                            // returns the width of the Label, not its contentWidth.
                            // I couldn't find a better solution than to use
                            // a layer for which the width is set to the contentWidth
                            // of the Label (couldn't access it in the Loader)
                            sourceComponent: Row {
                                id: toDownloadHelperRow
                                width: toDownloadLabel.contentWidth

                                Label {
                                    id: toDownloadLabel
                                    width: isOther ? chatViewPage.width - avatarLoader.width - units.gu(5) : (chatViewPage.width - units.gu(5))

                                    property var downloadState: model.downloadState

                                    text: {
                                        if (downloadState === DeltaHandler.DownloadAvailable) {
                                            return model.summarytext + " - <a href=\"%1\">%1</a>".arg(i18n.tr("Download"))
                                        } else if (downloadState === DeltaHandler.DownloadFailure) {
                                            return model.summarytext + " - <a href=\"%1\">%1</a>".arg(i18n.tr("Download failed"))
                                        } else if (downloadState === DeltaHandler.DownloadInProgress) {
                                            return model.summarytext + " - " + i18n.tr("Downloading…")
                                        } else if (downloadState === DeltaHandler.DownloadDone) {
                                            parent.visible = false
                                            return ""
                                        } else {
                                            console.log("ChatView.qml: Error: Unknown download state")
                                            return model.summarytext
                                        }
                                    }
                                    onLinkActivated: {
                                        // DeltaHandler.chatmodel.downloadFullMessage(index)
                                        let msgId = DeltaHandler.chatmodel.indexToMessageId(index)
                                        JSONRPC.client.downloadFullMessage(pageAccID, msgId)
                                            .catch(error => console.log("msg dl request failed:", error.message)) // to try the error handling use an invalid accountId or messageId
                                        
                                        linkColor = root.darkmode ? (model.messageSeen || isOther ? "#8080f7" : "#000055") : "#0000ff"
                                    }
                                    color: textColor
                                    linkColor: {
                                        if (downloadState === DeltaHandler.DownloadAvailable) {
                                            return root.darkmode ? (isOther ? "#aaaaf7" : (model.messageSeen ? "#bbbbf7" : "#0000aa")) : "#0000ff"
                                        } else if (downloadState === DeltaHandler.DownloadFailure) {
                                            return root.darkmode ? (isOther ? "#f7aaaa" : (model.messageSeen ? "#f78080" : "#aa0000")) : "#ff0000"
                                        } else if (downloadState === DeltaHandler.DownloadInProgress) {
                                            return root.darkmode ? (isOther ? "#aaaaff" : (model.messageSeen ? "#bbbbf7" : "#0000aa")) : "#0000ff"
                                        } else {
                                            return root.darkmode ? (isOther ? "#aaaaff" : (model.messageSeen ? "#bbbbf7" : "#0000aa")) : "#0000ff"
                                        }
                                    }
                                    wrapMode: Text.Wrap
                                    fontSize: root.scaledFontSize
                                }// end Label id: toDownloadLabel
                            } // Row id: toDownloadHelperRow
                        } // end Loader id: toDownloadLoader

                        Label {
                                id: msgLabel
                                width: isOther ? chatViewPage.width - avatarLoader.width - units.gu(5) : chatViewPage.width - units.gu(5)
                                 // TODO: this string has no translations ("Unread Messages")
                                text: isUnreadMsgsBar ? i18n.tr("Unread Messages") : msgtext
                                color: textColor
                                linkColor: isSearchResult ? "#0000ff" : (isOther ? root.otherMessageLinkColor : (messageSeen ? root.selfMessageSeenLinkColor : root.selfMessageSentLinkColor))

                                // Use Text.Wrap instead of Text.WordWrap,
                                // otherwise stuff like long links will
                                // extend the message bubble beyond the desired
                                // width and hide the text/link part that's off
                                // the screen
                                wrapMode: Text.Wrap 
                                onLinkActivated: Qt.openUrlExternally(link)
                                visible: isUnreadMsgsBar || (msgtext != "" && isDownloaded)
                                fontSize: root.scaledFontSize
                        }

                        Loader {
                            id: htmlLoader
                            active: model.hasHtml

                            sourceComponent: Rectangle {
                                height: getHtmlLabel.height + units.gu(2)
                                width: getHtmlLabel.contentWidth
                                color: msgbox.color

                                Label {
                                    id: getHtmlLabel
                                        anchors {
                                            bottom: parent.bottom
                                            bottomMargin: units.gu(0.5)
                                        }
                                    width: isOther ? chatViewPage.width - avatarLoader.width - units.gu(5) : chatViewPage.width - units.gu(5)
                                    text: i18n.tr("Show Full Message…")
                                    fontSize: root.scaledFontSize
                                    color: msgLabel.linkColor
                                }
                            
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        let urlpath = StandardPaths.locate(StandardPaths.CacheLocation, DeltaHandler.chatmodel.getHtmlMessage(index))

                                        let msgsubject = DeltaHandler.chatmodel.getHtmlMsgSubject(index)
                                        extraStack.push(Qt.resolvedUrl('MessageHtmlView.qml'), {"htmlPath": urlpath, "headerTitle": msgsubject, "overrideAndBlockAlwaysLoadRemote": ((protectionIsBroken || isContactRequest) && isOther)})
                                    }
                                }

                            }
                        }

                        Loader {
                            id: dateRowLoader
                            active: !isUnreadMsgsBar

                            anchors {
                                left: isOther ? parent.left : undefined
                                right: isSelf && !isInfoMsg && !isUnreadMsgsBar ? parent.right : undefined
                                horizontalCenter: isInfoMsg ? parent.horizontalCenter : undefined
                            }

                            sourceComponent: Row {
                                id: dateRow
                                spacing: units.gu(0.5)

                                Loader {
                                    id: padLockSelfLoader
                                    active: isSelf && isPadlocked && !isInfoMsg && !isUnreadMsgsBar
                                    anchors.verticalCenter: parent.verticalCenter

                                    sourceComponent: Icon {
                                        id: padlockSelf
                                        height: datelineIconSize
                                        width: height
                                        //name: "lock"
                                        source: "qrc:///assets/suru-icons/lock.svg"
                                        color: textColor
                                    }
                                }

                                Loader {
                                    id: usernameLoader
                                    active: isOther

                                    sourceComponent: Item {
                                        // have to put the label in an Item to set the width of the
                                        // loader to the contentWidth instead of the width of the
                                        // Label. Can't set it in Loader directly as this interacts
                                        // with the width of its sourceComponent.
                                        width: username.contentWidth
                                        height: username.height

                                        Label {
                                            id: username

                                            // Necessary to restrict the width of this label,
                                            // otherwise it will extend the message bubble beyond
                                            // the desired width.  datelineIconSize represents the
                                            // size of padlockOther
                                            width: chatViewPage.width - avatarLoader.width - msgDate.width - datelineIconSize - units.gu(7)
                                            text: model.username
                                            elide: Text.ElideRight
                                            fontSize: root.scaledFontSizeSmaller
                                            font.bold: true
                                            color: model.avatarColor
                                        }
                                    }
                                }

                                Label {
                                    id: msgDate
                                    color: textColor
                                    //fontSize: "x-small"
                                    fontSize: root.scaledFontSizeSmaller
                                    text: model.date
                                }

                                Loader {
                                    id: padlockOtherLoader
                                    active: isOther && isPadlocked
                                    anchors.verticalCenter: parent.verticalCenter

                                    sourceComponent: Icon {
                                        id: padlockOther
                                        height: datelineIconSize
                                        width: height
                                        //name: "lock"
                                        source: "qrc:///assets/suru-icons/lock.svg"
                                        color: textColor
                                    }
                                }

                                Loader {
                                    id: statusIconLoader
                                    active: isSelf && !isInfoMsg && !isUnreadMsgsBar

                                    anchors {
                                        bottom: parent.bottom
                                        bottomMargin: units.gu(0.15)
                                    }

                                    sourceComponent: Icon {
                                        height: datelineIconSize
                                        width: height * 2
                                        source: { 
                                            switch (messageState) {
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
                                    }
                                } // end Loader id: statusIconLoader
                            } // end Row id: dateRow
                        } // end Loader id: dateRowLoader
                    } // end Column id: contentColumn
                } // end LomiriShape id: msgbox

                Loader {
                    id: reactionsLoader
                    active: reactions.hasOwnProperty("reactions")

                    anchors {
                        bottom: parent.bottom
                        right: !isOther ? msgbox.right : undefined
                        rightMargin: !isOther ? units.gu(1) : undefined
                        left: isOther ? avatarLoader.right : undefined
                        leftMargin: isOther ? units.gu(2) : undefined
                    }

                    ListModel {
                        id: reactionsModel
                    }

                    function updateReactions() {
                        reactionsModel.clear()
                        if (reactions.hasOwnProperty("reactions")) {
                            let temparray = reactions.reactions

                            // I've found no way so far to interactively track the width of
                            // reactionsView while it is being build up. So it is estimated,
                            // see the comparison to msgbox.width below. To account for
                            // single reactions being wider when the count is displayed,
                            // noOfReactionsWithCountGt1 holds the number of reactions with a count > 1.
                            let noOfReactionsWithCountGt1 = 0

                            for (let i = 0; i < temparray.length; i++) {
                                let obj = temparray[i]

                                if (obj.count > 1) {
                                    noOfReactionsWithCountGt1++
                                }

                                if (i < 2) {
                                    // show at least
                                    // - three reactions or
                                    // - two reactions plus one with "..." if > 3 reactions
                                    reactionsModel.append( { reactEmoji: obj.emoji, reactCount: obj.count })

                                    // from the third reaction on, check against the width of the msgbox;
                                    // the calculation of the width of the reactionsView is just an
                                    // estimation as reactionsView.width seems to be of no use while building
                                    // up during this loop, see also comment for noOfReactionsWithCountGt1 above
                                } else if (msgbox.width < ( ((i+2) * 1.2 * (root.scaledFontSizeInPixels + units.gu(1))) + (noOfReactionsWithCountGt1 * (root.scaledFontSizeInPixels/2)) )) {
                                    if (temparray.length == (i+1) ) {
                                        reactionsModel.append( { reactEmoji: obj.emoji, reactCount: obj.count })
                                    } else {
                                        reactionsModel.append( { reactEmoji: "…", reactCount: 1 })
                                    }
                                    break;
                                } else {
                                    reactionsModel.append( { reactEmoji: obj.emoji, reactCount: obj.count })
                                }
                            }
                        }
                    }

                    function sendReaction(emojisToSend) {

                        let msgId = DeltaHandler.chatmodel.indexToMessageId(index)
                        JSONRPC.client.sendReaction(pageAccID, msgId, emojisToSend)
                            .catch(error => console.log("send reaction failed:", error.message))
                    }

                    sourceComponent: ListView {
                        id: reactionsView
                        height: root.scaledFontSizeInPixels + units.gu(1)
                        width: contentWidth

                        model: reactionsModel
                        orientation: ListView.Horizontal

                        delegate: LomiriShape {
                            id: reactionsDelegate
                            height: root.scaledFontSizeInPixels + units.gu(1)
                            width: reactionsLabel.contentWidth + units.gu(1)
                            backgroundColor: root.darkmode ? "#505050" : "white"
                            backgroundMode: LomiriShape.SolidColor
                            aspect: LomiriShape.DropShadow
                            radius: "large"

                            Label {
                                id: reactionsLabel
                                text: model.reactEmoji + (model.reactCount > 1 ? model.reactCount : "")
                                fontSize: root.scaledFontSize
                                color: root.darkmode ? "white" : "black"
                                anchors {
                                    horizontalCenter: parent.horizontalCenter
                                    verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: { 
                                    PopupUtils.open(Qt.resolvedUrl("ReactionsInfoPopup.qml"), chatViewPage, { "reactions": reactions })
                                }

                                onPressAndHold: {
                                    if (chatCanSend) {
                                        let popup1 = PopupUtils.open(Qt.resolvedUrl("ReactionsSelectionPopover.qml"), msgbox, {"reactions": reactions })
                                        popup1.sendReactions.connect(reactionsLoader.sendReaction)
                                    }
                                }

                            }
                        }
                    } // ListView id: reactionsView
                } // end Loader id: reactionsLoader
            } // end ListItem id: delegateListItem

        verticalLayoutDirection: ListView.BottomToTop
        spacing: units.gu(1)
        //cacheBuffer: 0

        Component.onCompleted: {
            if (DeltaHandler.chatmodel.getUnreadMessageBarIndex() > 0) {
                unreadJumpTimer.start()
            }
        }
    }

    LomiriShape {
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
                //name: "go-down"
                source: "qrc:///assets/suru-icons/go-down.svg"
                anchors {
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
    } // end LomiriShape id: toBottomButton

    Rectangle {
        id: cannotSendBox
        height: cannotSendLabel.contentHeight + units.gu(2)
        width: parent.width
        color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
        anchors {
            left: parent.left
            right: parent.right
            top: view.bottom
            topMargin: units.gu(1)
        }
        visible: !chatCanSend && !isContactRequest && !protectionIsBroken

        Label {
            id: cannotSendLabel
            width: cannotSendBox.width - units.gu(2)
            anchors {
                top: cannotSendBox.top
                topMargin: units.gu(1)
                left: cannotSendBox.left
                leftMargin: units.gu(1)
            }
            text: {
                if (DeltaHandler.chatmodel.chatIsDeviceTalk()) {
                    return i18n.tr("This chat contains locally generated messages; writing is disabled.")
                } else if (DeltaHandler.chatIsGroup(-1) && !DeltaHandler.chatmodel.selfIsInGroup()) {
                    return i18n.tr("You must be in this group to post a message. To join, ask another member.")
                } else {
                    return ""
                }
            }
            wrapMode: Text.WordWrap
            fontSize: root.scaledFontSize
        }
    } // end Rectangle id: cannotSendBox

    Rectangle {
        id: protectionBrokenBox
        height: protectionBrokenLabel.contentHeight + 2* acceptBrokenProtectionButton.height + units.gu(8)
        width: parent.width
        color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
        anchors {
            left: parent.left
            right: parent.right
            top: view.bottom
            topMargin: units.gu(1)
        }
        visible: !chatCanSend && protectionIsBroken

        Label {
            id: protectionBrokenLabel
            width: parent.width - units.gu(4)

            anchors {
                top: protectionBrokenBox.top
                topMargin: units.gu(2)
                left: parent.left
                leftMargin: units.gu(2)
            }

            text: i18n.tr("%1 sent a message from another device.").arg(chatname)
            wrapMode: Text.WordWrap
            fontSize: root.scaledFontSize
        }

        Button {
            id: acceptBrokenProtectionButton
            width: parent.width - units.gu(4)
            anchors {
                top: protectionBrokenLabel.bottom
                topMargin: units.gu(2)
                horizontalCenter: parent.horizontalCenter
            }
            text: i18n.tr('OK')
            font.pixelSize: root.scaledFontSizeInPixels
            color: theme.palette.normal.negative

            onClicked: {
                DeltaHandler.chatAccept()
            }
        }

        Button {
            id: protectionInfoButton
            width: parent.width - units.gu(4)
            anchors {
                top: acceptBrokenProtectionButton.bottom
                topMargin: units.gu(2)
                horizontalCenter: parent.horizontalCenter
            }
            text: i18n.tr('More Info')
            iconSource: root.darkmode ? "../assets/external-link-black.svg" : "../assets/external-link-white.svg"
            font.pixelSize: root.scaledFontSizeInPixels
            onClicked: {
                Qt.openUrlExternally("https://delta.chat/en/help#nocryptanymore")
            }
        }

    } // end Rectangle id: cannotSendBox

    Rectangle {
        id: messageCreatorBox
        height: messageEnterField.height + (quotedMessageBox.visible ? quotedMessageBox.height + units.gu(1) : 0) + (attachmentPreviewRect.visible ? attachmentPreviewRect.height + units.gu(1) : 0) 
        width: parent.width
        color: theme.palette.normal.background
        anchors {
            left: parent.left
            right: parent.right
            top: view.bottom
            topMargin: units.gu(1)
        }
        visible: !isContactRequest && chatCanSend

        Rectangle {
            id: quotedMessageBox
            height: cancelQuoteShape.height + units.gu(1) + quotedMessageLabel.contentHeight + units.gu(0.5) + quotedUser.contentHeight
            width: parent.width

            color: theme.palette.normal.background

            anchors {
                top: parent.top
                left: parent.left
            }
            visible: currentlyQuotingMessage

            Rectangle {
                id: quoteRectangle
                height: quotedUser.contentHeight + units.gu(0.5) + quotedMessageLabel.contentHeight
                width: units.gu(0.5)
                anchors {
                    bottom: parent.bottom
                    bottomMargin: units.gu(0.5)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                color: root.darkmode ? "white" : "black"
            }

            Label {
                id: quotedMessageLabel
                width: parent.width - units.gu(2) - quoteRectangle.width - units.gu(1) - units.gu(2)
                anchors { 
                    bottom: quotedUser.top
                    bottomMargin: units.gu(0.5)
                    left: quoteRectangle.left
                    leftMargin: units.gu(1)
                }
                maximumLineCount: 6
                //clip: true
                fontSize: root.scaledFontSize
            }

            Label {
                id: quotedUser
                width: parent.width - units.gu(2) - quoteRectangle.width - units.gu(1) - cancelQuoteShape.width - units.gu(1)
                anchors {
                    bottom: parent.bottom
                    bottomMargin: units.gu(0.5)
                    left: quoteRectangle.left
                    leftMargin: units.gu(1)
                }
                font.bold: true
                //fontSize: "x-small"
                fontSize: root.scaledFontSizeSmaller
            }

            LomiriShape {
                id: cancelQuoteShape
                width: units.gu(4)
                height: width
                color: theme.palette.normal.negative

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }

                Icon {
                    id: cancelQuoteIcon
                    width: parent.width - units.gu(1)
                    height: width
                    //name: "close"
                    source: "qrc:///assets/suru-icons/close.svg"
                    anchors {
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
            id: attachmentPreviewRect
            height: {
                let tempHeight
                if (attachAnimatedImagePreviewMode) {
                    tempHeight = attachPreviewAnimatedImage.height
                } else if (attachImagePreviewMode) {
                    tempHeight = attachPreviewAnimatedImage.height
                } else if (attachFilePreviewLabel.contentHeight > cancelAttachmentShape.height) {
                    tempHeight = attachFilePreviewLabel.contentHeight
                } else {
                    tempHeight = cancelAttachmentShape.height
                }
                return tempHeight + units.gu(1.5) + cancelAttachmentShape.height
            }
           // (attachImagePreviewMode ? attachPreviewImage.height : (attachFilePreviewLabel.contentHeight > cancelAttachmentShape.height ? attachFilePreviewLabel.contentHeight : cancelAttachmentShape.height) + units.gu(1.5)) + cancelAttachmentShape.height
            width: parent.width

            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
            //color: theme.palette.normal.background

            anchors {
                top: quotedMessageBox.visible ? quotedMessageBox.bottom : parent.top
                topMargin: quotedMessageBox.visible ? units.gu(1) : 0
                left: parent.left
            }

            visible: attachAnimatedImagePreviewMode || attachImagePreviewMode || attachFilePreviewMode || attachAudioPreviewMode || attachVoicePreviewMode

            Rectangle {
                id: attachVerticalCenterHelperRect
                height: parent.height - cancelAttachmentShape.height
                width: parent.width

                color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                }

                Icon {
                    id: attachFileIcon
                    height: cancelAttachmentShape.height
                    width: height
                    anchors {
                        verticalCenter: attachFilePreviewLabel.verticalCenter
                        left: parent.left
                        leftMargin: units.gu(1)
                    }
                    //name: "attachment"
                    source: "qrc:///assets/suru-icons/attachment.svg"
                    visible: attachFilePreviewMode
                }

                LomiriShape {
                    id: attachAudioShape
                    height: cancelAttachmentShape.height
                    width: height
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        leftMargin: units.gu(1)
                    }
                    visible: attachAudioPreviewMode || attachVoicePreviewMode
                    color: theme.palette.normal.background
                    aspect: LomiriShape.Inset

                    Icon {
                        id: attachAudioIcon
                        width: parent.width - units.gu(1)
                        height: width
                        anchors {
                            verticalCenter: parent.verticalCenter
                            horizontalCenter: parent.horizontalCenter
                        }
                        //name: "media-playback-start"
                        source: "qrc:///assets/suru-icons/media-playback-start.svg"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                playAudio(attachAudioPath)
                            }
                        }
                    }
                }

                Label {
                    id: attachFilePreviewLabel
                    width: chatViewPage.width - (attachAudioPreviewMode ? attachAudioShape.width : attachFileIcon.width) - units.gu(4)
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: attachFileIcon.right
                        leftMargin: units.gu(1)
                    }
                    //elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    visible: attachFilePreviewMode || attachAudioPreviewMode || attachVoicePreviewMode
                    fontSize: root.scaledFontSize
                }
            }

            AnimatedImage {
                id: attachPreviewAnimatedImage
                width: chatViewPage.width - units.gu(3)
                height: chatViewPage.height / 3
                // TODO: Doesn't work. That's the reason for
                // separating attachAnimatedImagePreviewMode and
                // attachImagePreviewMode, otherwise images
                // that should be rotated according to EXIF data
                // would not be rotated in the preview, but in the
                // chat after sending (or receiving).
                // Only using Image here isn't the solution either
                // as animated images would appear static.
                autoTransform: true

                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                visible: attachAnimatedImagePreviewMode
                fillMode: Image.PreserveAspectFit
            }

            Image {
                id: attachPreviewImage
                width: chatViewPage.width - units.gu(3)
                height: chatViewPage.height / 3
                autoTransform: true

                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                visible: attachImagePreviewMode
                fillMode: Image.PreserveAspectFit
            }

            LomiriShape {
                id: cancelAttachmentShape
                width: units.gu(4)
                height: width
                color: theme.palette.normal.negative

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                }

                Icon {
                    id: cancelAttachIcon
                    width: parent.width - units.gu(1)
                    height: width

                    // Voice messages are not recoverable, so they are
                    // deleted, whereas other stuff can still be
                    // obtained from its source (except for pics just
                    // taken by camera, but it's hard to check for this
                    // case)
                    //name: attachVoicePreviewMode ? "delete" : "close"
                    source: attachVoicePreviewMode ? "qrc:///assets/suru-icons/delete.svg" : "qrc:///assets/suru-icons/close.svg"
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            messageAudio.stop()
                            if (attachVoicePreviewMode) {
                                // actual deletion is done by the popup
                                PopupUtils.open(popoverComponentConfirmDeletion, cancelAttachmentShape)
                            } else {
                                // only ask for confirmation for voice messages as other
                                // attachments should be easily recoverable (except
                                // for pictures that were just taken, but well..)
                                DeltaHandler.chatmodel.unsetAttachment()
                                attachAnimatedImagePreviewMode = false
                                attachImagePreviewMode = false
                                attachFilePreviewMode = false
                                attachAudioPreviewMode = false
                            }
                        }
                    }
                }
            }
        } // end Rectangle id: attachmentPreviewRect

        LomiriShape{
            id: attachIconShape
            width: units.gu(4)
            height: width
            color: theme.palette.normal.overlay

            anchors {
                left: parent.left
                leftMargin: units.gu(0.5)
                verticalCenter: messageEnterField.verticalCenter
            }
            enabled: !(attachAnimatedImagePreviewMode || attachImagePreviewMode || attachFilePreviewMode || attachAudioPreviewMode || attachVoicePreviewMode)

            Icon {
                id: attachIcon
                width: parent.width - units.gu(1)
                height: width
                //name: attachmentMode ? "close" : "add"
                source: attachmentMode ? "qrc:///assets/suru-icons/close.svg" : "qrc:///assets/suru-icons/add.svg"
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        attachmentMode = !attachmentMode
                    }
                }
            }
        } // end LomiriShape id: attachIconShape
        
        TextArea {
            id: messageEnterField
            width: parent.width - attachIconShape.width - sendIconShape.width - units.gu(2)

            Keys.onPressed: {
                if ((event.key == Qt.Key_Return) && ((event.modifiers & Qt.ControlModifier) || root.enterKeySends)) {
                    event.accepted = true

                    if (((messageEnterField.displayText != "" && messageEnterField.displayText != "\n") || attachmentPreviewRect.visible) && !isRecording) {
                        // Without removing the focus from the TextArea,
                        // the text passed to DeltaHandler.sendMessage
                        // may be incomplete
                        messageEnterField.focus = false

                        attachAnimatedImagePreviewMode = false
                        attachImagePreviewMode = false
                        attachFilePreviewMode = false
                        attachAudioPreviewMode = false
                        attachVoicePreviewMode = false

                        // TODO for some reason, the Return makes it to text of the TextArea even
                        // though event.accepted is set to true. The '\n' is removed from the
                        // text on the C++ side; for this, cursorPosition has to be known.
                        DeltaHandler.chatmodel.sendMessage(messageEnterField.text, chatViewPage.pageAccID, chatViewPage.pageChatID, cursorPosition)

                        // TODO: is the comment below still correct?
                        // clear() does not work as we are using the TextArea
                        // from Lomiri.Components, not the one from
                        // QtQuickControls
                        //messageEnterField.clear()
                        messageEnterField.text = ""
                        messageEnterField.focus = true
                    }
                }
            }

            anchors {
                left: attachIconShape.right
                leftMargin: units.gu(0.5)
                top: attachmentPreviewRect.visible ? attachmentPreviewRect.bottom : (quotedMessageBox.visible ? quotedMessageBox.bottom : parent.top)
                topMargin: quotedMessageBox.visible || attachmentPreviewRect.visible ? units.gu(1) : 0
            }
            autoSize: true
            maximumLineCount: 5
            font.pixelSize: root.scaledFontSizeInPixels
            visible: !attachmentMode

            onFocusChanged: {
                if (root.oskViaDbus) {
                    if (focus) {
                        DeltaHandler.openOskViaDbus()
                    } else {
                        DeltaHandler.closeOskViaDbus()
                    }
                }
            }

            onDisplayTextChanged: {
                if (enterFieldChangeUpdatesDraft) {
                    DeltaHandler.chatmodel.setDraftText(displayText)
                }
            }
        }

        LomiriShape {
            id: sendIconShape
            width: units.gu(4)
            height: width
            color: theme.palette.normal.overlay
            anchors {
                right: parent.right
                rightMargin: units.gu(0.5)
                verticalCenter: messageEnterField.verticalCenter
            }
            visible: !attachmentMode

            Icon {
                id: sendIcon
                width: parent.width - units.gu(1)
                height: width
                //name: (messageEnterField.displayText == "" && !attachmentPreviewRect.visible) ? "audio-input-microphone-symbolic" : "send"
                source: (messageEnterField.displayText == "" && !attachmentPreviewRect.visible) ? "qrc:///assets/suru-icons/audio-input-microphone-symbolic.svg" : "qrc:///assets/suru-icons/send.svg"
                anchors {
                    verticalCenter: parent.verticalCenter
                    horizontalCenter: parent.horizontalCenter
                }
            } // end Icon id: sendIcon

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (messageEnterField.displayText == "" && !attachmentPreviewRect.visible) {
                        // currently showing the microphone icon => start voice message
                        // recording
                        messageAudio.stop()
                        attachmentMode = false
                        isRecording = true
                        let a = DeltaHandler.startAudioRecording(root.voiceMessageQuality)
                        recordingShapeLoader.active = true
                    } else {
                        // currently showing the send icon => send message
                        // 
                        // Without removing the focus from the TextArea,
                        // the text passed to DeltaHandler.sendMessage
                        // may be incomplete
                        messageEnterField.focus = false

                        attachAnimatedImagePreviewMode = false
                        attachImagePreviewMode = false
                        attachFilePreviewMode = false
                        attachAudioPreviewMode = false
                        attachVoicePreviewMode = false

                        DeltaHandler.chatmodel.sendMessage(messageEnterField.text, chatViewPage.pageAccID, chatViewPage.pageChatID)

                        // TODO: is the comment below still correct?
                        // clear() does not work as we are using the TextArea
                        // from Lomiri.Components, not the one from
                        // QtQuickControls
                        //messageEnterField.clear()
                        messageEnterField.text = ""
                        messageEnterField.focus = true
                    }
                }
            }
        } // end LomiriShape id: sendIconShape


        Rectangle {
            id: filetypeToSendCage
            height: messageEnterField.height
            width: (sendImageIconShape.width + units.gu(2))*3
            anchors {
                right: messageCreatorBox.right
                rightMargin: units.gu(1)
                top: quotedMessageBox.visible ? quotedMessageBox.bottom : parent.top
                topMargin: quotedMessageBox.visible ? units.gu(1) : 0
            }

            color: theme.palette.normal.background

            visible: attachmentMode

            LomiriShape {
                id: sendImageIconShape
                width: units.gu(4)
                height: width
                color: theme.palette.normal.overlay

                anchors {
                    right: filetypeToSendCage.right
                    verticalCenter: parent.verticalCenter
                }

                function attachImage(imagePath) {
                    if (DeltaHandler.chatmodel.isGif(imagePath)) {
                        DeltaHandler.chatmodel.setAttachment(imagePath, DeltaHandler.GifType)
                    } else {
                        DeltaHandler.chatmodel.setAttachment(imagePath, DeltaHandler.ImageType)
                    }
                }

                Icon {
                    id: imageIcon
                    width: parent.width - units.gu(1)
                    height: width
                    //name: "stock_image"
                    source: "qrc:///assets/suru-icons/stock_image.svg"
                    anchors {
                        horizontalCenter: sendImageIconShape.horizontalCenter
                        verticalCenter: sendImageIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.onUbuntuTouch) {
                                DeltaHandler.newFileImportSignalHelper()
                                DeltaHandler.fileImportSignalHelper.fileImported.connect(sendImageIconShape.attachImage)
                                extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })
                                // See comments in CreateOrEditGroup.qml
                                //let incubator = layout.addPageToCurrentColumn(chatViewPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })

                                //if (incubator.status != Component.Ready) {
                                //    // have to wait for the object to be ready to connect to the signal,
                                //    // see documentation on AdaptivePageLayout and
                                //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                                //    incubator.onStatusChanged = function(status) {
                                //        if (status == Component.Ready) {
                                //            incubator.object.fileSelected.connect(sendImageIconShape.attachImage)
                                //        }
                                //    }
                                //} else {
                                //    // object was directly ready
                                //    incubator.object.fileSelected.connect(sendImageIconShape.attachImage)
                                //}
                            } else {
                                picImportLoader.source = "FileImportDialog.qml"
                                picImportLoader.item.setFileType(DeltaHandler.ImageType)
                                picImportLoader.item.open()
                            }

                            attachmentMode = false
                        }
                        enabled: true
                    }

                    Loader {
                        id: picImportLoader
                    }

                    Connections {
                        target: picImportLoader.item
                        onFileSelected: {
                            sendImageIconShape.attachImage(urlOfFile)
                            picImportLoader.source = ""
                        }
                        onCancelled: {
                            picImportLoader.source = ""
                        }
                    }
                }
            } // end LomiriShape id: sendImageIconShape

            LomiriShape {
                id: sendAudioIconShape
                width: units.gu(4)
                height: width
                color: theme.palette.normal.overlay

                anchors {
                    right: sendImageIconShape.left
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                Icon {
                    id: audioIcon
                    width: parent.width - units.gu(1)
                    height: width
                    //name: "stock_music"
                    source: "qrc:///assets/suru-icons/stock_music.svg"
                    anchors {
                        horizontalCenter: sendAudioIconShape.horizontalCenter
                        verticalCenter: sendAudioIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.onUbuntuTouch) {
                                DeltaHandler.newFileImportSignalHelper()
                                DeltaHandler.fileImportSignalHelper.fileImported.connect(function(fileUrl) {
                                    DeltaHandler.chatmodel.setAttachment(fileUrl, DeltaHandler.AudioType)
                                } )
                                extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.AudioType })
                                // See comments in CreateOrEditGroup.qml
                                //let incubator = layout.addPageToCurrentColumn(chatViewPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.AudioType })

                                //if (incubator.status != Component.Ready) {
                                //    // have to wait for the object to be ready to connect to the signal,
                                //    // see documentation on AdaptivePageLayout and
                                //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                                //    incubator.onStatusChanged = function(status) {
                                //        if (status == Component.Ready) {
                                //            incubator.object.fileSelected.connect(function(fileUrl) {
                                //                DeltaHandler.chatmodel.setAttachment(fileUrl, DeltaHandler.AudioType)
                                //            } )
                                //        }
                                //    }
                                //} else {
                                //    // object was directly ready
                                //    incubator.object.fileSelected.connect(function(fileUrl) {
                                //        DeltaHandler.chatmodel.setAttachment(fileUrl, DeltaHandler.AudioType)
                                //    } )
                                //}
                            } else {
                                audioImportLoader.source = "FileImportDialog.qml"
                                audioImportLoader.item.setFileType(DeltaHandler.AudioType)
                                audioImportLoader.item.open()
                            }

                            attachmentMode = false
                        }
                        enabled: true
                    } // MouseArea

                    Loader {
                        id: audioImportLoader
                    }

                    Connections {
                        target: audioImportLoader.item
                        onFileSelected: {
                            DeltaHandler.chatmodel.setAttachment(urlOfFile, DeltaHandler.AudioType)
                            audioImportLoader.source = ""
                        }
                        onCancelled: {
                            audioImportLoader.source = ""
                        }
                    }
                } // Icon id: audioIcon
            } // end LomiriShape id: sendAudioIconShape

            LomiriShape {
                id: sendFileIconShape
                width: units.gu(4)
                height: width
                color: theme.palette.normal.overlay

                anchors {
                    right: sendAudioIconShape.left
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                Icon {
                    id: attachmentIcon
                    width: parent.width - units.gu(1)
                    height: width
                    //name: "attachment"
                    source: "qrc:///assets/suru-icons/attachment.svg"
                    anchors {
                        horizontalCenter: sendFileIconShape.horizontalCenter
                        verticalCenter: sendFileIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.onUbuntuTouch) {
                                DeltaHandler.newFileImportSignalHelper()
                                DeltaHandler.fileImportSignalHelper.fileImported.connect(function(fileUrl) {
                                    DeltaHandler.chatmodel.setAttachment(fileUrl, DeltaHandler.FileType)
                                } )
                                extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.FileType })
                                // See comments in CreateOrEditGroup.qml
                                //let incubator = layout.addPageToCurrentColumn(chatViewPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.FileType })

                                //if (incubator.status != Component.Ready) {
                                //    // have to wait for the object to be ready to connect to the signal,
                                //    // see documentation on AdaptivePageLayout and
                                //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                                //    incubator.onStatusChanged = function(status) {
                                //        if (status == Component.Ready) {
                                //            incubator.object.fileSelected.connect(function(fileUrl) {
                                //                DeltaHandler.chatmodel.setAttachment(fileUrl, DeltaHandler.FileType)
                                //            } )
                                //        }
                                //    }
                                //} else {
                                //    // object was directly ready
                                //    incubator.object.fileSelected.connect(function(fileUrl) {
                                //        DeltaHandler.chatmodel.setAttachment(fileUrl, DeltaHandler.FileType)
                                //    } )
                                //}
                            } else {
                                fileImportLoader.source = "FileImportDialog.qml"
                                fileImportLoader.item.setFileType(DeltaHandler.FileType)
                                fileImportLoader.item.open()
                            }

                            attachmentMode = false
                        }
                        enabled: true
                    }

                    Loader {
                        id: fileImportLoader
                    }

                    Connections {
                        target: fileImportLoader.item
                        onFileSelected: {
                            DeltaHandler.chatmodel.setAttachment(urlOfFile, DeltaHandler.FileType)
                            fileImportLoader.source = ""
                        }
                        onCancelled: {
                            fileImportLoader.source = ""
                        }
                    }
                } // Icon id: attachmentIcon
            } // end LomiriShape id: sendFileIconShape

            LomiriShape {
                id: voiceMessageIconShape
                width: units.gu(4)
                height: width
                color: theme.palette.normal.overlay

                anchors {
                    right: sendFileIconShape.left
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                Icon{
                    id: voiceMessageIcon
                    width: parent.width - units.gu(1)
                    height: width
                    //name: "audio-input-microphone-symbolic"
                    source: "qrc:///assets/suru-icons/audio-input-microphone-symbolic.svg"
                    anchors {
                        horizontalCenter: voiceMessageIconShape.horizontalCenter
                        verticalCenter: voiceMessageIconShape.verticalCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            messageAudio.stop()
                            attachmentMode = false
                            let a = DeltaHandler.startAudioRecording(root.voiceMessageQuality)
                            recordingShapeLoader.active = true
                            isRecording = true
                        }
                        enabled: true
                    }
                }
            } // end LomiriShape id: voiceMessageIconShape
        } // end Rectangle id: filetypeToSendCage
        

        Loader {
            id: recordingShapeLoader
            active: false
            visible: isRecording

            anchors {
                bottom: messageCreatorBox.top
                bottomMargin: units.gu(10)
                horizontalCenter: parent.horizontalCenter
            }

            sourceComponent: LomiriShape {
                id: recordingShape

                height: units.gu(20)
                width: units.gu(10)

                color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                LomiriShape {
                    id: recordingBackground
                    height: units.gu(10)
                    width: units.gu(10)

                    anchors {
                        top: parent.top
                        left: parent.left
                    }

                    color: root.darkmode ? "white" : "black"
                }

                Icon {
                    id: floatingRecIcon

                    width: parent.width - units.gu(2)
                    height: width
                    //name: "media-record"
                    source: "qrc:///assets/suru-icons/media-record.svg"

                    anchors {
                        top: parent.top
                        topMargin: units.gu(1)
                        left: parent.left
                        leftMargin: units.gu(1)
                    }

                    SequentialAnimation {
                        loops: Animation.Infinite
                        running: true
                        PropertyAnimation {
                            target: recordingBackground
                            property: "opacity"
                            to: 1
                            duration: 1000
                        }
                        PropertyAnimation {
                            target: recordingBackground
                            property: "opacity"
                            to: 0.3
                            duration: 1000
                        }
                    }
                }

                Icon {
                    width: parent.width - units.gu(2)
                    height: width
                    //name: "media-playback-stop"
                    source: "qrc:///assets/suru-icons/media-playback-stop.svg"

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: units.gu(1)
                        left: parent.left
                        leftMargin: units.gu(1)
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        DeltaHandler.stopAudioRecording()
                        isRecording = false
                    }
                }
            } // end LomiriShape id: recordingShape
        }
    } // end Rectangle id: messageCreatorBox


    Rectangle {
        id: contactRequestRect
        height: 3* acceptRequestButton.height + units.gu(8)
        width: parent.width
        color: theme.palette.normal.background
        anchors {
            left: parent.left
            right: parent.right
            top: view.bottom
            topMargin: units.gu(1)
        }
        visible: isContactRequest

        Button {
            id: acceptRequestButton
            width: parent.width - units.gu(4)
            anchors {
                top: contactRequestRect.top
                topMargin: units.gu(2)
                horizontalCenter: parent.horizontalCenter
            }
            text: i18n.tr('Accept')
            font.pixelSize: root.scaledFontSizeInPixels
            color: theme.palette.normal.positive

            onClicked: {
                DeltaHandler.chatAccept()
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
            font.pixelSize: root.scaledFontSizeInPixels
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
            font.pixelSize: root.scaledFontSizeInPixels
            onClicked: {
                DeltaHandler.chatBlockContactRequest()
                layout.removePages(chatViewPage)
            }
        }

    } // end Rectangle id: contactRequestRect

    Loader {
        id: audioPlayLoader
        active: false
        visible: messageAudio.playbackState === Audio.PlayingState || messageAudio.playbackState === Audio.PausedState

        anchors {
            top: header.bottom
            topMargin: units.gu(2)
            horizontalCenter: chatViewPage.horizontalCenter
        }

        function startPlaying(sourceUrl) {
            messageAudio.stop()
            messageAudio.source = sourceUrl
            messageAudio.play()
        }

        Audio {
            id: messageAudio
        }

        sourceComponent: LomiriShape {
            id: audioPlayerShape
            height: units.gu(5)
            width: units.gu(1) + audioPlayIcon.width + units.gu(1) + audioStopIcon.width + units.gu(1) + durationLabel.contentWidth + units.gu(1)

            backgroundColor: root.darkmode ? "white" : "black"

            Icon {
                id: audioPlayIcon
                height: units.gu(4)
                anchors {
                    left: audioPlayerShape.left
                    leftMargin: units.gu(1)
                    verticalCenter: audioPlayerShape.verticalCenter
                }
                //name: messageAudio.playbackState === Audio.PlayingState ? "media-playback-pause" : "media-playback-start"
                source: messageAudio.playbackState === Audio.PlayingState ? "qrc:///assets/suru-icons/media-playback-pause.svg" : "qrc:///assets/suru-icons/media-playback-start.svg"

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
                //name: "media-playback-stop"
                source: "qrc:///assets/suru-icons/media-playback-stop.svg"

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
                fontSize: root.scaledFontSize
            }
        } // end LomiriShape id: audioPlayerShape
    } // end Loader id: audioPlayLoader


    Timer {
        id: unreadJumpTimer
        interval: 500
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            view.positionViewAtIndex(DeltaHandler.chatmodel.getUnreadMessageBarIndex(), ListView.End)
        }
    }

    Timer {
        id: leaveTimer
        interval: 100
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            layout.removePages(chatViewPage)
        }
    }

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
                    // Lomiri.Components.Themes 1.3 doesn't solve it). 
                    color: theme.palette.normal.focus
                    ListItemLayout {
                        id: layout1
                        title.text: i18n.tr("Delete")
                        title.font.pixelSize: scaledFontSizeInPixels
                        title.color: root.darkmode ? "black" : "white"
                    }
                    onClicked: {
                        if (messageAudio.source == attachAudioPath) {
                            messageAudio.stop()
                        }

                        if (attachVoicePreviewMode) {
                            DeltaHandler.dismissAudioRecording()
                            DeltaHandler.chatmodel.unsetAttachment()
                            attachVoicePreviewMode = false
                        } else {
                            DeltaHandler.chatmodel.unsetAttachment()
                            attachAnimatedImagePreviewMode = false
                            attachImagePreviewMode = false
                            attachFilePreviewMode = false
                            attachAudioPreviewMode = false
                        }

                        PopupUtils.close(popoverConfirmDeletion)
                    }
                }
            }
        }
    } // end Component id: popoverComponentConfirmDeletion

// PinchHandler currently taken out due to incompatibility with ListItem
//
//    // Taken from from Messaging-App Copyright 2012-2016 Canonical Ltd.,
//    // licensed under GPLv3
//    // https://gitlab.com/ubports/development/core/messaging-app/-/blob/62f448f8a5bec59d8e5c3f7bf386d6d61f9a1615/src/qml/Messages.qml
//    // modified by (C) 2023 Lothar Ketterer
//    PinchHandler {
//        id: pinchHandlerChatView
//        target: null
//
//        minimumPointCount: 2
//
//        property real previousScale: 1.0
//        property real zoomThreshold: 0.5
//
//        onScaleChanged: {
//            var nextLevel = root.scaleLevel
//
//            if (activeScale > previousScale + zoomThreshold && nextLevel < root.maximumScale) { // zoom in
//                nextLevel++
//            // nextLevel > 1 (instead of > 0) so the main scaleLevel cannot go below "small"
//            } else if (activeScale < previousScale - zoomThreshold && nextLevel > 1) { // zoom out
//                nextLevel--
//            }
//
//            if (nextLevel !== root.scaleLevel) {
//
//                root.scaleLevel = nextLevel
//
//                // Ugly hack for the TextArea to correctly resize. If this is
//                // not applied, the font will resize directly, but the item
//                // height will only resize after a line will be added or
//                // removed.  If going from small to large text, the text will
//                // be partly hidden until resizing the item height.
//                let tempMsgTxt = messageEnterField.text
//                messageEnterField.text = "b\nb"
//                messageEnterField.text = tempMsgTxt
//
//
////                 // get the index of the current drag item if any and make ListView follow it
////                var positionInRoot = mapToItem(view.contentItem, centroid.position.x, centroid.position.y)
////                const currentIndex = view.indexAt(positionInRoot.x,positionInRoot.y)
////
////                view.positionViewAtIndex(currentIndex, ListView.Visible)
//
//                previousScale = activeScale
//            }
//        }
//
//        onActiveChanged: {
//            if (active) {
//                previousScale = 1.0
//                view.currentIndex = -1
//            }
//        }
//    }
} // end Page id: chatViewPage
