/*
 * Copyright (C) 2023, 2024 Lothar Ketterer
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
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import Lomiri.Connectivity 1.0
import Lomiri.Components.Popups 1.3

import DeltaHandler 1.0
import "pages"
import "jsonrpc.mjs" as JSONRPC

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'deltatouch.lotharketterer'
    automaticOrientation: true
    anchorToKeyboard: true

//    FontLoader {
//        id: emojifont
//        name: "qrc:///assets/joypixels-android.ttf"
//    }

    property string appName: i18n.tr('DeltaTouch')
    property string version: '1.7.0'
    property string oldVersion: "unknown"

    property bool chatViewIsOpen: false
    property int activeChatId: -1

    // used for the content of the URL dispatcher
    property string urlstring

    // the page that is currently handling URLs/QR codes,
    // by name of the file minus the .qml extension, relative
    // to the qml/ directory (e.g., "pages/AddAccount")
    property string urlHandlingPage: "Main"

    signal unprocessedUrl(string rawUrl)

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
                console.log("Main.qml: New installation or previous version older than 1.1.1")
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
            DeltaHandler.addDeviceMessageForVersion(version, oldVersion)

            // Save the new version to the settings
            oldVersion = version
        }
    }

    function updateConnectivity() {
        let conn = DeltaHandler.getConnectivitySimple()
        if (conn >= 1000 && conn < 2000) {
            // "Not connected"
            connectivityShape.color = "red"
            connectivityShape.height = profilePicShape.height * (2/5)
            connectivityIcon.visible = false
        } else if (conn >= 2000 && conn < 3000) {
            // "Connecting…"
            connectivityShape.color = "yellow"
            connectivityShape.height = profilePicShape.height * (2/5)
            connectivityIcon.visible = false
        } else if (conn >= 3000 && conn < 4000) {
            // "Updating…"
            //connectivityShape.color = "orange"
            connectivityShape.color = "yellow"
            // When updating, we make the icon somewhat bigger
            connectivityShape.height = profilePicShape.height * (1/2)
            connectivityIcon.visible = true
        } else if (conn >= 4000) {
            // "Connected"
            connectivityShape.color = "green"
            connectivityShape.height = profilePicShape.height * (2/5)
            connectivityIcon.visible = false
        } else {
            // unknown state
            connectivityShape.color = "white"
            connectivityShape.height = profilePicShape.height * (2/5)
            connectivityIcon.visible = false
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
            let popup3 = PopupUtils.open(Qt.resolvedUrl("pages/RequestDatabasePassword.qml"), layout.primaryPage, { "extendedInfoVisible": true })
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
        DeltaHandler.chatmodel.setQQuickView(myview);

        if (!DeltaHandler.hasConfiguredAccount) {
            extraStack.push(Qt.resolvedUrl('pages/AccountConfig.qml'))
        } else {
            updateConnectivity()
            if (hasTwoColumns) {
                DeltaHandler.selectAndOpenLastChatId()
            }
        }

        checkVersionUpdateLate()

        refreshOtherAccsIndicator()

        DeltaHandler.notificationHelper.setEnablePushNotifications(sendPushNotifications)
        DeltaHandler.notificationHelper.setDetailedPushNotifications(detailedPushNotifications)
        DeltaHandler.notificationHelper.setNotifyContactRequests(notifyContactRequests)

        DeltaHandler.connectivityChangedForActiveAccount.connect(updateConnectivity)
        root.periodicTimerSignal.connect(DeltaHandler.periodicTimerActions)
        root.chatlistQueryTextHasChanged.connect(DeltaHandler.updateChatlistQueryText)
        DeltaHandler.clearChatlistQueryRequest.connect(root.clearChatlistQuery)
        root.appStateNowActive.connect(DeltaHandler.appIsActiveAgainActions)
        root.appStateNowActive.connect(DeltaHandler.chatmodel.appIsActiveAgainActions)

        startStopIO()
        hintTimer.start()

        if (Qt.application.state == Qt.ApplicationActive) {
            periodicTimer.start()
        }

        
        // check for and process arguments (arguments[0] is the application name)
        if (Qt.application.arguments && Qt.application.arguments.length > 1) {
            urlstring = Qt.application.arguments[1]
            urlDispatcherStep1(true)
        }
    }

    function newUrlFromScan(newUrl) {
        urlstring = newUrl
        urlDispatcherStep1(false)
    }

    // QR code + URL handling: URLs can be passed to the app in several ways:
    // * As command line argument when the app is not running yet. The argument
    //   is checked in qml/Main.qml (function startupStep5()).
    // * As command line arg when another instance is already running:
    //   - On Ubuntu Touch, the UriHandler will send the opened signal, see
    //     the connection in Main.qml to UriHandler.
    //   - On platforms other than Ubuntu Touch, it's checked whether the
    //     the app is already running via DBus, see main.cpp. If there's
    //     already an instance, the URL is sent via DBus to the existing instance,
    //     see signal urlReceived from DeltaHandler.
    // * As a scanned QR code by QrScanner.qml
    //
    // In each case, the url/QR code is passed to urlDispatcherStep1().
    // This function expects a boolean arg that tells whether it should ask
    // for an account that handles the URL. Background is that if multiple
    // accounts (profiles) exist, it's not clear with which account the user wants
    // to handle, e.g., an invitation link. Assumption is that if the user scanned
    // a QR code, they probably want to handle it with the account they are currently
    // using, so if the URL is from QrScanner.qml, the user will not be asked
    // to choose an account. On the contrary, URLs that are clicked in, e.g.,
    // a browser will trigger the account chooser if the action is account specific.
    //
    // By default, URLs are handled in Main.qml. If a page wants to handle URLs
    // itself, it has to perform these steps:
    // * In onCompleted:
    //   - save the original content of root.urlHandlingPage somewhere
    //   - set root.urlHandlingPage to its file name relative to the qml directory,
    //     but without the ".qml" extension (e.g., "qml/OnboardingChatmail")
    // * In the onDestruction function, the page has to write the original
    //   content back to root.urlHandlingPage
    // * To receive the URLs, the page has to connect to the unprocessedUrl(string)
    //   signal of root and handle the urls in there, but only if root.urlHandlingPage
    //   is set to the file name as stated above (could be that another page was
    //   activated afterwards that's also handling urls)
    
    function urlDispatcherStep1(askForAccount) {
        if (urlHandlingPage !== "Main") {
            unprocessedUrl(urlstring)
            urlstring = ""
            return
        }

        // Determine the type of the argument/url
        let qrstate = DeltaHandler.evaluateQrCode(urlstring)

        switch (qrstate) {
            case DeltaHandler.DT_QR_ASK_VERIFYCONTACT:
                console.log("qr state is DT_QR_ASK_VERIFYCONTACT")
                if ( (DeltaHandler.numberOfAccounts() - DeltaHandler.numberOfUnconfiguredAccounts()) > 1 && askForAccount) {
                    let popup12 = PopupUtils.open(Qt.resolvedUrl("pages/UrlDispatchAccountChooserPopup.qml"),
                        chatlistPage,
                        { "dialogText": i18n.tr("Chat with %1?").arg(DeltaHandler.getQrContactEmail()) + "\n\n" + i18n.tr("Select account for chatting") })
                    popup12.cancelled.connect(function() {
                        // unset urlstring if the user cancelled the account selection
                        urlstring = ""
                    })
                    popup12.selected.connect(function() {
                        extraStack.clear()
                        imageStack.clear()
                        // rest of the action will be triggered in the popup
                    })
                    // If the user selected an account, don't call DeltaHandler.continueQrCodeAction()
                    // here as switching to the chosen account may not have finished yet.
                    // Instead, the signal accountForUrlProcessingSelected will be
                    // emitted from C++ side in this case, triggering the respective action..

                    // if there's one account, or more than one and askForAccount is false
                } else if ( (DeltaHandler.numberOfAccounts() - DeltaHandler.numberOfUnconfiguredAccounts()) > 0) {
                    // only one configured account, go to step 2 directly
                    let popup = PopupUtils.open(
                        Qt.resolvedUrl("pages/ConfirmDialog.qml"),
                        chatlistPage,
                        { dialogText: i18n.tr("Chat with %1?").arg(DeltaHandler.getQrContactEmail()), confirmButtonPositive: true })
                    popup.confirmed.connect(function() {
                        extraStack.clear()
                        imageStack.clear()
                        DeltaHandler.continueQrCodeAction()
                    })
                    // unset urlstring if only one account
                    urlstring = ""
                } else {
                    // no account configured, cannot perform this action
                    console.log("Main.qml: urlDispatcherStep1(): No account configured, cannot process DT_QR_ASK_VERIFYCONTACT")
                    urlstring = ""
                }
                break;
                
            case DeltaHandler.DT_QR_ADDR:
                console.log("qr state is DT_QR_ADDR")
                if ( (DeltaHandler.numberOfAccounts() - DeltaHandler.numberOfUnconfiguredAccounts()) > 1 && askForAccount) {
                        let popup16 = PopupUtils.open(Qt.resolvedUrl("pages/UrlDispatchAccountChooserPopup.qml"), chatlistPage, { "dialogText": i18n.tr("Chat with %1?").arg(DeltaHandler.getQrContactEmail()) + "\n\n" + i18n.tr("Select account for chatting") })
                    popup16.cancelled.connect(function() {
                        // unset urlstring if the user cancelled the account selection
                        urlstring = ""
                    })
                    popup16.selected.connect(function() {
                        extraStack.clear()
                        imageStack.clear()
                        // rest of the action will be triggered in the popup
                    })
                    // see above regarding not calling DeltaHandler.continueQrCodeAction()
                    
                    // if there's one account, or more than one and askForAccount is false
                } else if ( (DeltaHandler.numberOfAccounts() - DeltaHandler.numberOfUnconfiguredAccounts()) > 0) {
                    // only one configured account
                    let popup17 = PopupUtils.open(
                        Qt.resolvedUrl("pages/ConfirmDialog.qml"),
                        chatlistPage,
                        { dialogText: i18n.tr("Chat with %1?").arg(DeltaHandler.getQrContactEmail()), confirmButtonPositive: true })
                    popup17.confirmed.connect(function() {
                        extraStack.clear()
                        imageStack.clear()
                        DeltaHandler.continueQrCodeAction()
                    })
                    // unset urlstring if only one account
                    urlstring = ""
                } else {
                    // no account configured, cannot perform this action
                    console.log("Main.qml: urlDispatcherStep1(): No account configured, cannot process DT_QR_ADDR")
                    urlstring = ""
                }
                break;

            case DeltaHandler.DT_QR_ASK_VERIFYGROUP:
                console.log("qr state is DT_QR_ASK_VERIFYGROUP")
                if ( (DeltaHandler.numberOfAccounts() - DeltaHandler.numberOfUnconfiguredAccounts()) > 1 && askForAccount) {
                        let popup6 = PopupUtils.open(Qt.resolvedUrl("pages/UrlDispatchAccountChooserPopup.qml"), chatlistPage, { "dialogText": i18n.tr("Do you want to join the group \"%1\"?").arg(DeltaHandler.getQrTextOne()) + "\n\n" + i18n.tr("Select account for joining") })
                    popup6.cancelled.connect(function() {
                        // unset urlstring if the user cancelled the account selection
                        urlstring = ""
                    })
                    popup6.selected.connect(function() {
                        extraStack.clear()
                        imageStack.clear()
                        // rest of the action will be triggered in the popup
                    })
                    // see above regarding not calling DeltaHandler.continueQrCodeAction()
                    
                    // if there's one account, or more than one and askForAccount is false
                } else if ( (DeltaHandler.numberOfAccounts() - DeltaHandler.numberOfUnconfiguredAccounts()) > 0) {
                    // only one configured account
                    let popup9 = PopupUtils.open(
                        Qt.resolvedUrl("pages/ConfirmDialog.qml"),
                        chatlistPage,
                        { dialogText: i18n.tr("Do you want to join the group \"%1\"?").arg(DeltaHandler.getQrTextOne()) })
                    popup9.confirmed.connect(function() {
                        extraStack.clear()
                        imageStack.clear()
                        DeltaHandler.continueQrCodeAction()
                    })
                    // unset urlstring if only one account
                    urlstring = ""
                } else {
                    // no account configured, cannot perform this action
                    console.log("Main.qml: urlDispatcherStep1(): No account configured, cannot process DT_QR_ASK_VERIFYGROUP")
                    urlstring = ""
                }
                break;

            case DeltaHandler.DT_QR_ACCOUNT:
                console.log("qr state is DT_QR_ACCOUNT")
                let tempurl1 = urlstring
                let popup10 = PopupUtils.open(
                    Qt.resolvedUrl("pages/ConfirmDialog.qml"),
                    chatlistPage,
                    { dialogText: (DeltaHandler.numberOfAccounts() > 0 ? i18n.tr("Create new profile on \"%1\" and log in there?\n\nYour existing profile will not be deleted. Use the \"Switch Profile\" item to switch between your profiles.").arg(DeltaHandler.getQrTextOne()) : i18n.tr("Create new profile on \"%1\" and log in there?").arg(DeltaHandler.getQrTextOne())), confirmButtonPositive: true })
                popup10.confirmed.connect(function() {
                    extraStack.clear()
                    imageStack.clear()
                    extraStack.push(Qt.resolvedUrl("pages/OnboardingChatmail.qml"), {"initialUrl": tempurl1})
                })
                urlstring = ""
                break;

            case DeltaHandler.DT_QR_LOGIN:
                console.log("qr state is DT_QR_LOGIN")
                let tempurl2 = urlstring
                let popup13 = PopupUtils.open(
                    Qt.resolvedUrl("pages/ConfirmDialog.qml"),
                    chatlistPage,
                    { dialogText: i18n.tr("Log into \"%1\"?").arg(DeltaHandler.getQrTextOne()),
                      confirmButtonPositive: true
                })
                popup13.confirmed.connect(function() {
                    extraStack.clear()
                    imageStack.clear()
                    extraStack.push(Qt.resolvedUrl("pages/OnboardingChatmail.qml"), {"initialUrl": tempurl2})
                })
                urlstring = ""
                break;

            case DeltaHandler.DT_QR_BACKUP: // fallthrough
            case DeltaHandler.DT_QR_BACKUP2:
                console.log("qr state is DT_QR_BACKUP or DT_QR_BACKUP2")
                let popup11 = PopupUtils.open(
                    Qt.resolvedUrl("pages/ConfirmDialog.qml"),
                    chatlistPage,
                    { dialogText: i18n.tr("Copy the account from the other device to this device?"),
                    dialogTitle: i18n.tr("Add as Second Device"),
                    okButtonText: i18n.tr("Add Second Device"),
                    confirmButtonPositive: true
                })
                popup11.confirmed.connect(function() {
                    extraStack.clear()
                    imageStack.clear()
                    PopupUtils.open(Qt.resolvedUrl("pages/ProgressQrBackupImport.qml"))
                })
                urlstring = ""
                break;

            case DeltaHandler.DT_QR_ERROR:
                console.log("qr state is DT_QR_ERROR")
                let popup15 = PopupUtils.open(
                    Qt.resolvedUrl("pages/ErrorMessage.qml"),
                    chatlistPage,
                    { text: i18n.tr("Error: %1").arg(DeltaHandler.getQrTextOne()),
                      title: i18n.tr("Error") })
                urlstring = ""
                break;

            case DeltaHandler.DT_UNKNOWN: // fallthrough
            default:
                // If this appears in the log, the url/argument may not even be something
                // unknown to the core, but it's just none of the cases that
                // we handle when passed as argument on startup or via URL dispatcher
                console.log("Main.qml: Don't know how to handle argument \"", urlstring, "\", passed on start or via urlDispatcher, skipping it")
                let popup14 = PopupUtils.open(
                    Qt.resolvedUrl("pages/ErrorMessage.qml"),
                    chatlistPage,
                    { text: i18n.tr("Unknown"),
                      title: i18n.tr("Error") })
                urlstring = ""
                break;
        }
    }


    function refreshOtherAccsIndicator() {
        let noOfInactiveMsgs = DeltaHandler.accountsmodel.noOfFreshMsgsInInactiveAccounts();
        if (root.notifyContactRequests) {
            noOfInactiveMsgs += DeltaHandler.accountsmodel.noOfChatRequestsInInactiveAccounts();
        }

        if (noOfInactiveMsgs > 0) {
            hasNewMsgsInOtherAccs = true

            if (noOfInactiveMsgs > 99) {
                newMsgsInOtherAccsCountLabel.text = "99+"
            } else {
                newMsgsInOtherAccsCountLabel.text = noOfInactiveMsgs
            }
        } else {
            hasNewMsgsInOtherAccs = false
        }
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

    property string otherAccsIndicatorBackgroundColor: inactiveAccsNewMsgsSinceLastCheck ? "#cbecf0" : "#111111" //"#182828"
    property string otherAccsIndicatorTextColor: inactiveAccsNewMsgsSinceLastCheck ? "black" : "#f5f5dc"


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

    property bool onUbuntuTouch: false

    property bool oskViaDbus: false

    // Will connect to the network if true. Offline mode if
    // set to false. Connected to the "Sync all" switch
    // in the Settings page. Setting takes effect on all
    // accounts, i.e., it is not account (context) specific.
    property bool syncAll: true

    property bool showBottomEdgeHint: true

    property int voiceMessageQuality: DeltaHandler.BalancedRecordingQuality

    property bool enterKeySends: false

    property bool sendPushNotifications: false
    property bool detailedPushNotifications: true
    property bool aggregatePushNotifications: false
    property bool hasNewMsgsInOtherAccs: false

    // Indicates whether new messages have been received for
    // accounts other than the active one since the last
    // time the user took a look at the account overview.
    // onCompleted in AccountConfig.qml will set it to false.
    // TODO: Should AccountConfig.qml set it to false in 
    // onDestruction instead?
    property bool inactiveAccsNewMsgsSinceLastCheck: false

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
    property bool notifyContactRequests: true

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

    // used in ReactionsSelectionPopover.qml, but already loaded here to
    // save time when creating the popup
    property var emojiRecentArray: ["🙂", "😂", "😄", "😅", "😬", "😞", "☹️", "🙁", "😳", "😢", "👍", "👎", "💪", "👀", "🤦", "🤷", "🤞", "🙈", "🍀", "❤️", "💓", "💯", "🚀", "🎉"]

    property bool webxdcTestingEnabled: false

    Settings {
        id: settings
        property alias synca: root.syncAll
        property alias voiceMessQual: root.voiceMessageQuality
        property alias rootEnterKeySends: root.enterKeySends
        property alias sendPushNotif: root.sendPushNotifications
        property alias detailedPushNotif: root.detailedPushNotifications
        property alias aggregatePushNotif: root.aggregatePushNotifications
        property alias versionAtLastSession: root.oldVersion
        property alias accountsExpSettings: root.showAccountsExperimentalSettings
        property alias showChatRequests: root.notifyContactRequests
        property alias scaleLevelTextZoom: root.scaleLevel
        property alias alwaysLoadRemote: root.alwaysLoadRemoteContent
        property alias inactAccsNewMsgsSinceLastCheck: root.inactiveAccsNewMsgsSinceLastCheck
        property alias recentlyUsedEmojisNew: root.emojiRecentArray
        property alias rootWidth: root.width
        property alias rootHeight: root.height
        property alias webxdcTesting: root.webxdcTestingEnabled
    }

    width: units.gu(45)
    height: units.gu(75)

    function startStopIO() {
        if (DeltaHandler.networkingIsStarted) { // network is up, check if it needs to be stopped
            //if (Qt.application.state != Qt.ApplicationActive || !DeltaHandler.networkingIsAllowed || !DeltaHandler.hasConfiguredAccount || !(Connectivity.online || isDesktopMode) || !root.syncAll) {
            if (!DeltaHandler.networkingIsAllowed || !DeltaHandler.hasConfiguredAccount || !(Connectivity.online || isDesktopMode || !onUbuntuTouch) || !root.syncAll) {
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
            if (DeltaHandler.networkingIsAllowed && DeltaHandler.hasConfiguredAccount && (Connectivity.online || isDesktopMode || !onUbuntuTouch) && root.syncAll) {
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
            if (Connectivity.online) {
                if (!onUbuntuTouch) {
                    JSONRPC.maybeNetwork()
                }
                console.log('Main.qml: received Lomiri Connectivity signal onlineChanged: Now online')
            } else {
                console.log('Main.qml: received Lomiri Connectivity signal onlineChanged: Now offline')
            }
        }
    }

    Connections {
        target: UriHandler
        onOpened: {
            if (uris.length > 0) {
                console.log("Main.qml: Received url from UriHandler: ", uris[0])
                urlstring = uris[0]
                urlDispatcherStep1(true)
            }
        }
    }
    
    Connections {
        target: DeltaHandler
        
        onNewJsonrpcResponse: {
            receiveJsonrpcResponse(response)
        }

        onAccountChanged: {
            // In two-column mode, the user can select a new account while
            // the ChatView is open. Just call selectAndOpenLastChatId if
            // we're in two-column mode.
            //
            // The second part of the condition (if we're not in two-column
            // mode, but the chat view is open) can occur if the user opened
            // the account switcher in two-column mode, then resized the window
            // to be in one-column mode. If a chat view was open before, it
            // will still be open, but hidden by the account switcher.
            if (hasTwoColumns || (!hasTwoColumns && chatViewIsOpen)) {
                DeltaHandler.selectAndOpenLastChatId()
            }
        }


        onUrlReceived: {
            urlstring = myUrl
            if (urlstring !== "") {
                // raise() doesn't work, at least it doesn't in fluxbox
                //myview.raise()
                myview.requestActivate()
                urlDispatcherStep1(true)
            }
        }

        onAccountForUrlProcessingSelected: {
            if (urlstring !== "") {
                // Step 2 is only needed for situations that require the user to
                // select an account to perform the action with. The user chosen account
                // is set at this stage, perform the action connected to the url/argument.
                //
                // All user queries ("Do you want to do this?") should be performed
                // in a previous step, nothing is queried here anymore.
                
                // Need to execute evaluateQrCode() again to make sure that the correct
                // contact ID is set in case a switch of accounts has taken place
                // between step1 and step2,  because in this case, the url/argument was
                // evaluated with the old account/context, and the contact ID via the
                // dc_lot_t as returned by dc_check_qr refers to a contact of the old
                // context)
                let qrstate = DeltaHandler.evaluateQrCode(urlstring)
                
                // Clear urlstring, so it will not trigger any action (e.g., when
                // switching to a different account) except for the one below. Its
                // content is not needed anymore, any info is stored on C++ side
                urlstring = ""

                switch (qrstate) {
                    // only cases that require account selection are listed here
                    case DeltaHandler.DT_QR_ASK_VERIFYCONTACT: // fallthrough
                    case DeltaHandler.DT_QR_ASK_VERIFYGROUP: // fallthrough
                    case DeltaHandler.DT_QR_ADDR:
                        DeltaHandler.continueQrCodeAction()
                        break;
                    default:
                        console.log("Main.qml, onAccountForUrlProcessingSelected: Warning: switch reached default case, url type is not covered by this function")
                        break;
                }
            } else {
                console.log("Main.qml, onAccountForUrlProcessingSelected: Warning: urlstring is not set, cannot perform any action")
            }
        }

        onChatViewClosed: {
            root.chatOpenAlreadyClicked = false;
            if (gotoQrScanPage) {
                extraStack.push(Qt.resolvedUrl('pages/QrScanner.qml'))
            }
        }

        onHasConfiguredAccountChanged: {
            startStopIO()
            console.log('DeltaHandler signal hasConfiguredAccountChanged')
            if (!DeltaHandler.hasConfiguredAccount) {
                // maybe the chat view is not active, but it
                // shouldn't be a problem to call removePages anyway
                layout.removePages(layout.primaryPage)
                // when the signal hasConfiguredAccountChanged is sent, the
                // account is only prepared for removal, but not actually removed
                // yet, so numberOfAccounts() would be wrong. The signal deletedAccount
                // is sent once the account has been actually deleted, push
                // AccountConfig when the deletedAccount signal is received.
                //extraStack.push(Qt.resolvedUrl('pages/AccountConfig.qml'))
            }
        }

        onNetworkingIsAllowedChanged: {
            startStopIO()
            console.log('DeltaHandler signal networkingIsAllowedChanged')
        }

        onOpenChatViewRequest: {
            if (!chatViewIsOpen) {
                layout.addPageToNextColumn(layout.primaryPage, Qt.resolvedUrl('pages/ChatView.qml'), { "pageAccID": accID, "pageChatID": chatID })
                chatViewIsOpen = true
            }
            root.activeChatId = chatID
        }

        onCloseChatViewRequest: {
            // maybe the chat view is not active, but it
            // shouldn't be a problem to call removePages anyway
            layout.removePages(layout.primaryPage)
        }

        onChatlistShowsArchivedOnly: {
            showArchiveCloseLine = showsArchived;
            if (!root.hasTwoColumns) {
                root.chatOpenAlreadyClicked = false
            }
        }

        onChatlistToBeginning: {
            view.positionViewAtBeginning()
        }

        onErrorEvent: {
            errorShape.visible = true
            errorLabel.text = i18n.tr("Error: %1").arg(errorMessage)
        }

        onNewConfiguredAccount: {
            accSwitcherSidebar.visible = root.showAccSwitchSidebar && DeltaHandler.numberOfAccounts() > 1
        }

        onNewUnconfiguredAccount: {
            accSwitcherSidebar.visible = root.showAccSwitchSidebar && DeltaHandler.numberOfAccounts() > 1
        }

        onFinishedSetConfigFromQr: {
            // see signal finishedSetConfigFromQr in deltahandler.h
            if (urlHandlingPage === "Main") {
                if (successful) {
                    // TODO: Unlike in the call from AddOrConfigureEmailAccount.qml,
                    // the account should not persist if the configuration fails (or should it?)
                    PopupUtils.open(
                        Qt.resolvedUrl("pages/ProgressConfigAccount.qml"),
                        chatlistPage,
                        { "title": i18n.tr('Configuring...') }
                    )
                } else {
                    PopupUtils.open(
                        Qt.resolvedUrl("pages/errorMessage.qml"),
                        chatlistPage,
                        { "title": i18n.tr('Error') }
                    )
                    setTempContextNull()
                }
            }
        }
    }

    Connections {
        target: DeltaHandler.notificationHelper
        onNewMessageForInactiveAccount: {
            root.inactiveAccsNewMsgsSinceLastCheck = true
            refreshOtherAccsIndicator()
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
            extraStack.clear()
            imageStack.clear()
            layout.removePages(layout.primaryPage)
            view.model = null
            DeltaHandler.shutdownTasks()
        }
    }

    Connections {
        target: DeltaHandler.contactsmodel
        onChatCreationSuccess: {
            bottomEdge.collapse()
        }
    }

    Connections {
        target: DeltaHandler.accountsmodel
        onInactiveFreshMsgsMayHaveChanged: {
            refreshOtherAccsIndicator()
        }

        onDeletedAccount: {
            accSwitcherSidebar.visible = root.showAccSwitchSidebar && DeltaHandler.numberOfAccounts() > 1
            if (!DeltaHandler.hasConfiguredAccount) {
                extraStack.push(Qt.resolvedUrl('pages/AccountConfig.qml'))
            }
        }
    }

    property bool hasTwoColumns: width > units.gu(90)
    property bool showAccSwitchSidebar: width > units.gu(120)

    onHasTwoColumnsChanged: {
        if (hasTwoColumns) {
            if (chatOpenAlreadyClicked) {
                chatOpenAlreadyClicked = false
            }
        }
    }

    Rectangle {
        id: accSwitcherSidebar
        width: root.scaledFontSizeInPixels*1.5 + units.gu(5)
        height: parent.height

        anchors {
            left: parent.left
            top: parent.top
        }

        visible: root.showAccSwitchSidebar && (DeltaHandler.numberOfAccounts() > 1)
        color:  theme.palette.highlighted.background

        ListView {
            id: switcherSidebarView
            anchors.fill: parent

            model: DeltaHandler.accountsmodel
            delegate: Loader {
                width: switcherSidebarView.width
                height: width
                property string sidebarColor: accSwitcherSidebar.color
                source: Qt.resolvedUrl("pages/SwitcherSidebarDelegate.qml")
            }
        }
    }

    AdaptivePageLayout {
        id: layout
        //anchors.fill: parent
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: accSwitcherSidebar.visible ? accSwitcherSidebar.right : parent.left
            right: parent.right
        }

        layouts: [
            PageColumnsLayout {
                when: root.hasTwoColumns
                // column #0
                PageColumn {
                    minimumWidth: units.gu(30)
                    preferredWidth: units.gu(50)
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
            
                property string currentUsername: DeltaHandler.hasConfiguredAccount ? (DeltaHandler.getCurrentUsername() == "" ? "" : DeltaHandler.getCurrentUsername()) : i18n.tr("No account configured")
                property string currentProfilePic: DeltaHandler.getCurrentProfilePic() == "" ? "" : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())
                //property string currentProfilePic: DeltaHandler.getCurrentProfilePic() == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())

                Connections {
                    target: DeltaHandler
                    onAccountChanged: {
                        headerRect.currentUsername = DeltaHandler.hasConfiguredAccount ? (DeltaHandler.getCurrentUsername() == "" ? "" : DeltaHandler.getCurrentUsername()) : i18n.tr("No account configured")
                        headerRect.currentProfilePic = DeltaHandler.getCurrentProfilePic() == "" ? "" : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())
                        //headerRect.currentProfilePic = DeltaHandler.getCurrentProfilePic() == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())
                        profilePicShape.color = DeltaHandler.getCurrentProfileColor()
                        bottomEdge.enabled = DeltaHandler.hasConfiguredAccount && !root.chatOpenAlreadyClicked
                        bottomEdgeHint.visible = DeltaHandler.hasConfiguredAccount
                        updateConnectivity()

                        refreshOtherAccsIndicator()
                    }

                    onAccountDataChanged: {
                        headerRect.currentUsername = DeltaHandler.hasConfiguredAccount ? (DeltaHandler.getCurrentUsername() == "" ? "" : DeltaHandler.getCurrentUsername()) : i18n.tr("No account configured")
                        headerRect.currentProfilePic = DeltaHandler.getCurrentProfilePic() == "" ? "" : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())
                        //headerRect.currentProfilePic = DeltaHandler.getCurrentProfilePic() == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())
                        profilePicShape.color = DeltaHandler.getCurrentProfileColor()
                    }
                }

                Rectangle {
                    id: profilePicAndNameRect

                    width: headerRect.width - searchIconCage.width - qrIconCage.width - settingsIconCage.width - units.gu(1)
                    height: headerTopBackgroundColor.height
                    anchors {
                        left: headerRect.left
                        top: headerRect.top
                    }
                    color: headerTopBackgroundColor.color

                    MouseArea {
                        id: headerMouse
                        anchors.fill: parent
                        onClicked: {
                            extraStack.push(Qt.resolvedUrl('pages/AccountConfig.qml'))
                            root.inactiveAccsNewMsgsSinceLastCheck = false
                        }
                        enabled: !root.chatOpenAlreadyClicked
                    }

                    LomiriShape {
                        id: profilePicShape
                        height: usernameLabel.contentHeight + units.gu(3)
                        width: height

                        anchors {
                            left: profilePicAndNameRect.left
                            leftMargin: units.gu(0.5)
                            top: profilePicAndNameRect.top
                            topMargin: units.gu(0.5)
                        }

                        color: DeltaHandler.getCurrentProfileColor()

                        source: headerRect.currentProfilePic === "" ? undefined : ownProfileImage

                        Image {
                            id: ownProfileImage
                            anchors.fill: parent
                            source: headerRect.currentProfilePic
                            visible: false
                        }

                        Label {
                            id: ownInitialLabel
                            visible: headerRect.currentProfilePic === ""
                            text: headerRect.currentUsername === "" ? "#" : headerRect.currentUsername.charAt(0).toUpperCase()
                            font.pixelSize: parent.height * 0.6
                            color: "white"
                            anchors.centerIn: parent
                        }

                        sourceFillMode: LomiriShape.PreserveAspectCrop
                        aspect: LomiriShape.Flat
                    } // end of LomiriShape id:profilePicShape
                
                    Label {
                        id: usernameLabel
                        anchors {
                            left: profilePicShape.right
                            leftMargin: units.gu(2.5)
                            bottom: parent.bottom
                            bottomMargin: units.gu(2)
                        }
                        width: parent.width - profilePicShape.width - (newMsgsInOtherAccsIndicator.visible ? newMsgsInOtherAccsIndicator.width + units.gu(1) : 0) - units.gu(3)
                        elide: Text.ElideRight
                        text: headerRect.currentUsername == '' ? i18n.tr('no username set') : headerRect.currentUsername

                        // needed for right-to-left text such as Arabic
                        horizontalAlignment: Text.AlignLeft
                        color: "#e7fcfd"
                        font.pixelSize: root.scaledFontSizeInPixels * 1.3
                    }
                } // Rectangle id: profilePicAndNameRect
                
                LomiriShape {
                    id: connectivityShape

                    height: profilePicShape.height * (2/5)
                    width: height
                    anchors {
                        left: parent.left
                        leftMargin: units.gu(0.5) + profilePicShape.width - (width * 0.35)
                        top: parent.top
                        topMargin: units.gu(0.25)
                    }

                    Icon {
                        id: connectivityIcon
                        //name: "sync"
                        source: "qrc:///assets/suru-icons/sync.svg"
                        width: connectivityShape.width * (0.9)
                        height: width
                        anchors{
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                        color: "black"
                    }
                } // end Rectangle id: connectivityShape

                LomiriShape {
                    id: newMsgsInOtherAccsIndicator
                    height: profilePicShape.height * (2/5)
                    width: height
                    anchors {
                        right: searchIconCage.left
                        rightMargin: units.gu(0.5)
                        verticalCenter: searchIconCage.verticalCenter
                    }
                    color: root.otherAccsIndicatorBackgroundColor
                    //aspect: LomiriShape.Flat
                    visible: hasNewMsgsInOtherAccs && !accSwitcherSidebar.visible

                    Label {
                        id: newMsgsInOtherAccsCountLabel
                        anchors {
                            top: parent.top
                            topMargin: units.gu(0.3)
                            horizontalCenter: parent.horizontalCenter
                        }
                        fontSize: root.scaledFontSizeSmaller
                        font.bold: true
                        color: root.otherAccsIndicatorTextColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: headerMouse.clicked(mouse)
                    }
                } // LomiriShape id: newMsgsInOtherAccsIndicator

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
                        //name: "find"
                        source: "qrc:///assets/suru-icons/find.svg"
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
                        right: settingsIconCage.left
                        top: profilePicAndNameRect.top
                        bottom: profilePicAndNameRect.bottom
                    }
                    color: headerTopBackgroundColor.color
            
                    Icon {
                        id: qrIcon
                        //name: "view-grid-symbolic"
                        source: "qrc:///assets/suru-icons/view-grid-symbolic.svg"
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
                        onClicked: extraStack.push(Qt.resolvedUrl('pages/InviteCode.qml'))
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
                        //name: "settings"
                        source: "qrc:///assets/suru-icons/settings.svg"
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
                        onClicked: extraStack.push(Qt.resolvedUrl('pages/SettingsPage.qml'))
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
                        //name: "close"
                        source: "qrc:///assets/suru-icons/close.svg"

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
                    //iconName: "delete"
                    iconSource: "qrc:///assets/suru-icons/delete.svg"
                    text: i18n.tr("Delete")
                    onTriggered: {
                        // the index is passed as parameter and can
                        // be accessed via 'value'
                        DeltaHandler.setMomentaryChatIdByIndex(value)

                        let popup7 = PopupUtils.open(
                            Qt.resolvedUrl('pages/ConfirmDialog.qml'),
                            chatlistPage,
                            { "dialogTitle": i18n.tr("Delete Chat"),
                              "dialogText": i18n.tr('Are you sure you want to delete \"%1\"?').arg(DeltaHandler.getMomentaryChatName()),
                              "okButtonText": i18n.tr("Delete Chat"),
                        })
                        popup7.confirmed.connect(function() {
                            DeltaHandler.deleteMomentaryChat()
                        })
                    }
                }
            }

            ListItemActions {
                id: trailingChatActions
                actions: [
                    Action {
                        //iconName: "folder-symbolic"
                        iconSource: "qrc:///assets/suru-icons/folder-symbolic.svg"
                        text: i18n.tr("Archive")
                        onTriggered: {
                            // the index is passed as parameter and can
                            // be accessed via 'value'
                            DeltaHandler.setMomentaryChatIdByIndex(value)

                            // TODO: In desktop mode, when right-clicking and choosing "Archive",
                            // the action is performed and the popover with the ListItemActions
                            // seems to vanish (as it should), it is actually still present in an
                            // invisible way, and (almost) no clicks have any effect except for
                            // clicks in the area of the invisible popover, which will trigger
                            // the actions as if the popover was still there.
                            // Temporary solution is to give the popover some time to close itself
                            // before the actual action is performed.
                            archiveMomentaryTimer.start()
                        }
                    },
                    Action {
                        //iconName: "pinned"
                        iconSource: "qrc:///assets/suru-icons/pinned.svg"
                        // TODO: Text should be "Unpin" if chat is already pinned. However,
                        // "value" (or "index") cannot be used here the same way as in
                        // onTriggered. Maybe the only way to solve this is to manually
                        // create the context menu instead of using the automatic one.
                        text: i18n.tr("Pin")
                        onTriggered: {
                            DeltaHandler.setMomentaryChatIdByIndex(value)
                            DeltaHandler.pinUnpinMomentaryChat()
                        }
                    },
                    Action {
                        //iconName: "navigation-menu"
                        iconSource: "qrc:///assets/suru-icons/navigation-menu.svg"
                        text: i18n.tr("More Options")
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
                        //iconName: "folder-symbolic"
                        iconSource: "qrc:///assets/suru-icons/folder-symbolic.svg"
                        text: i18n.tr("Unarchive")
                        onTriggered: {
                            DeltaHandler.setMomentaryChatIdByIndex(value)
                            // TODO: same as for archiveMomentaryTimer
                            unarchiveMomentaryTimer.start()
                        }
                    },
                    Action {
                        //iconName: "navigation-menu"
                        iconSource: "qrc:///assets/suru-icons/navigation-menu.svg"
                        text: i18n.tr("More Options")
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

                    //property var thisChatID: model.chatId
                    property var chatlistEntry: model.chatlistEntry; //JSON.parse(model.chatlistEntry)["result"]["" + thisChatID]
                    property bool isArchiveLink: chatlistEntry.kind === "ArchiveLink"
                    property string chatPicPath: ""
                    property var previewIconSource
                    property bool previewStatusActive
                    property string avatarInitial
                    property bool mouseHovers: hoverMouse.containsMouse
                    property int thisChatID: (JSON.parse(model.basicChatInfo)).result.id

                    onChatlistEntryChanged: {
                        isArchiveLink = chatlistEntry.kind === "ArchiveLink"
                        if (isArchiveLink) {
                            let chatInfo = JSON.parse(model.basicChatInfo)
                            setChatPic(chatInfo.result.profileImage)
                         } else {
                             setChatPic(chatlistEntry.avatarPath)
                         }

                         setPreviewStatusIcon()
                    }

                    function setChatPic(path) {
                       if (path != null) {
                           let lengthToSubtract = ("" + StandardPaths.writableLocation(StandardPaths.AppConfigLocation)).length - 6
                           let temp = path.substring(lengthToSubtract)
                           chatPicPath = StandardPaths.locate(StandardPaths.AppConfigLocation, temp)
                       } else {
                           chatPicPath = ""
                           if (chatlistEntry.name === "") {
                               avatarInitial = "#"
                           } else {
                               avatarInitial = chatlistEntry.name.charAt(0).toUpperCase()
                           }
                       }
                    }

                    function setPreviewStatusIcon() {
                        let tempstate = DeltaHandler.intToMessageStatus(chatlistEntry.summaryStatus)
                        switch (tempstate) {
                            case DeltaHandler.StatePending:
                                if (root.darkmode) {
                                    previewIconSource = Qt.resolvedUrl('../assets/dotted_circle.svg');
                                    break;
                                } else {
                                    previewIconSource = Qt.resolvedUrl('../assets/dotted_circle.svg');
                                    break;
                                }

                            case DeltaHandler.StateDelivered:
                                previewIconSource = Qt.resolvedUrl('../assets/sent_green.svg');
                                break;

                            case DeltaHandler.StateReceived:
                                previewIconSource = Qt.resolvedUrl('../assets/read_green.svg');
                                break;

                            case DeltaHandler.StateFailed:
                                previewIconSource = Qt.resolvedUrl('../assets/circled_x_red.svg');
                                break;
                        }

                        previewStatusActive = (tempstate === DeltaHandler.StatePending || tempstate === DeltaHandler.StateFailed || tempstate === DeltaHandler.StateDelivered || tempstate === DeltaHandler.StateReceived)
                    }

                    Component.onCompleted: {
                        if (isArchiveLink) {
                            // does not work, setChatPic is not accessible in the arrow expression
                            // TODO: why not? how to deal with this?
                            //JSONRPC.setSendRequest((request) => DeltaHandler.sendJsonrpcRequest(request))
                            //JSONRPC.client.getBasicChatInfo(model.accountId, thisChatID).then((chatInfo) => { setChatPic(chatInfo.profileImage) })
                            let chatInfo = JSON.parse(model.basicChatInfo)
                            setChatPic(chatInfo.result.profileImage)
                       } else {
                           setChatPic(chatlistEntry.avatarPath)
                       }

                       setPreviewStatusIcon()
                    }

                    // shall specify the height when Using ListItemLayout inside ListItem
                    height: chatlistLayout.height + (divider.visible ? divider.height : 0)
                    divider.visible: true
                    color: (root.activeChatId === thisChatID && chatViewIsOpen) ? root.selfMessageSeenBackgroundColor : (mouseHovers ? root.selfMessageSentBackgroundColor : "transparent")
                    //color: (root.activeChatId === thisChatID && chatViewIsOpen) ? theme.palette.normal.focus : (mouseHovers ? theme.palette.focused.background : "transparent")


                    onClicked: {
                        if (!root.chatOpenAlreadyClicked) {
                            if (!root.hasTwoColumns) {
                                root.chatOpenAlreadyClicked = true
                            }
                            DeltaHandler.selectChatByIndex(index)
                            DeltaHandler.openChat()
                        } 
                    }

                    MouseArea {
                        id: hoverMouse

                        // For some reason, on Ubuntu Touch, the first time the app is touched,
                        // containsMouse will become true for the touched ListItem and never
                        // become false again (test it by switching to the app and, e.g., begin
                        // sliding one list item in the chatlist, it will then turn its color
                        // to the hover color). As a workaround, on UT, changing the background
                        // on hovering is only enabled when showAccSwitchSidebar is true.
                        // TODO: find reason
                        enabled: !root.onUbuntuTouch || root.showAccSwitchSidebar
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    leadingActions: isArchiveLink ? null : leadingChatAction
                    trailingActions: isArchiveLink ? null : (chatlistEntry.isArchived ? trailingChatActionsArchived : trailingChatActions)

                    ListItemLayout {
                        id: chatlistLayout
                        title.text: isArchiveLink ? i18n.tr("Archived Chats") : chatlistEntry.name

                        // needed for right-to-left text such as Arabic
                        title.horizontalAlignment: Text.AlignLeft
                        title.font.bold: true
                        title.font.pixelSize: scaledFontSizeInPixels
                        title.color: (thisChatID === root.activeChatId && chatViewIsOpen) ? root.selfMessageSeenTextColor : (mouseHovers ? root.selfMessageSentTextColor : theme.palette.normal.backgroundText)
                        //title.color: (thisChatID === root.activeChatId && chatViewIsOpen) ? theme.palette.normal.focusText : (mouseHovers ? theme.palette.focused.backgroundText : theme.palette.normal.backgroundText)
                        subtitle.text: isArchiveLink ? null : ((chatlistEntry.summaryText1 === "" ? "" : chatlistEntry.summaryText1 + ": ") + chatlistEntry.summaryText2)
                        subtitle.horizontalAlignment: Text.AlignLeft
                        subtitle.font.pixelSize: scaledFontSizeInPixelsSmaller
                        subtitle.color: title.color

                        // need to explicitly set the height because otherwise,
                        // the height will increase when switching
                        // scaledFontSize from "medium" to "small" (why??)
                        height: chatPicShape.height + units.gu(1) + units.gu(scaleLevel * 0.25) + ((!onUbuntuTouch && scaledFontSize === "x-large") ? units.gu(2) : 0)

                        LomiriShape {
                            id: chatPicShape
                            SlotsLayout.position: SlotsLayout.Leading
                            height: units.gu(4) + units.gu(scaleLevel)
                            width: height
                            
                            source: chatPicPath !== "" ? chatPicImage : undefined 
                            Image {
                                id: chatPicImage
                                visible: false
                                source: chatPicPath
                            }

                            Label {
                                id: avatarInitialLabel
                                visible: chatPicPath === ""
                                text: avatarInitial
                                font.pixelSize: parent.height * 0.6
                                color: "white"
                                anchors.centerIn: parent
                            }

                            color: chatlistEntry.color
                            sourceFillMode: LomiriShape.PreserveAspectCrop
                            aspect: LomiriShape.Flat
                        }

                        Rectangle {
                            id: dateAndMsgCount
                            SlotsLayout.position: SlotsLayout.Trailing
                            width: (((verifiedIcon.visible ? verifiedIcon.width + units.gu(0.5) : 0) + (mutedIcon.visible ? mutedIcon.width + units.gu(0.5) : 0) + (pinnedIcon.visible ? pinnedIcon.width + units.gu(0.5) : 0) + timestamp.contentWidth) > contactRequestLabel.contentWidth ? ((verifiedIcon.visible ? verifiedIcon.width + units.gu(0.5) : 0) + (mutedIcon.visible ? mutedIcon.width + units.gu(0.5) : 0) + (pinnedIcon.visible ? pinnedIcon.width + units.gu(0.5) : 0) + timestamp.contentWidth) : contactRequestLabel.contentWidth) + units.gu(1)
                            height: units.gu(3) + units.gu(scaleLevel)
                            color: "transparent"
                            visible: !isArchiveLink

                            Icon {
                                id: verifiedIcon
                                height: timestamp.contentHeight
                                width: height

                                anchors {
                                    right: mutedIcon.visible ? mutedIcon.left : timestamp.left
                                    rightMargin: units.gu(0.5)
                                    top: dateAndMsgCount.top
                                }
                                source: "../assets/verified.svg"
                                visible: chatlistEntry.isProtected
                            }
 
                            Icon {
                                id: mutedIcon
                                height: timestamp.contentHeight
                                width: height
                                anchors {
                                    right: timestamp.left
                                    rightMargin: units.gu(0.5)
                                    top: dateAndMsgCount.top
                                }
                                //name: "audio-speakers-muted-symbolic"
                                source: "qrc:///assets/suru-icons/audio-speakers-muted-symbolic.svg"
                                color: chatlistLayout.title.color
                                visible: chatlistEntry.isMuted

                            }

                            Icon {
                                id: pinnedIcon
                                height: timestamp.contentHeight
                                width: height
                                anchors {
                                    right: dateAndMsgCount.right
                                    top: dateAndMsgCount.top
                                }
                                //name: "pinned"
                                source: "qrc:///assets/suru-icons/pinned.svg"
                                color: chatlistLayout.title.color
                                visible: chatlistEntry.isPinned

                            }

                            Label {
                                id: timestamp
                                text: isArchiveLink ? "" : (chatlistEntry.lastUpdated !== null ? DeltaHandler.timeToString(chatlistEntry.lastUpdated, true) : "")
                                anchors {
                                    right: pinnedIcon.visible ? pinnedIcon.left : dateAndMsgCount.right
                                    rightMargin: pinnedIcon.visible ? units.gu(0.5) : 0
                                    top: dateAndMsgCount.top
                                    topMargin: units.gu(0.2)
                                }
                                fontSize: root.scaledFontSizeSmaller
                                color: chatlistLayout.title.color
                            }

                            Component {
                                id: previewIcon
                                Icon {
                                    source: previewIconSource
                                    color: chatlistLayout.title.color
                                }
                            }

                            Loader {
                                id: previewStatusLoader
                                //active: chatlistEntry.summaryStatus !== DeltaHandler.StateUnknown && !chatlistEntry.isContactRequest && chatlistEntry.freshMessageCounter === 0
                                active: previewStatusActive
                                height: timestamp.height
                                width: height * 2

                                anchors {
                                    top: timestamp.bottom
                                    topMargin: units.gu(0.6) + units.gu(scaleLevel/10)
                                    right: dateAndMsgCount.right
                                    //rightMargin: units.gu(1)
                                }

                                sourceComponent: previewIcon
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
                                    }
                                    text: i18n.tr('Request')
                                    fontSize: root.scaledFontSizeSmaller
                                    color: "white"
                                }
                                color: root.unreadMessageCounterColor
                                border.color: contactRequestLabel.color
                                visible: chatlistEntry.isContactRequest
                            } // Rectangle id: contactRequestRect

                            LomiriShape {
                                id: newMsgCountShape
                                height: newMsgCountLabel.height + units.gu(0.6)
                                width: height

                                anchors {
                                    top: timestamp.bottom
                                    topMargin: units.gu(0.3) + units.gu(scaleLevel/10)
                                    right: dateAndMsgCount.right
                                    //rightMargin: units.gu(1)
                                }
                                backgroundColor: chatlistEntry.isMuted ? (root.darkmode ? "#202020" : "#e0e0e0") : root.unreadMessageCounterColor
                                
                                visible: !chatlistEntry.isContactRequest && chatlistEntry.freshMessageCounter > 0

                                Label {
                                    id: newMsgCountLabel
                                    anchors {
                                        top: newMsgCountShape.top
                                        topMargin: units.gu(0.3)
                                        horizontalCenter: newMsgCountShape.horizontalCenter
                                    }
                                    text: chatlistEntry.freshMessageCounter > 99 ? "99+" : chatlistEntry.freshMessageCounter
                                    fontSize: root.scaledFontSizeSmaller
                                    font.bold: true
                                    color: chatlistEntry.isMuted && !root.darkmode ? "black" : "white"
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
                height: chatlistPage.height - headerRect.height - bottomEdgeHint.height - (showArchiveCloseLine ? archivedChatsItem.height : 0)
                model: DeltaHandler
                delegate: delegateListItem

                LomiriShape {
                    id: toTopButton
                    anchors {
                        right: view.right
                        rightMargin: units.gu(4)
                        bottom: view.bottom
                        bottomMargin: units.gu(4)
                    }
                    backgroundColor: "#F7F7F7"
                    opacity: 0.5
                    visible: isScrolled

                    property bool isScrolled: view.visibleArea.yPosition != 0

                    width: units.gu(5)
                    height: width

                        Icon {
                            id: toTopIcon
                            width: parent.width - units.gu(1)
                            height: width
                            //name: "go-up"
                            source: "qrc:///assets/suru-icons/go-up.svg"
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
                } // end LomiriShape id: toTopButton
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
                    //iconName: "compose"
                    iconSource: "qrc:///assets/suru-icons/compose.svg"
                    onStatusChanged: if (status === BottomEdgeHint.Inactive) bottomEdge.hint.status = (showBottomEdgeHint ? BottomEdgeHint.Locked : BottomEdgeHint.Active)
                    visible: DeltaHandler.hasConfiguredAccount
                }
            }
        } // end of Page id: chatlistPage
    } // end of AdaptivePageLayout id: layout

    Rectangle {
        id: backgroundForImageStack
        anchors.fill: imageStack
        color: theme.palette.normal.background
        visible: imageStack.depth !== 0

        MouseArea {
            // to prevent clicks + scrolls reaching the AdaptivePageLayout below
            anchors.fill: parent
            onWheel: wheel.accepted = true
            acceptedButtons: Qt.AllButtons
        }
    }

    PageStack {
        id: imageStack
        anchors.fill: parent
    }

    Rectangle {
        id: transparencyAroundPageStack
        anchors.fill: parent
        color: root.darkmode ? "white" : "black"
        opacity: 0.8
        visible: extraStack.depth !== 0    

        MouseArea {
            // to prevent clicks + scrolls reaching the AdaptivePageLayout below
            anchors.fill: parent
            onWheel: wheel.accepted = true
            acceptedButtons: Qt.AllButtons
        }
    }

    Rectangle {
        id: backgroundForExtraStack
        anchors.fill: extraStack
        color: theme.palette.normal.background
        visible: extraStack.depth !== 0    
    }
    
    PageStack {
        // for everything except chatlist, chatview and images
        id: extraStack
        width: parent.width > units.gu(90) ? units.gu(80) : parent.width
        //height: parent.height
        anchors {
            fill: undefined
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            bottom: parent.bottom
        }
    }

    // lock the bottom edge hint for the first 10 seconds
    Timer {
        id: hintTimer
        interval: 10000
        repeat: false
        triggeredOnStart: false
        onTriggered: showBottomEdgeHint = false
    }

    // see ListItemActions above
    Timer {
        id: archiveMomentaryTimer
        interval: 500
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            DeltaHandler.archiveMomentaryChat()
        }
    }

    // see ListItemActions above
    Timer {
        id: unarchiveMomentaryTimer
        interval: 500
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            DeltaHandler.unarchiveMomentaryChat()
        }
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
        onUbuntuTouch = DeltaHandler.onUbuntuTouch()
        oskViaDbus = DeltaHandler.shouldOpenOskViaDbus()

        i18n.domain = "deltatouch.lotharketterer"
        if (onUbuntuTouch) {
            // on Ubuntu Touch, CMAKE_INSTALL_FULL_LOCALEDIR is "/./share/locale"
            console.log("Main.qml: Calling i18n.bindtextdomain(\"deltatouch.lotharketterer\", ", "." + i18nDirectory)
            i18n.bindtextdomain("deltatouch.lotharketterer", "." + i18nDirectory)
        } else {
            i18n.bindtextdomain("deltatouch.lotharketterer", i18nDirectory)
            console.log("Main.qml: Calling i18n.bindtextdomain(\"deltatouch.lotharketterer\", ", i18nDirectory, ")")
        }
        console.log("Main.qml: i18n.language is ", i18n.language)

        darkmode = (theme.name == "Lomiri.Components.Themes.SuruDark")
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
