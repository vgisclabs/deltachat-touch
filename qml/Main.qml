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
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import Ubuntu.Connectivity 1.0
import Ubuntu.Components.Popups 1.3

import DeltaHandler 1.0
import "pages"
import "jsonrpc.mjs" as JSONRPC

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'deltatouch.lotharketterer'
    automaticOrientation: true
    anchorToKeyboard: true

    property string appName: i18n.tr('DeltaTouch')
    property string version: '1.3.1-pre03'
    property string oldVersion: "unknown"

    signal appStateNowActive()
    signal ioChanged()

    // see periodicTimer
    signal periodicTimerSignal()

    signal chatlistQueryTextHasChanged(string query)

    function receiveJsonrpcResponse(response) {
        //console.log("+++++++++++ in Main.qml: received jsonrpc response: ", response)
        JSONRPC.receiveResponse(response)
    }


    // Performs actions related to a version update
    // directly at beginning of onCompleted
    function checkVersionUpdateEarly() {
        if (oldVersion === version) {
            // Last session was by the same version as this one
            console.log("Main.qml: No version update since last session")

        } else {
            // Any code that is to be executed upon first start
            // of a new or updated version is to be entered here

            if (oldVersion !== "unknown") {
                console.log("Main.qml: Version update detected, version of last session: " + oldVersion)
                // stuff only for updated versions
            } else {
                console.log("Main.qml: New installation detected or version older than 1.1.1")
                // stuff only for new or very old (< 1.1.1) installations
            }

            // Do NOT save the new version to the settings, this is done
            // in checkVersionUpdateLate()
        }
    }

    // Performs actions related to a version update
    // at the end of the startup process, i.e., when
    // all accounts are open
    function checkVersionUpdateLate() {
        // Action only needed if new version
        if (oldVersion !== version) {
            // Any code that is to be executed upon first start
            // of a new or updated version is to be entered here

//            if (oldVersion !== "unknown") {
//                // stuff only for updated versions
//            } else {
//                // stuff only for new or updates to very old (< 1.1.1) installations
//            }

            // add device message for the current version.
            // The version string has to be passed, the actual
            // message is defined in the called function in C++.
            DeltaHandler.addDeviceMessageForVersion(version)

            // Save the new version to the settings
            oldVersion = version
        }
    }

    function updateConnectivity() {
        let conn = DeltaHandler.getConnectivitySimple()
        if (conn >= 1000 && conn < 2000) {
            // "Not connected"
            connectivityShape.color = "red"
        } else if (conn >= 2000 && conn < 3000) {
            // "Connecting…"
            connectivityShape.color = "yellow"
        } else if (conn >= 3000 && conn < 4000) {
            // "Updating…"
            connectivityShape.color = "orange"
        } else if (conn >= 4000) {
            // "Connected"
            connectivityShape.color = "green"
        } else {
            // unknown state
            connectivityShape.color = "white"
        }
    }

    function startupStep1() {
        // Check
        // - if at least one account is present
        // - if a workflow has to be resumed (in which case
        //   only an info popup will be shown to the user at
        //   this stage, actual resuming will come later)
        if (DeltaHandler.numberOfAccounts() > 0) {
            // check if workflows have to be resumed
            if (DeltaHandler.workflowToEncryptedPending()) {
                let popup1 = PopupUtils.open(
                    Qt.resolvedUrl("pages/InfoPopup.qml"),
                    layout.primaryPage,
                    // TODO string not translated yet
                    { "text": i18n.tr("From last session, database encryption has not finished yet and will resume after entering the passphrase.")}
                )
                popup1.done.connect(startupStep2)
            } else if (DeltaHandler.workflowToUnencryptedPending()) {
                let popup2 = PopupUtils.open(
                    Qt.resolvedUrl("pages/InfoPopup.qml"),
                    layout.primaryPage,
                    // TODO string not translated yet
                    { "text": i18n.tr("From last session, database decryption has not finished yet and will resume after entering the passphrase.")}
                )
                popup2.done.connect(startupStep2)
            } else {
                startupStep2()
            }
        } else {
            // Number of accounts is 0
            startupStep4()
        }
    }

    function startupStep2() {
        // Request the user to enter the database passphrase, if necessary
        // 
        // In RequestDatabasePassword, the passphrase is sent
        // to DeltaHandler. DeltaHandler will then open all closed accounts
        // or emit failure(), which will be taken as signal that the
        // passphrase was incorrect. In this case the popup won't close until
        // the correct passphrase has been entered.
        if (DeltaHandler.hasEncryptedAccounts() || DeltaHandler.workflowToEncryptedPending() || DeltaHandler.workflowToUnencryptedPending()) {
            let popup3 = PopupUtils.open(Qt.resolvedUrl("pages/RequestDatabasePassword.qml"), layout.primaryPage)
            popup3.success.connect(startupStep3)
        } else {
            startupStep4()
        }
        // TODO: maybe check here whether the setting for encrypted db
        // is consistent with the status of the accounts? Or at a later step?
    }

    function startupStep3() {
        // Resumes database encryption or decryption workflows, if necessary
        if (DeltaHandler.workflowToUnencryptedPending()) {
            let popup4 = PopupUtils.open(
                Qt.resolvedUrl("pages/ProgressDatabaseDecryption.qml"),
                layout.primaryPage,
                { "resumeWorkflow": true })
            popup4.success.connect(startupStep3a)
            // TODO: what to do if the WF failed?
            popup4.failed.connect(startupStep3a)
        } else if (DeltaHandler.workflowToEncryptedPending()) {
            let popup5 = PopupUtils.open(Qt.resolvedUrl("pages/ProgressDatabaseEncryption.qml"), layout.primaryPage)
            popup5.success.connect(startupStep3b)
            // TODO: what to do if the WF failed?
            popup5.failed.connect(startupStep3b)
        } else {
            startupStep4()
        }
    }

    function startupStep3a() {
        // Decryption workflow has finished or failed, clean up
        DeltaHandler.databaseDecryptionCleanup()
        // go directly to step 5 as the ...cleanup() method above will
        // call loadSelectedAccount()
        startupStep5()
    }

    function startupStep3b() {
        // Encryption workflow has finished or failed, clean up
        DeltaHandler.databaseEncryptionCleanup()
        // go directly to step 5 as the ...cleanup() method above will
        // call loadSelectedAccount()
        startupStep5()
    }

    function startupStep4() {
        // Some actions are required on C++ side now
        DeltaHandler.loadSelectedAccount()
        startupStep5()
    }

    function startupStep5() {
        if (!DeltaHandler.hasConfiguredAccount) {
            layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/AccountConfig.qml'))
        } else {
            updateConnectivity()
        }

        checkVersionUpdateLate()

        startStopIO()
        hintTimer.start()

        root.appStateNowActive.connect(DeltaHandler.chatmodel.appIsActiveAgainActions)

        DeltaHandler.setEnablePushNotifications(sendPushNotifications)
        DeltaHandler.setDetailedPushNotifications(detailedPushNotifications)
        DeltaHandler.setAggregatePushNotifications(aggregatePushNotifications)

        root.periodicTimerSignal.connect(DeltaHandler.periodicTimerActions)

        root.chatlistQueryTextHasChanged.connect(DeltaHandler.updateChatlistQueryText)
        DeltaHandler.clearChatlistQueryRequest.connect(root.clearChatlistQuery)

        DeltaHandler.connectivityChangedForActiveAccount.connect(updateConnectivity)

        periodicTimer.start()

        DeltaHandler.sendJsonrpcRequest("{
            \"jsonrpc\": \"2.0\",
            \"method\": \"get_system_info\",
            \"id\": 13105,
            \"params\": []
        }")

    }

    function clearChatlistQuery() {
        chatlistSearchField.text = "";
    }

    // Color scheme
    //
    // The bool darkmode will be set on startup. If it is set here
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

    // Comment and property isDesktopMode taken from Ubuntu Weather
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

    // Controls whether the search bar is visible. Used instead of
    // setting chatlistSearchField.visible directly to be able
    // to hide the search bar after clicking on a chat (via
    // binding chatOpenAlreadyClicked to chatlistSearchField.visible);
    // to be able to control the visibility via the search icon, too,
    // this property is needed.
    property bool searchVisible: false

    // see AccountConfig.qml
    property bool showAccountsExperimentalSettings: false

    /* ********** Text Zoom ***********/
    // valid values are from 1 to 4. Must NOT be 0, otherwise
    // scaledFontSizeLarger will try to access fontSizeNames[-1].
    // Likewise, values > 4 will result in out-of-bounds.
    property int scaleLevel: 2

    // Upper limit for scaleLevel
    property int maximumScale: 4

    // x-large is duplicated so the main scale (message texts etc.) can reach x-large, but 
    // scaledFontSizeLarger still works (which is scaleLevel + 1)
    //
    // On the other end, scaling the main scale lower than "small" probably
    // makes no sense. This is limited by the PinchHandler
    // and in the setting (SettingsPage.qml).
    readonly property variant fontSizeNames: ["x-small", "small", "medium", "large", "x-large", "x-large"]
    readonly property string scaledFontSize: fontSizeNames[scaleLevel]
    readonly property string scaledFontSizeSmaller: fontSizeNames[scaleLevel - 1]
    readonly property string scaledFontSizeLarger: fontSizeNames[scaleLevel + 1]
    property int scaledFontSizeInPixels: FontUtils.sizeToPixels(root.scaledFontSize)
    property int scaledFontSizeInPixelsSmaller: FontUtils.sizeToPixels(root.scaledFontSizeSmaller)
    /* ********* END Text Zoom *********/

    property bool alwaysLoadRemoteContent: false

    Settings {
        id: settings
        property alias synca: root.syncAll
        property alias voiceMessQual: root.voiceMessageQuality
        property alias sendPushNotif: root.sendPushNotifications
        property alias detailedPushNotif: root.detailedPushNotifications
        property alias aggregatePushNotif: root.aggregatePushNotifications
        property alias versionAtLastSession: root.oldVersion
        property alias accountsExpSettings: root.showAccountsExperimentalSettings
        property alias scaleLevelTextZoom: root.scaleLevel
        property alias alwaysLoadRemote: root.alwaysLoadRemoteContent
    }

    width: units.gu(45)
    height: units.gu(75)

    function startStopIO() {
        if (DeltaHandler.networkingIsStarted) { // network is up, check if it needs to be stopped
            //if (Qt.application.state != Qt.ApplicationActive || !DeltaHandler.networkingIsAllowed || !DeltaHandler.hasConfiguredAccount || !(Connectivity.online || isDesktopMode) || !root.syncAll) {
            if (!DeltaHandler.networkingIsAllowed || !DeltaHandler.hasConfiguredAccount || !(Connectivity.online || isDesktopMode) || !root.syncAll) {
                DeltaHandler.stop_io();
                console.log('startStopIO(): network is currently up, calling stop_io()')
                ioChanged();
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
                ioChanged();
            }
            else {
                console.log('startStopIO(): network is down, doing nothing')
            }
        }
        updateConnectivity()
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
        onNewJsonrpcResponse:{
            receiveJsonrpcResponse(response)
        }

        onChatViewClosed: {
            root.chatOpenAlreadyClicked = false;
            if (gotoQrScanPage) {
                layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/QrShowScan.qml'), { "goToScanDirectly": true })
            }
        }

        onHasConfiguredAccountChanged: {
            startStopIO()
            console.log('DeltaHandler signal hasConfiguredAccountChanged')
        }

        onNetworkingIsAllowedChanged: {
            startStopIO()
            console.log('DeltaHandler signal networkingIsAllowedChanged')
        }

        onOpenChatViewRequest: {
            layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/ChatView.qml'))
        }

        onChatlistShowsArchivedOnly: {
            showArchiveCloseLine = showsArchived;
            root.chatOpenAlreadyClicked = false
        }

        onErrorEvent: {
            errorShape.visible = true
            errorLabel.text = i18n.tr("Error: %1").arg(errorMessage)
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
        onAboutToQuit: {
            DeltaHandler.shutdownTasks()
        }
    }

    Connections {
        target: DeltaHandler.contactsmodel
        onChatCreationSuccess: {
            bottomEdge.collapse()
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
                height: headerTopBackgroundColor.height + (chatlistSearchField.visible ? units.gu(1) + chatlistSearchField.height + units.gu(1) + dividerItem.height : 0)
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
                    height: profilePicShape.height + units.gu(1)
                    width: headerRect.width
                    anchors {
                        top: headerRect.top
                        left: headerRect.left
                    }
                    color: "#053f45" //"#06545b" //"#032c30" //"#0ca7b6"
                }

                //opacity: 0.5
            
                property string currentUsername: DeltaHandler.hasConfiguredAccount ? (DeltaHandler.getCurrentUsername() == "" ? i18n.tr("no username set") : DeltaHandler.getCurrentUsername()) : i18n.tr("No account configured")
                property string currentEmail: DeltaHandler.hasConfiguredAccount ? DeltaHandler.getCurrentEmail() : i18n.tr("Click Settings to manage accounts")
                property string currentProfilePic: DeltaHandler.getCurrentProfilePic() == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())

                Connections {
                    target: DeltaHandler
                    onAccountChanged: {
                        headerRect.currentUsername = DeltaHandler.hasConfiguredAccount ? (DeltaHandler.getCurrentUsername() == "" ? i18n.tr("no username set") : DeltaHandler.getCurrentUsername()) : i18n.tr("No account configured")
                        headerRect.currentEmail = DeltaHandler.hasConfiguredAccount ? DeltaHandler.getCurrentEmail() : i18n.tr("Click Settings to manage accounts")
                        headerRect.currentProfilePic = DeltaHandler.getCurrentProfilePic() == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())
                        bottomEdge.enabled = DeltaHandler.hasConfiguredAccount && !root.chatOpenAlreadyClicked
                        bottomEdgeHint.visible = DeltaHandler.hasConfiguredAccount
                        updateConnectivity()
                    }
                }

                Rectangle {
                    id: profilePicAndNameRect

                    width: headerRect.width - qrIconCage.width - settingsIconCage.width - infoIconCage.width - units.gu(1)
                    height: headerTopBackgroundColor.height
                    anchors {
                        left: headerRect.left
                        top: headerRect.top
                    }
                    color: headerTopBackgroundColor.color

                    MouseArea {
                        id: headerMouse
                        anchors.fill: parent
                        onClicked: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/AccountConfig.qml'))
                        enabled: !root.chatOpenAlreadyClicked
                    }
                
                    UbuntuShape {
                        id: profilePicShape
                        height: usernameLabel.contentHeight + emailLabel.contentHeight + units.gu(1)
                        width: height
                        anchors {
                            left: profilePicAndNameRect.left
                            leftMargin: units.gu(0.5)
                            top: profilePicAndNameRect.top
                            topMargin: units.gu(0.5)
                        }
                        source: Image {
                            source: headerRect.currentProfilePic
                        }
                        sourceFillMode: UbuntuShape.PreserveAspectCrop
                    } // end of UbuntuShape id:profilePicShape
                
                    Label {
                        id: usernameLabel
                        anchors {
                            left: profilePicShape.right
                            leftMargin: units.gu(1.5)
                            bottom: emailLabel.top
                        }
                        width: parent.width - units.gu(3)
                        elide: Text.ElideRight
                        text: headerRect.currentUsername == '' ? i18n.tr('no username set') : headerRect.currentUsername
                        color: "#e7fcfd"
                        fontSize: root.scaledFontSize
                    }
            
                    Label {
                        id: emailLabel
                        anchors {
                            left: profilePicShape.right
                            leftMargin: units.gu(1.5)
                            bottom: profilePicShape.bottom
                            bottomMargin: units.gu(0.5)
                        }
                        text: headerRect.currentEmail
                        width: parent.width - units.gu(3)
                        elide: Text.ElideRight
                        color: usernameLabel.color
                        fontSize: root.scaledFontSize
                    }
                } // Rectangle id: profilePicAndNameRect
                
                UbuntuShape {
                    id: connectivityShape

                    height: profilePicShape.height * (2/5)
                    width: height
                    anchors {
                        left: parent.left
                        leftMargin: units.gu(0.5) + profilePicShape.width - (width/2)
                        top: parent.top
                        topMargin: units.gu(0.25)
                    }
                } // end Rectangle id: connectivityShape
            
                Rectangle {
                    id: searchIconCage
                    height: profilePicShape.height + units.gu(1)
                    width: searchIcon.width + units.gu(2)
                    anchors {
                        right: qrIconCage.left
                        top: profilePicAndNameRect.top
                        bottom: profilePicAndNameRect.bottom
                    }
                    color: headerTopBackgroundColor.color
            
                    Icon {
                        id: searchIcon
                        name: "find"
                        width: profilePicShape.width * (2/5)
                        height: width
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
                            } else {
                                chatlistSearchField.focus = true
                            }
                            searchVisible = !searchVisible
                        }
                        enabled: !root.chatOpenAlreadyClicked
                    }
                }
            
                Rectangle {
                    id: qrIconCage
                    height: profilePicShape.height + units.gu(1)
                    width: searchIcon.width + units.gu(2)
                    anchors {
                        right: infoIconCage.left
                        top: profilePicAndNameRect.top
                        bottom: profilePicAndNameRect.bottom
                    }
                    color: headerTopBackgroundColor.color
            
                    Icon {
                        id: qrIcon
                        name: "view-grid-symbolic"
                        width: profilePicShape.width * (2/5)
                        height: width
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
                    height: profilePicShape.height + units.gu(1)
                    width: searchIcon.width + units.gu(2)
                    anchors {
                        right: settingsIconCage.left
                        top: profilePicAndNameRect.top
                        bottom: profilePicAndNameRect.bottom
                    }
                    color: headerTopBackgroundColor.color
            
                    Icon {
                        id: infoIcon
                        name: "info"
                        width: profilePicShape.width * (2/5)
                        height: width
                        anchors{
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        color: usernameLabel.color
                    }
            
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('pages/About.qml'))
                        }
                        enabled: !root.chatOpenAlreadyClicked
                    }
                }
            
                Rectangle {
                    id: settingsIconCage
                    height: profilePicShape.height + units.gu(1)
                    width: searchIcon.width + units.gu(2)
                    anchors {
                        right: headerRect.right
                        rightMargin: units.gu(1)
                        top: profilePicAndNameRect.top
                        bottom: profilePicAndNameRect.bottom
                    }
                    color: headerTopBackgroundColor.color //"#032c30" //"#0ca7b6"
            
                    Icon {
                        id: settingsIcon
                        name: "settings"
                        width: profilePicShape.width * (2/5)
                        height: width
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
                        top: profilePicAndNameRect.bottom
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
                    font.pixelSize: scaledFontSizeInPixels
                    onDisplayTextChanged: {
                        if (DeltaHandler.hasConfiguredAccount && !root.chatOpenAlreadyClicked) {
                            root.chatlistQueryTextHasChanged(displayText)
                        }
                    }
                    visible: searchVisible && !chatOpenAlreadyClicked
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

                    leadingActions: model.chatIsArchiveLink ? null : leadingChatAction
                    trailingActions: model.chatIsArchiveLink ? null : (model.chatIsArchived ? trailingChatActionsArchived : trailingChatActions)

                    ListItemLayout {
                        id: chatlistLayout
                        title.text: model.chatname
                        title.font.bold: true
                        title.font.pixelSize: scaledFontSizeInPixels
                        subtitle.text: model.msgPreview
                        subtitle.font.pixelSize: scaledFontSizeInPixelsSmaller

                        // need to explicitly set the height because otherwise,
                        // the height will increase when switching
                        // scaledFontSize from "medium" to "small" (why??)
                        height: chatPicShape.height + units.gu(1) + units.gu(scaleLevel * 0.25)

                        UbuntuShape {
                            id: chatPicShape
                            SlotsLayout.position: SlotsLayout.Leading
                            height: units.gu(4) + units.gu(scaleLevel)
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

                            sourceFillMode: UbuntuShape.PreserveAspectCrop
                        }

                        Rectangle {
                            id: dateAndMsgCount
                            SlotsLayout.position: SlotsLayout.Trailing
                            width: (((verifiedIcon.visible ? verifiedIcon.width + units.gu(0.5) : 0) + (mutedIcon.visible ? mutedIcon.width + units.gu(0.5) : 0) + (pinnedIcon.visible ? pinnedIcon.width + units.gu(0.5) : 0) + timestamp.contentWidth) > contactRequestLabel.contentWidth ? ((verifiedIcon.visible ? verifiedIcon.width + units.gu(0.5) : 0) + (mutedIcon.visible ? mutedIcon.width + units.gu(0.5) : 0) + (pinnedIcon.visible ? pinnedIcon.width + units.gu(0.5) : 0) + timestamp.contentWidth) : contactRequestLabel.contentWidth) + units.gu(1)
                            height: units.gu(3) + units.gu(scaleLevel)
                            color: chatListItem.color 

                            Icon {
                                id: verifiedIcon
                                height: timestamp.contentHeight
                                width: height

                                anchors {
                                    right: mutedIcon.visible ? mutedIcon.left : (pinnedIcon.visible ? pinnedIcon.left : timestamp.left)
                                    rightMargin: units.gu(0.5)
                                    top: dateAndMsgCount.top
                                }
                                source: "../assets/verified.svg"
                                visible: model.chatIsVerified
                            }
 
                            Icon {
                                id: mutedIcon
                                height: timestamp.contentHeight
                                width: height
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
                                width: height
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
                                fontSize: root.scaledFontSizeSmaller
                            }

                            Loader {
                                id: previewStatusLoader
                                active: model.previewMsgState !== DeltaHandler.StateUnknown && !model.isContactRequest && model.newMsgCount === 0
                                height: timestamp.height
                                width: height * 2

                                anchors {
                                    top: timestamp.bottom
                                    topMargin: units.gu(0.6) + units.gu(scaleLevel/10)
                                    right: dateAndMsgCount.right
                                    //rightMargin: units.gu(1)
                                }

                                sourceComponent: Icon {
                                    source: { 
                                        switch (model.previewMsgState) {
                                            case DeltaHandler.StatePending:
                                                if (root.darkmode) {
                                                    return Qt.resolvedUrl('../assets/dotted_circle_white.svg');
                                                    break;
                                                } else {
                                                    return Qt.resolvedUrl('../assets/dotted_circle_black.svg');
                                                    break;
                                                }

                                            case DeltaHandler.StateDelivered:
                                                return Qt.resolvedUrl('../assets/sent_green.svg');
                                                break;

                                            case DeltaHandler.StateReceived:
                                                return Qt.resolvedUrl('../assets/read_green.svg');
                                                break;

                                            case DeltaHandler.StateFailed:
                                                return Qt.resolvedUrl('../assets/circled_x_red.svg');
                                                break;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: contactRequestRect
                                width: contactRequestLabel.contentWidth + units.gu(0.5)
                                height: contactRequestLabel.contentHeight + units.gu(0.5)
                                anchors {
                                    top: timestamp.bottom
                                    topMargin: units.gu(0.3) + units.gu(scaleLevel/10)
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
                                    fontSize: root.scaledFontSizeSmaller
                                    color: "white"
                                }
                                color: root.unreadMessageCounterColor
                                border.color: contactRequestLabel.color
                                visible: model.isContactRequest
                            } // Rectangle id: contactRequestRect

                            UbuntuShape {
                                id: newMsgCountShape
                                height: newMsgCountLabel.height + units.gu(0.6)
                                width: height

                                anchors {
                                    top: timestamp.bottom
                                    topMargin: units.gu(0.3) + units.gu(scaleLevel/10)
                                    right: dateAndMsgCount.right
                                    //rightMargin: units.gu(1)
                                }
                                backgroundColor: model.chatIsMuted ? (root.darkmode ? "#202020" : "#e0e0e0") : root.unreadMessageCounterColor
                                
                                visible: !model.isContactRequest && model.newMsgCount > 0

                                Label {
                                    id: newMsgCountLabel
                                    anchors {
                                        top: newMsgCountShape.top
                                        topMargin: units.gu(0.3)
                                        horizontalCenter: newMsgCountShape.horizontalCenter
                                    }
                                    text: model.newMsgCount > 99 ? "99+" : model.newMsgCount
                                    fontSize: root.scaledFontSizeSmaller
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
                anchors.fill: parent
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

        checkVersionUpdateEarly()

        isDesktopMode = DeltaHandler.isDesktopMode()
        if (isDesktopMode) {
            console.log("Main.qml: Running in desktop mode")
        } else {
            console.log("Main.qml: NOT running in desktop mode")
        }

        darkmode = (theme.name == "Ubuntu.Components.Themes.SuruDark") || (theme.name == "Lomiri.Components.Themes.SuruDark")
        startupStep1()

        JSONRPC.setSendRequest((request) => DeltaHandler.sendJsonrpcRequest(request))

        JSONRPC.client.getSystemInfo().then((dc_info) => console.log("Main.qml: deltachat-core-rust", dc_info.deltachat_core_version))
    }

    Connections {
        target: DeltaHandler.emitterthread
        onErrorEvent: {
            errorShape.visible = true
            errorLabel.text = i18n.tr("Error: %1").arg(errorMessage)
        }
    }

    UbuntuShape {
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

// PinchHandler currently taken out due to incompatibility with ListItem
//
//    // Taken from from Messaging-App Copyright 2012-2016 Canonical Ltd.,
//    // licensed under GPLv3
//    // https://gitlab.com/ubports/development/core/messaging-app/-/blob/62f448f8a5bec59d8e5c3f7bf386d6d61f9a1615/src/qml/Messages.qml
//    // modified by (C) 2023 Lothar Ketterer
//    PinchHandler {
//        id: pinchHandlerMain
//        target: null
//        enabled: !root.chatOpenAlreadyClicked
//
//        minimumPointCount: 2
//
//        property real previousScale: 1.0
//        property real zoomThreshold: 0.5
//
//        onScaleChanged: {
//            var nextLevel = root.scaleLevel
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
////                 // get the index of the current drag item if any and make ListView follow it
////                var positionInRoot = mapToItem(messageList.contentItem, centroid.position.x, centroid.position.y)
////                const currentIndex = messageList.indexAt(positionInRoot.x,positionInRoot.y)
////
////                messageList.positionViewAtIndex(currentIndex, ListView.Visible)
////
//                previousScale = activeScale
//            }
//        }
//
//        onActiveChanged: {
//            if (active) {
//                previousScale = 1.0
//            }
//            view.currentIndex = -1
//        }
//    }
} // end of MainView id: root
