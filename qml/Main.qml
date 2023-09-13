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
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import Lomiri.Connectivity 1.0

import DeltaHandler 1.0
import "pages"

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'deltatouch.lotharketterer'
    automaticOrientation: true
    anchorToKeyboard: true

    signal appStateNowActive()

    // see periodicTimer
    signal periodicTimerSignal()

    signal chatlistQueryTextHasChanged(string query)

    function clearChatlistQuery() {
        chatlistSearchField.text = "";
    }

    property string appName: i18n.tr('DeltaTouch')
    property string version: '1.1.1'
    property string oldVersion: "unknown"

    // Color scheme
    //
    // The bool darkmode will be set in onCompleted. If it is set here
    // (i.e., with binding) it will change if the theme is changed by,
    // e.g., ThemeSwitcher, and all colors depending on it will change,
    // too. For some strange reason, the UITK components don't do the
    // live switching (at least in xenial), so there would be a
    // mismatch.
    // Trying to set theme.name or Theme.name in onStateChanged resulted
    // in darkmode not doing the live switch instead of UITK doing it as
    // well??
    property bool darkmode
    property string otherMessageBackgroundColor: root.darkmode ? "#3b3b3b" : "#e9e9e9"
    property string selfMessagePendingBackgroundColor: root.darkmode ? "#86d3db" : "#f0fafb"
    property string selfMessageSentBackgroundColor: root.darkmode ? "#0dbece" : "#cbecf0" //"#0ca7b6" : "#cbecf0"
    property string selfMessageSeenBackgroundColor: root.darkmode ? "#06545b" : "#2bb2c0"
    property string selfMessageSentTextColor: root.darkmode ? "black" : "black"
    property string selfMessageSeenTextColor: root.darkmode ? "white" : "black"
    property string unreadMessageCounterColor: "#053f45"
    property string unreadMessageBarColor: root.darkmode ? "#000080" : "#968cd9"
    property string searchResultMessageColor: "#d55e00"
    property string dtLinkColor: root.darkmode ? "#8888ff" : "#0000ff"
    property string otherMessageLinkColor: root.darkmode ? "#ccccff" : "#0000ff"
    property string selfMessageSentLinkColor: root.darkmode ? "#0000aa" : "#0000c2"
    property string selfMessageSeenLinkColor: root.darkmode ? "#b8b8ff" : "#0000BB"


    // If there are any archived chats, a pseudo-chat "Archived Chats" will
    // be shown in the list of chats. When clicked, only the archived chats
    // are shown. To get back to the list of normal (i.e., un-archived) chats,
    // an extra item will be shown at the top of the chat list.
    property bool showArchiveCloseLine: false

    // Comment and property isDesktopMode taken from Lomiri Weather
    // App, Copyright (C) 2015 Canonical Ltd, licensed via GPLv3:
    // "When the app is started with clickable desktop, the check for network
    // connection via Connectivity does not work.
    // If the app is run in desktop mode, set this property to 'true' and the
    // check will be disabled."
    property bool isDesktopMode: false

    // Will connect to the network if true. Offline mode if
    // set to false. Connected to the "Sync all" switch
    // in the Settings page. Setting takes effect on all
    // accounts, i.e., it is not account (context) specific.
    property bool syncAll: true

    property bool showBottomEdgeHint: true

    property int voiceMessageQuality: DeltaHandler.BalancedRecordingQuality

    property bool sendPushNotifications: false
    property bool detailedPushNotifications: true
    property bool aggregatePushNotifications: false

    // to protect against clicks on multiple chat lines
    property bool chatOpenAlreadyClicked: false

    Settings {
        id: settings
        property alias synca: root.syncAll
        property alias voiceMessQual: root.voiceMessageQuality
        property alias sendPushNotif: root.sendPushNotifications
        property alias detailedPushNotif: root.detailedPushNotifications
        property alias aggregatePushNotif: root.aggregatePushNotifications
        property alias versionAtLastSession: root.oldVersion
    }

    width: units.gu(45)
    height: units.gu(75)

    function startStopIO() {
        if (DeltaHandler.networkingIsStarted) { // network is up, check if it needs to be stopped
            //if (Qt.application.state != Qt.ApplicationActive || !DeltaHandler.networkingIsAllowed || !DeltaHandler.hasConfiguredAccount || !(Connectivity.online || isDesktopMode) || !root.syncAll) {
            if (!DeltaHandler.networkingIsAllowed || !DeltaHandler.hasConfiguredAccount || !(Connectivity.online || isDesktopMode) || !root.syncAll) {
                DeltaHandler.stop_io();
                console.log('startStopIO(): network is currently up, calling stop_io()')
            }
            else {
                console.log('startStopIO(): network is up, doing nothing')
            }
        }
        else { // network is down, check if it can be brought up
            //if (Qt.application.state == Qt.ApplicationActive && DeltaHandler.networkingIsAllowed && DeltaHandler.hasConfiguredAccount && (Connectivity.online || isDesktopMode) && root.syncAll) {
            if (DeltaHandler.networkingIsAllowed && DeltaHandler.hasConfiguredAccount && (Connectivity.online || isDesktopMode) && root.syncAll) {
                DeltaHandler.start_io()
                console.log('startStopIO(): network is currently down, calling start_io()')
            }
            else {
                console.log('startStopIO(): network is down, doing nothing')
            }
        }
    }

    Connections {
        target: Connectivity
        onOnlineChanged: {
            startStopIO()
            console.log('connectivity signal onlineChanged')
        }
    }
    
    Connections {
        target: DeltaHandler
        onChatViewClosed: {
            root.chatOpenAlreadyClicked = false;
        }
    }

    Connections {
        target: DeltaHandler
        onHasConfiguredAccountChanged: {
            startStopIO()
            console.log('DeltaHandler signal hasConfiguredAccountChanged')
        }
    }

    Connections {
        target: DeltaHandler
        onNetworkingIsAllowedChanged: {
            startStopIO()
            console.log('DeltaHandler signal networkingIsAllowedChanged')
        }
    }

    Connections {
        target: Qt.application
        onStateChanged: {
            startStopIO()
            let currState;
            // see Qt::ApplicationState
            if (Qt.application.state == Qt.ApplicationActive) {
                currState = "ApplicationActive"
                appStateNowActive()
                periodicTimerSignal()
                periodicTimer.start()
            } else if (Qt.application.state == Qt.ApplicationSuspended) {
                currState = "ApplicationSuspended"
                periodicTimer.stop()
            } else if (Qt.application.state == Qt.ApplicationHidden) {
                currState = "ApplicationHidden"
                periodicTimer.stop()
            } else if (Qt.application.state == Qt.ApplicationInactive) {
                currState = "ApplicationInactive"
                periodicTimer.stop()
            } else {
                currState = "Unknown state " + Qt.application.state
                periodicTimer.stop()
            }
            console.log('Qt.application signal stateChanged, state is now: ' + currState)
        }
    }

    Connections {
        target: DeltaHandler
        onChatlistShowsArchivedOnly: {
            showArchiveCloseLine = showsArchived;
            root.chatOpenAlreadyClicked = false
        }
    }

    Connections {
        target: DeltaHandler.contactsmodel
        onChatCreationSuccess: {
            bottomEdge.collapse()
        }
    }

    Connections {
        target: DeltaHandler
        onOpenChatViewRequest: {
            layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/ChatView.qml'))
        }
    }

    AdaptivePageLayout {
        id: layout
        anchors.fill: parent
        layouts: [
            PageColumnsLayout {
                when: width > units.gu(100)
                // column #0
                PageColumn {
                    minimumWidth: units.gu(45)
                    preferredWidth: units.gu(70)
                    maximumWidth: units.gu(70)
                }
                // column #1
                PageColumn {
                    fillWidth: true
                }
            },
            // only one column if width <= units.gu(100)
            PageColumnsLayout {
                when: true
                PageColumn {
                    fillWidth: true
                }
            }
        ]
        primaryPage: Page {
            id: chatlistPage
            anchors.fill: parent

            /* ========================== HEADER ===========================
             * creating a custom header as PageHeader doesn't suit our needs
             * ============================================================= */
            header: Rectangle {
                id: headerRect
                height: units.gu(6) + (chatlistSearchField.visible ? units.gu(1) + chatlistSearchField.height + units.gu(1) + dividerItem.height : 0)
                width: chatlistPage.width
                anchors {
                    left: chatlistPage.left
                    right: chatlistPage.right
                    top: chatlistPage.top
                }

                color: theme.palette.normal.background

                Rectangle {

                    // introduced to set the background color of top
                    // part of the header, but not the background of the
                    // search bar
                    id: headerTopBackgroundColor
                    height: units.gu(6)
                    width: headerRect.width
                    anchors {
                        top: headerRect.top
                        left: headerRect.left
                    }
                    color: "#053f45" //"#06545b" //"#032c30" //"#0ca7b6"
                }

                //opacity: 0.5
            
                // TODO should these be properties?
                property string currentUsername: DeltaHandler.hasConfiguredAccount ? (DeltaHandler.getCurrentUsername() == "" ? i18n.tr("no username set") : DeltaHandler.getCurrentUsername()) : i18n.tr("No account configured")
                property string currentEmail: DeltaHandler.hasConfiguredAccount ? DeltaHandler.getCurrentEmail() : i18n.tr("Click Settings to manage accounts")
                property string currentProfilePic: DeltaHandler.getCurrentProfilePic() == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())

                Connections {
                    target: DeltaHandler
                    onAccountChanged: {
                        headerRect.currentUsername = DeltaHandler.hasConfiguredAccount ? (DeltaHandler.getCurrentUsername() == "" ? i18n.tr("no username set") : DeltaHandler.getCurrentUsername()) : i18n.tr("No account configured")
                        headerRect.currentEmail = DeltaHandler.hasConfiguredAccount ? DeltaHandler.getCurrentEmail() : i18n.tr("Click Settings to manage accounts")
                        headerRect.currentProfilePic = DeltaHandler.getCurrentProfilePic() == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())
                    }
                }

                MouseArea {
                    id: headerMouse
                    anchors.fill: headerRect
                    onClicked: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/AccountConfig.qml'))
                    enabled: !root.chatOpenAlreadyClicked
                }
            
                LomiriShape {
                    id: profilePicShape
                    height: units.gu(5)
                    width: height
                    anchors {
                        left: headerRect.left
                        leftMargin: units.gu(2.5)
                        top: headerRect.top
                        topMargin: units.gu(0.5)
                    }
                    source: Image {
                        source: headerRect.currentProfilePic
                    }
                    sourceFillMode: LomiriShape.PreserveAspectCrop
                } // end of LomiriShape id:profilePicShape
            
                Rectangle {
                    id: headerRectMain
                    width: parent.width - profilePicShape.width - units.gu(2) - qrIconCage.width - settingsIconCage.width - infoIconCage.width - units.gu(1)
                    height: units.gu(6)
                    anchors {
                        left: profilePicShape.right
                        leftMargin: units.gu(1)
                        top: headerRect.top
                    }
                    color: headerTopBackgroundColor.color
                  
                    Label {
                        id: usernameLabel
                        anchors {
                            left: headerRectMain.left
                            leftMargin: units.gu(1)
                            bottom: emailLabel.top
                        }
                        text: headerRect.currentUsername == '' ? i18n.tr('no username set') : headerRect.currentUsername
                        color: "#e7fcfd"
                    }
            
                    Label {
                        id: emailLabel
                        anchors {
                            left: headerRectMain.left
                            leftMargin: units.gu(1)
                            bottom: parent.bottom
                            bottomMargin: units.gu(1)
                        }
                        text: headerRect.currentEmail
                        color: usernameLabel.color
                    }
            
                } // Rectangle id: headerRectMain
            
                Rectangle {
                    id: searchIconCage
                    width: units.gu(4)
                    anchors {
                        right: qrIconCage.left
                        top: headerRectMain.top
                        bottom: headerRectMain.bottom
                    }
                    color: headerTopBackgroundColor.color
            
                    Icon {
                        id: searchIcon
                        name: "find"
                        width: units.gu(2)
                        anchors{
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        color: usernameLabel.color
                    }
            
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (chatlistSearchField.visible) {
                                chatlistSearchField.text = ""
                            }
                            chatlistSearchField.visible = !chatlistSearchField.visible
                        }
                        enabled: !root.chatOpenAlreadyClicked
                    }
                }
            
                Rectangle {
                    id: qrIconCage
                    width: units.gu(4)
                    anchors {
                        right: infoIconCage.left
                        top: headerRectMain.top
                        bottom: headerRectMain.bottom
                    }
                    color: headerTopBackgroundColor.color
            
                    Icon {
                        id: qrIcon
                        name: "view-grid-symbolic"
                        width: units.gu(2)
                        anchors{
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        color: usernameLabel.color
                    }
            
                    MouseArea {
                        anchors.fill: parent
                        onClicked: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/QrShowScan.qml'))
                        enabled: !root.chatOpenAlreadyClicked
                    }
                }
            
                Rectangle {
                    id: infoIconCage
                    width: units.gu(4)
                    anchors {
                        right: settingsIconCage.left
                        top: headerRectMain.top
                        bottom: headerRectMain.bottom
                    }
                    color: headerTopBackgroundColor.color
            
                    Icon {
                        id: infoIcon
                        name: "info"
                        width: units.gu(2)
                        anchors{
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        color: usernameLabel.color
                    }
            
                    MouseArea {
                        anchors.fill: parent
                        onClicked: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/About.qml'))
                        enabled: !root.chatOpenAlreadyClicked
                    }
                }
            
                Rectangle {
                    id: settingsIconCage
                    width: units.gu(4)
                    anchors {
                        right: headerRect.right
                        rightMargin: units.gu(1)
                        top: headerRect.top
                        bottom: headerRectMain.bottom
                    }
                    color: headerTopBackgroundColor.color //"#032c30" //"#0ca7b6"
            
                    Icon {
                        id: settingsIcon
                        name: "settings"
                        width: units.gu(2)
                        anchors{
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        color: usernameLabel.color
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/SettingsPage.qml'))
                        enabled: !root.chatOpenAlreadyClicked
                    }
                }

                TextField {
                    id: chatlistSearchField
                    width: parent.width < units.gu(45) ? parent.width - units.gu(4) : units.gu(41)
                    anchors {
                        left: parent.left
                        leftMargin: units.gu(2)
                        top: headerRectMain.bottom
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
                    placeholderText: i18n.tr("Search")
                    onDisplayTextChanged: {
                        root.chatlistQueryTextHasChanged(displayText)
                    }
                    visible: false
                    enabled: DeltaHandler.hasConfiguredAccount && !root.chatOpenAlreadyClicked
                }

                ListItem {
                    id: dividerItem
                    height: divider.height
                    anchors {
                        top: chatlistSearchField.bottom
                        topMargin: units.gu(1)
                    }
                    visible: chatlistSearchField.visible
                }
            } // end of Rectangle id:headerRect
            /* ======================= END HEADER =========================== */

        //            // fallback header
        //            header: PageHeader {
        //                id: header
        //
        //                title: '%1 v%2'.arg(root.appName).arg(root.version)
        //
        //                trailingActionBar.actions: [
        //                    Action {
        //                        iconName: 'settings'
        //                        text: i18n.tr('Settings')
        //                        onTriggered: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/SettingsPage.qml'))
        //                    },
        //
        //                    Action {
        //                        iconName: 'info'
        //                        text: i18n.tr('About DeltaTouch')
        //                        onTriggered: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/About.qml'))
        //                    }
        //                ]
        //            } PageHeader id:header
                
            ListItem {
                id: archivedChatsItem
                width: parent.width
                height: archivedChatsItemLayout.height + (divider.visible ? divider.height : 0)
                anchors {
                    top: headerRect.bottom
                }

                ListItemLayout {
                    id: archivedChatsItemLayout
                    title.text: i18n.tr("Archived Chats")
                    title.font.bold: true

                    Icon {
                        id: closeArchiveListIcon
                        SlotsLayout.position: SlotsLayout.Trailing
                        height: units.gu(3)
                        width: height
                        name: "close"

                        MouseArea {
                            anchors.fill: closeArchiveListIcon
                            onClicked: DeltaHandler.closeArchive()
                        }
                    }


                }
                visible: showArchiveCloseLine

            }

            ListItemActions {
                id: leadingChatAction
                actions: Action {
                    iconName: "delete"
                    onTriggered: {
                        // the index is passed as parameter and can
                        // be accessed via 'value'
                        DeltaHandler.setMomentaryChatIdByIndex(value)
                        PopupUtils.open(Qt.resolvedUrl('pages/ConfirmChatDeletion.qml'))
                    }
                }
            }

            ListItemActions {
                id: trailingChatActions
                actions: [
                    Action {
                        iconName: "folder-symbolic"
                        onTriggered: {
                            // the index is passed as parameter and can
                            // be accessed via 'value'
                            DeltaHandler.setMomentaryChatIdByIndex(value)
                            DeltaHandler.archiveMomentaryChat()
                        }
                    },
                    Action {
                        iconName: "pinned"
                        onTriggered: {
                            DeltaHandler.setMomentaryChatIdByIndex(value)
                            DeltaHandler.pinUnpinMomentaryChat()
                        }
                    },
                    Action {
                        iconName: "navigation-menu"
                        onTriggered: {
                            DeltaHandler.setMomentaryChatIdByIndex(value)
                            PopupUtils.open(Qt.resolvedUrl('pages/ChatInfosActionsChatlist.qml'))
                        }
                    }
                ]
            }

            ListItemActions {
                // TODO: solve via visibility of actions instead of 
                // multiple ListItemActions?
                id: trailingChatActionsArchived
                actions: [
                    Action {
                        iconName: "folder-symbolic"
                        onTriggered: {
                            DeltaHandler.setMomentaryChatIdByIndex(value)
                            DeltaHandler.unarchiveMomentaryChat()
                        }
                    },
                    Action {
                        iconName: "navigation-menu"
                        onTriggered: {
                            DeltaHandler.setMomentaryChatIdByIndex(value)
                            PopupUtils.open(Qt.resolvedUrl('pages/ChatInfosActionsChatlist.qml'))
                        }
                    }
                ]
            }

            Component {
                id: delegateListItem

                ListItem {
                    id: chatListItem
                    // shall specify the height when Using ListItemLayout inside ListItem
                    height: chatlistLayout.height //+ (divider.visible ? divider.height : 0)
                    divider.visible: true
                    onClicked: {
                        if (!root.chatOpenAlreadyClicked) {
                            root.chatOpenAlreadyClicked = true
                            DeltaHandler.selectChat(index)
                            DeltaHandler.openChat()
                        } 
                    }

                    leadingActions: model.chatIsArchiveLink ? undefined : leadingChatAction
                    trailingActions: model.chatIsArchiveLink ? {} : (model.chatIsArchived ? trailingChatActionsArchived : trailingChatActions)

                    ListItemLayout {
                        id: chatlistLayout
                        title.text: model.chatname
                        title.font.bold: true
                        subtitle.text: model.msgPreview
                        //summary.text: "that's the summary"

                        LomiriShape {
                            id: chatPicShape
                            SlotsLayout.position: SlotsLayout.Leading
                            height: units.gu(6)
                            width: height
                            
                            source: model.chatPic == "" ? undefined : chatPicImage
                            Image {
                                id: chatPicImage
                                visible: false
                                source: StandardPaths.locate(StandardPaths.AppConfigLocation, model.chatPic)
                            }

                            Label {
                                id: avatarInitialLabel
                                visible: model.chatPic == ""
                                text: model.avatarInitial
                                fontSize: "x-large"
                                color: "white"
                                anchors.centerIn: parent
                            }

                            color: model.avatarColor

                            sourceFillMode: LomiriShape.PreserveAspectCrop
                        }

                        Rectangle {
                            id: dateAndMsgCount
                            SlotsLayout.position: SlotsLayout.Trailing
                            width: (((pinnedIcon.visible ? pinnedIcon.width + units.gu(0.5) : 0) + timestamp.contentWidth) > contactRequestLabel.contentWidth ? ((pinnedIcon.visible ? pinnedIcon.width + units.gu(0.5) : 0) + timestamp.contentWidth) : contactRequestLabel.contentWidth) + units.gu(1)
                            height: units.gu(6)
                            color: chatListItem.color 

                            Icon {
                                id: mutedIcon
                                height: timestamp.contentHeight
                                anchors {
                                    right: pinnedIcon.visible ? pinnedIcon.left : timestamp.left
                                    rightMargin: units.gu(0.5)
                                    top: dateAndMsgCount.top
                                }
                                name: "audio-speakers-muted-symbolic"
                                color: root.darkmode ? "white" : "black"
                                visible: model.chatIsMuted

                            }

                            Icon {
                                id: pinnedIcon
                                height: timestamp.contentHeight
                                anchors {
                                    right: timestamp.left
                                    rightMargin: units.gu(0.5)
                                    top: dateAndMsgCount.top
                                }
                                name: "pinned"
                                color: root.darkmode ? "white" : "black"
                                visible: model.chatIsPinned

                            }

                            Label {
                                id: timestamp
                                text: model.timestamp
                                anchors {
                                    right: dateAndMsgCount.right
                                    top: dateAndMsgCount.top
                                    topMargin: units.gu(0.2)
                                }
                                fontSize: "small"
                            }

                            Rectangle {
                                id: contactRequestRect
                                width: contactRequestLabel.contentWidth + units.gu(0.5)
                                height: contactRequestLabel.contentHeight + units.gu(0.5)
                                anchors {
                                    top: timestamp.bottom
                                    topMargin: units.gu(0.7)
                                    right: dateAndMsgCount.right
                                    //rightMargin: units.gu(1)
                                }
                                Label {
                                    id: contactRequestLabel
                                    anchors {
                                        horizontalCenter: contactRequestRect.horizontalCenter
                                        verticalCenter: contactRequestRect.verticalCenter
//                                        top: timestamp.bottom
//                                        topMargin: units.gu(1.25)
//                                        left: contactRequestRect.left
//                                        leftMargin: units.gu(0.25)
                                    }
                                    text: i18n.tr('Request')
                                    fontSize: "small"
                                    color: "white"
                                }
                                color: root.unreadMessageCounterColor
                                border.color: contactRequestLabel.color
                                visible: model.isContactRequest
                            } // Rectangle id: contactRequestRect

                            LomiriShape {
                                id: newMsgCountShape
                                height: units.gu(3)
                                width: height

                                anchors {
                                    top: timestamp.bottom
                                    topMargin: units.gu(0.8)
                                    right: dateAndMsgCount.right
                                    //rightMargin: units.gu(1)
                                }
                                backgroundColor: model.chatIsMuted ? (root.darkmode ? "#202020" : "#e0e0e0") : root.unreadMessageCounterColor
                                
                                property bool shouldBeVisible: !model.isContactRequest && model.newMsgCount > 0
                                visible: shouldBeVisible

                                Label {
                                    id: newMsgCountLabel
                                    anchors {
                                        top: newMsgCountShape.top
                                        topMargin: units.gu(0.6)
                                        horizontalCenter: newMsgCountShape.horizontalCenter
                                    }
                                    text: model.newMsgCount > 99 ? "99+" : model.newMsgCount
                                    fontSize: "small"
                                    font.bold: true
                                    color: model.chatIsMuted && !root.darkmode ? "black" : "white"
                                }

                            }
                        } // Rectangle id: dateAndMsgCount
                    } // end ListItemLayout id: chatlistLayout
                } // end ListItem id: chatListItem
            } // end Compoment id: delegateListItem

            ListView {
                id: view
                clip: true
                anchors.top: showArchiveCloseLine ? archivedChatsItem.bottom : headerRect.bottom
                width: parent.width
                height: chatlistPage.height - headerRect.height - bottomEdgeHint.height
                model: DeltaHandler
                delegate: delegateListItem
            }

            Rectangle {
                height: parent.height - headerRect.height
                width: parent.width
                anchors {
                    top: headerRect.bottom
                    left: parent.left
                }
                color: theme.palette.normal.background
                visible: root.chatOpenAlreadyClicked
                Label {
                    anchors.centerIn: parent
                    text: i18n.tr("Loading…")
                }
            }

            // BottomEdge originally from FluffyChat (C) Christian Pauly,
            // licensed under GPLv3
            // https://gitlab.com/KrilleFear/fluffychat
            // modified by (C) 2023 Lothar Ketterer
            BottomEdge {
                id: bottomEdge
                height: parent.height
                //contentUrl: Qt.resolvedUrl('pages/AddChat.qml')
                preloadContent: false
                enabled: DeltaHandler.hasConfiguredAccount && !root.chatOpenAlreadyClicked
                contentComponent: Rectangle {
                    width: chatlistPage.width
                    height: chatlistPage.height
                    color: theme.palette.normal.background
                    AddChat {
                        id: addChatPage
                    }
                }

                hint  {
                    id: bottomEdgeHint
                    status: isDesktopMode ? BottomEdgeHint.Locked : (showBottomEdgeHint ? BottomEdgeHint.Locked : BottomEdgeHint.Active)
                    text: bottomEdge.hint.status == BottomEdgeHint.Locked ? i18n.tr("New Chat") : ""
                    iconName: "compose"
                    onStatusChanged: if (status === BottomEdgeHint.Inactive) bottomEdge.hint.status = (showBottomEdgeHint ? BottomEdgeHint.Locked : BottomEdgeHint.Active)
                    visible: DeltaHandler.hasConfiguredAccount
                }
            }
        } // end of Page id: chatlistPage
    } // end of AdaptivePageLayout id: layout
    
    // lock the bottom edge hint for the first 10 seconds
    Timer {
        id: hintTimer
        interval: 10000
        repeat: false
        triggeredOnStart: false
        onTriggered: showBottomEdgeHint = false
    }

    // Update the list of chats every 5 minutes. Reason is
    // for example, to capture the end of a mute duration (there's
    // no signal/event when a mute duration expires, so it's
    // necessary to, e.g.,  periodically check)
    Timer {
        id: periodicTimer
        interval: 300000
        repeat: true
        triggeredOnStart: false
        onTriggered: periodicTimerSignal()
    }
    
    Component.onCompleted: {
        console.log("Main.qml: App version " + version)

        if (oldVersion === version) {
            // Last session was by the same version as this one
        } else {
            // Any code that is to be executed upon first start
            // of a new version is to be entered here
            console.log("Main.qml: Version update detected, version of last session: " + oldVersion)

            // save the new version to the settings
            oldVersion = version
        }

        darkmode = (theme.name == "Lomiri.Components.Themes.SuruDark")
        if (!DeltaHandler.hasConfiguredAccount) {
            layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/AccountConfig.qml'))
        }

        startStopIO()
        hintTimer.start()

        root.appStateNowActive.connect(DeltaHandler.chatmodel.appIsActiveAgainActions)

        DeltaHandler.setEnablePushNotifications(sendPushNotifications)
        DeltaHandler.setDetailedPushNotifications(detailedPushNotifications)
        DeltaHandler.setAggregatePushNotifications(aggregatePushNotifications)

        root.periodicTimerSignal.connect(DeltaHandler.periodicTimerActions)

        root.chatlistQueryTextHasChanged.connect(DeltaHandler.updateChatlistQueryText)
        DeltaHandler.clearChatlistQueryRequest.connect(root.clearChatlistQuery)

        periodicTimer.start()
    }

    Connections {
        target: DeltaHandler.emitterthread
        onErrorEvent: {
            errorShape.visible = true
            errorLabel.text = i18n.tr("Error: %1").arg(errorMessage)
        }
    }

    LomiriShape {
        id: errorShape
        width: parent.width - units.gu(2)
        height: errorLabel.contentHeight + units.gu(2)
        anchors {
            top: parent.top
            topMargin: units.gu(10)
            horizontalCenter: parent.horizontalCenter
        }

        color: theme.palette.normal.negative
        visible: false

        Label {
            id: errorLabel
            width: errorShape.width - units.gu(2)
            anchors {
                left: errorShape.left
                leftMargin: units.gu(1)
                top: errorShape.top
                topMargin: units.gu(1)
            }
            color: theme.palette.normal.negativeText
            wrapMode: Text.Wrap
        }

        MouseArea {
            anchors.fill: parent
            onClicked: errorShape.visible = false
        }
    }
} // end of MainView id: root
