/*
 * Copyright (C) 2022 - 2024 Lothar Ketterer
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
import QtQuick.Layouts 1.3
import Lomiri.Components.Popups 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import QtMultimedia 5.12
import QtQml.Models 2.12

import DeltaHandler 1.0

Page {
    id: settingsPage

    Component.onDestruction: {
        
    }

    Component.onCompleted: {
        offlineSwitch.checked = root.syncAll
        updateShowClassicMailsCurrentSetting()
        updateAutoDownloadCurrentSetting()
        updateDeleteFromDeviceCurrentSetting()
        updateDeleteFromServerCurrentSetting()
        updateConnectivity()
    }

    property string showClassicMailsCurrentSetting: ""
    property string autoDownloadCurrentSetting: ""
    property string deleteFromDeviceCurrentSetting: ""
    property string deleteFromServerCurrentSetting: ""

    function updateConnectivity() {
        let conn = DeltaHandler.getConnectivitySimple()
        if (conn >= 1000 && conn < 2000) {
            connectivityLayout.summary.text = i18n.tr("Not connected")
        } else if (conn >= 2000 && conn < 3000) {
            connectivityLayout.summary.text = i18n.tr("Connecting…")
        } else if (conn >= 3000 && conn < 4000) {
            connectivityLayout.summary.text = i18n.tr("Updating…")
        } else if (conn >= 4000) {
            connectivityLayout.summary.text = i18n.tr("Connected")
        } else {
            connectivityLayout.summary.text = "??"
        }
    }

    function backupExportFinished() {
        DeltaHandler.removeTempExportFile()
    }

    // Opens the file export dialog once the backup
    // file has been written to the cache.
    function startFileExport()
    {
        // different code depending on platform
        if (root.onUbuntuTouch) {
            // Ubuntu Touch
            // In contrast to to other file exports, the temporary
            // backup file should be removed from the cache. Connect
            // the success and cancelled signal from FileExportDialog
            // to the function that removes the temp file.
            let tempBackupPath = StandardPaths.locate(StandardPaths.CacheLocation, DeltaHandler.getUrlToExport())
            let popup8 = extraStack.push(Qt.resolvedUrl('FileExportDialog.qml'), { "url": tempBackupPath, "conType": DeltaHandler.FileType })

            popup8.success.connect(settingsPage.backupExportFinished)
            popup8.cancelled.connect(settingsPage.backupExportFinished)

        } else {
            // non-Ubuntu Touch
            fileExpLoader.source = "FileExportDialog.qml"

            // TODO: String not translated yet
            fileExpLoader.item.title = "Choose folder to save backup"
            fileExpLoader.item.setFileType(DeltaHandler.FileType)
            fileExpLoader.item.open()
        }
    }

    Loader {
        // Only for non-Ubuntu Touch platforms
        id: fileExpLoader
    }

    Connections {
        // Only for non-Ubuntu Touch platforms
        target: fileExpLoader.item
        onFolderSelected: {
            let exportedPath = DeltaHandler.saveBackupFile(urlOfFolder)
            showExportSuccess(exportedPath)
            fileExpLoader.source = ""
            backupExportFinished()
        }
        onCancelled: {
            fileExpLoader.source = ""
            backupExportFinished()
        }
    }

    function showExportSuccess(exportedPath) {
        // Only for non-Ubuntu Touch platforms
        if (exportedPath === "") {
            // error, file was not exported
            PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"),
            settingsPage,
            // TODO: string not translated yet
            {"text": i18n.tr("File could not be saved") , "title": i18n.tr("Error") })
        } else {
            let popup10 = PopupUtils.open(Qt.resolvedUrl("InfoPopup.qml"),
            settingsPage,
            // TODO: string not translated yet
            {"text": i18n.tr("Saved file ") + exportedPath })
            popup10.done.connect(function() { extraStack.clear() })
        }
    }

    // Updating the displayed setting for "Show Classic Emails",
    // see Label with id: showClassicMailsLabel
    function updateShowClassicMailsCurrentSetting()
    {
        switch (DeltaHandler.getCurrentConfig("show_emails")) {
            case "0":
                showClassicMailsCurrentSetting = i18n.tr("No, chats only")
                break
            case "1":
                showClassicMailsCurrentSetting = i18n.tr("For accepted contacts")
                break
            case "2":
                showClassicMailsCurrentSetting = i18n.tr("All")
                break
            default:
                showClassicMailsCurrentSetting = "?"
                break
        }
    }

    function updateAutoDownloadCurrentSetting() {
        switch (DeltaHandler.getCurrentConfig("download_limit")) {
            case "0":
                autoDownloadCurrentSetting = i18n.tr("All")
                break;

            case "40960":
                autoDownloadCurrentSetting = i18n.tr("Up to %1").arg("40 KiB")
                break;

            case "163840":
                autoDownloadCurrentSetting = i18n.tr("Up to %1, most worse quality images").arg("160 KiB")
                break;


            case "655360":
                autoDownloadCurrentSetting = i18n.tr("Up to %1, most balanced quality images").arg("640 KiB")
                break;

            case "5242880":
                autoDownloadCurrentSetting = i18n.tr("Up to %1").arg("5 MiB")
                break;

            case "26214400":
                autoDownloadCurrentSetting = i18n.tr("Up to %1").arg("25 MiB")
                break;

            default:
                autoDownloadCurrentSetting = "?"
                break;
        }
    }
    
    function updateDeleteFromDeviceCurrentSetting() {
        switch (DeltaHandler.getCurrentConfig("delete_device_after")) {
            case "0":
                deleteFromDeviceCurrentSetting = i18n.tr("Never")
                break;

            case "3600":
                deleteFromDeviceCurrentSetting = i18n.tr("After 1 hour")
                break;

            case "86400":
                deleteFromDeviceCurrentSetting = i18n.tr("After 1 day")
                break;

            case "604800":
                deleteFromDeviceCurrentSetting = i18n.tr("After 1 week")
                break;

            case "2419200":
                deleteFromDeviceCurrentSetting = i18n.tr("After 4 weeks")
                break;

            case "31536000":
                deleteFromDeviceCurrentSetting = i18n.tr("After 1 year")
                break;

            default: 
                deleteFromDeviceCurrentSetting = i18n.tr("?")
                break;
        }
    }

    function updateDeleteFromServerCurrentSetting() {
        switch (DeltaHandler.getCurrentConfig("delete_server_after")) {
            case "0":
                deleteFromServerCurrentSetting = i18n.tr("Never")
                break;

            case "1":
                deleteFromServerCurrentSetting = i18n.tr("At once")
                break;

            case "30":
                deleteFromServerCurrentSetting = i18n.tr("After 30 seconds")
                break;

            case "60":
                deleteFromServerCurrentSetting = i18n.tr("After 1 minute")
                break;

            case "3600":
                deleteFromServerCurrentSetting = i18n.tr("After 1 hour")
                break;

            case "86400":
                deleteFromServerCurrentSetting = i18n.tr("After 1 day")
                break;

            case "604800":
                deleteFromServerCurrentSetting = i18n.tr("After 1 week")
                break;

            case "2419200":
                deleteFromServerCurrentSetting = i18n.tr("After 4 weeks")
                break;

            case "31536000":
                deleteFromServerCurrentSetting = i18n.tr("After 1 year")
                break;

            default: 
                deleteFromServerCurrentSetting = i18n.tr("?")
                break;
        }
    }

    /* ==========================================================
     * ===== Functions related to encryption of database ========
     * ========================================================== */
     
    function uncheckEncryptDatabaseSwitch() {
        // Called if any popup during the stages for encryption is
        // cancelled. In this case, the switch has to be unset again.
        encryptDatabaseSwitch.checked = false
    }

    function encryptDatabaseStage1() {
        if (!DeltaHandler.hasDatabasePassphrase()) {
            // No phassphrase known to DeltaHandler, so a new one is set up
            let popup2 = PopupUtils.open(Qt.resolvedUrl("CreateDatabasePassword.qml"), settingsPage)
            popup2.success.connect(encryptDatabaseStage2)
            popup2.cancelled.connect(uncheckEncryptDatabaseSwitch)
        } else {
            // Passphrase already set in DeltaHandler, use it
            // TODO: is this case possible?
            encryptDatabaseStage2() 
        }
    }

    function encryptDatabaseStage2() {
        let numberUnencryptedAccounts = DeltaHandler.numberOfAccounts() - DeltaHandler.numberOfEncryptedAccounts()
        if (numberUnencryptedAccounts > 0) {
            let popup6 = PopupUtils.open(
                Qt.resolvedUrl('ConfirmDialog.qml'),
                settingsPage,
                { "dialogText": i18n.tr("The existing account(s) will now be encrypted. This will take some time. Make sure that the app stays in foreground, and prevent the screen from locking."),
                  "okButtonText": i18n.tr("Continue"),
            })

            popup6.confirmed.connect(encryptDatabaseStage3)
            popup6.cancelled.connect(function() {
                    uncheckEncryptDatabaseSwitch()
                    if (!DeltaHandler.hasEncryptedAccounts()) {
                        // Previously in stage 1, a database key has
                        // been generated. If there's no encrypted account,
                        // cancelling at this stage has to reset the passphrase,
                        // as the user might want to choose a different one when
                        // setting the switch to encrypted at a later time.
                        DeltaHandler.invalidateDatabasePassphrase()
                    }
                })
        } else {
            // There's no account to encrypt. Adapt the setting now as the 
            // user has confirmed all stages. Nothing else to do.
            DeltaHandler.changeEncryptedDatabaseSetting(encryptDatabaseSwitch.checked)
        }
    }

    function encryptDatabaseStage3() {
        // The user has confirmed all stages, adapt the setting now. Even if the conversion
        // fails, the setting should now persist. If the conversion failed or
        // was interrupted, it will be tried to finish it at next startup of the app.
        DeltaHandler.changeEncryptedDatabaseSetting(encryptDatabaseSwitch.checked)
        let popup7 = PopupUtils.open(Qt.resolvedUrl("ProgressDatabaseEncryption.qml"), settingsPage)
        popup7.success.connect(encryptDatabaseStage4)
        // Cleanup needed even in case of failure. Currently no differentiation of
        // success or failure at this stage.
        popup7.failed.connect(encryptDatabaseStage4)
    }

    function encryptDatabaseStage4() {
        // workflow has finished (or failed), clean up
        DeltaHandler.databaseEncryptionCleanup()
    }

    /* =============== END encryption of database =============== */


    /* ==========================================================
     * ===== Functions related to decryption of database ========
     * ========================================================== */

    function recheckEncryptDatabaseSwitch() {
        // Called if the popup to disable database encryption is
        // cancelled. In this case, the switch has to be set again.
        encryptDatabaseSwitch.checked = true
    }

    function decryptDatabaseStage1() {
        // tell the user that all encrypted accounts will now
        // be decrypted (can be cancelled)
        if (DeltaHandler.hasEncryptedAccounts()) {
            let popup9 = PopupUtils.open(
                Qt.resolvedUrl('ConfirmDialog.qml'),
                settingsPage,
                { "dialogText": i18n.tr("The existing account(s) will now be decrypted. This will take some time. Make sure that the app stays in foreground, and prevent the screen from locking."),
                  "okButtonText": i18n.tr("Continue"),
            })

            popup9.confirmed.connect(decryptDatabaseStage2)
            popup9.cancelled.connect(function() {
                    recheckEncryptDatabaseSwitch()
                })
        } else {
            DeltaHandler.invalidateDatabasePassphrase()
            DeltaHandler.changeEncryptedDatabaseSetting(encryptDatabaseSwitch.checked)
            // nothing else to do
        }
    }

    function decryptDatabaseStage2() {
        // starts the workflow to decrypt the accounts
        DeltaHandler.changeEncryptedDatabaseSetting(encryptDatabaseSwitch.checked)
        let popup11 = PopupUtils.open(Qt.resolvedUrl("ProgressDatabaseDecryption.qml"), settingsPage)
        popup11.success.connect(decryptDatabaseStage3)
        popup11.failed.connect(decryptDatabaseStage3)
    }

    function decryptDatabaseStage3() {
        // Workflow has finished (or failed), clean up
        // Passphrase needs to be reset now, but only if there
        // are no encrypted accounts left.
        if (!DeltaHandler.hasEncryptedAccounts()) {
            DeltaHandler.invalidateDatabasePassphrase()
        }
        DeltaHandler.databaseDecryptionCleanup()
    }

    /* =============== END decryption of database =============== */


    header: PageHeader {
        id: settingsHeader
        title: i18n.tr("Settings")

        leadingActionBar.actions: [
            Action {
                //iconName: "close"
                iconSource: "qrc:///assets/suru-icons/close.svg"
                text: i18n.tr("Close")
                onTriggered: {
                    extraStack.pop()
                }
            }
        ]

        //trailingActionBar.numberOfSlots: 2
        trailingActionBar.actions: [
//          //  Action {
//          //      //iconName: 'help'
//          //      iconSource: 'qrc:///assets/suru-icons/help.svg'
//          //      text: i18n.tr('Help')
//          //      onTriggered: {
//          //          layout.addPageToCurrentColumn(settingsPage, Qt.resolvedUrl('Help.qml'))
//          //      }
//          //  },
            Action {
                //iconName: 'info'
                iconSource: "qrc:///assets/suru-icons/info.svg"
                text: i18n.tr('About DeltaTouch')
                onTriggered: {
                    extraStack.push(Qt.resolvedUrl('About.qml'))
                }
            }
        ]
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.topMargin: (settingsPage.header.flickable ? 0 : settingsPage.header.height)
        //anchors.bottomMargin: units.gu(2)
        contentHeight: flickContent.childrenRect.height

        Column {
            id: flickContent
            width: parent.width

            Rectangle {
                id: allAccountsSeparator
                height: profileSpecificSeparatorLabel.contentHeight + units.gu(4)
                width: parent.width
                Label {
                    id: allAccountsSeparatorLabel
                    anchors {
                        top: allAccountsSeparator.top
                        topMargin: units.gu(3)
                        horizontalCenter: allAccountsSeparator.horizontalCenter
                    }
                    text: i18n.tr("All Accounts")
                    //font.bold: true
                    fontSize: "large"
                }
                color: theme.palette.normal.background
            }

            ListItem {
                height: offlineLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: offlineLayout
                    title.text: i18n.tr("Sync All")
                    title.font.bold: true

                    Switch {
                        id: offlineSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        onCheckedChanged: {
                            // avoid actions upon initial setting of switch
                            // because this will trigger checkedChanged, too
                            if (offlineSwitch.checked != root.syncAll) {
                                root.syncAll = offlineSwitch.checked
                                root.startStopIO()
                            }
                        }
                    }
                }
            }

            ListItem {
                height: accountsItemLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: accountsItemLayout
                    title.text: i18n.tr("Known Accounts")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    extraStack.push(Qt.resolvedUrl("AccountConfig.qml"))
                }
            }

            ListItem {
                id: textZoomItem
                height: textZoomLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: textZoomLayout
                    title.text: i18n.tr("Message Font Size")
                    title.font.bold: true

                    Label {
                        id: textZoomLabel
                        width: settingsPage.width/4
                        text: {
                            switch (root.scaleLevel) {
                                case 1:
                                    return i18n.tr("Small");
                                    break;
                                case 2:
                                    return i18n.tr("Normal");
                                    break;
                                case 3:
                                    return i18n.tr("Large");
                                    break;
                                case 4:
                                    return i18n.tr("Extra large");
                                    break;
                            }
                        }

                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentTextZoom, textZoomItem)
                }
            }

            ListItem {
                height: enterKeySendsLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width
                divider.visible: true

                ListItemLayout {
                    id: enterKeySendsLayout
                    title.text: i18n.tr("Enter Key Sends")
                    title.font.bold: true
                    summary.text: i18n.tr("Pressing the Enter key will send text messages")
                    summary.wrapMode: Text.WordWrap

                    Switch {
                        id: enterKeySendsSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: root.enterKeySends
                        onCheckedChanged: {
                            if (enterKeySendsSwitch.checked != root.enterKeySends) {
                                root.enterKeySends = enterKeySendsSwitch.checked
                            }
                        }
                    }
                }
            }

            ListItem {
                height: expSettings.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: expSettings
                    title.text: i18n.tr("Experimental Features")
                    title.font.bold: true

                    Switch {
                        id: expSettingsSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: root.showAccountsExperimentalSettings
                        onCheckedChanged: {
                            // avoid actions upon initial setting of switch
                            // because this will trigger checkedChanged, too
                            if (checked != root.showAccountsExperimentalSettings) {
                                root.showAccountsExperimentalSettings = checked
                            }
                        }
                        enabled: !checked || !encryptDatabaseSwitch.checked
                    }
                }
            }

            Rectangle {
                id: databaseEncryptionHeader
                height: databaseEncryptionSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: databaseEncryptionSectionHeaderLabel
                    anchors {
                        top: databaseEncryptionHeader.top
                        topMargin: units.gu(3)
                        left: databaseEncryptionHeader.left
                        leftMargin: units.gu(2)
                    }
                    // TODO: String not translated yet
                    text: i18n.tr("Database Encryption")
                    font.bold: true
                }
                visible: root.showAccountsExperimentalSettings
                color: theme.palette.normal.background
            }

            ListItem {
                id: encryptDatabaseItem
                height: encryptDatabaseLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width
                divider.visible: false
                visible: root.showAccountsExperimentalSettings

                ListItemLayout {
                    id: encryptDatabaseLayout
                    // TODO: String not translated yet
                    title.text: i18n.tr("Encrypted Database (experimental)")

                    Switch {
                        id: encryptDatabaseSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: DeltaHandler.databaseIsEncryptedSetting()
                        onCheckedChanged: {
                            if (checked != DeltaHandler.databaseIsEncryptedSetting()) {
                                // Conversion of accounts from encrypted to unencrypted
                                // or vice versa depends on them being exportable.
                                // Unconfigured accounts cannot be exported, so 
                                // a corresponding info message is shown to the user,
                                // and no conversion is done if unconfigured accounts exist.
                                let numberUnconfiguredAccounts = DeltaHandler.numberOfUnconfiguredAccounts()
                                if (numberUnconfiguredAccounts === 1) {
                                    PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"),
                                        settingsPage,
                                        {"text": i18n.tr("One unconfigured account exists. Unconfigured accounts cannot be converted. Please configure all unconfigured accounts or remove them prior to changes to this setting.")
                                    })

                                    // reset the switch
                                    checked = DeltaHandler.databaseIsEncryptedSetting()

                                } else if (numberUnconfiguredAccounts > 1) {
                                    PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"),
                                        settingsPage,
                                        {"text": numberUnconfiguredAccounts + i18n.tr(" unconfigured accounts exist. Unconfigured accounts cannot be converted. Please configure all unconfigured accounts or remove them prior to changes to this setting.")
                                    })

                                    // reset the switch
                                    checked = DeltaHandler.databaseIsEncryptedSetting()

                                } else {
                                    // no unconfigured accounts, start with conversion
                                    if (checked) {
                                        // this popup will inform that db encryption is experimental, blobs are
                                        // not encrypted, nobody can help if pw is lost etc.
                                        let popup4 = PopupUtils.open(
                                            Qt.resolvedUrl('ConfirmDialog.qml'),
                                            settingsPage,
                                            { "dialogTitle": i18n.tr("Really encrypt the database?"),
                                              "dialogText": DeltaHandler.numberOfAccounts() > 0 ?  i18n.tr("• Database encryption is experimental, use at your own risk. BACKUP YOUR ACCOUNTS OR ADD A SECOND DEVICE FIRST.\n\n• It will only cover text messages and username/password of your accounts. Pictures, voice messages, files etc. will remain unencrypted.\n\n• If the phassphrase is lost, your data will be lost as well.\n\n• You will have to enter the phassphrase upon each startup of the app.") : i18n.tr("• Database encryption is experimental, use at your own risk.\n\n• It will only cover text messages and username/password of your accounts. Pictures, voice messages, files etc. will remain unencrypted.\n\n• If the phassphrase is lost, your data will be lost as well.\n\n• You will have to enter the phassphrase upon each startup of the app."),
                                              "okButtonText": i18n.tr("Continue"),
                                        })

                                        popup4.confirmed.connect(encryptDatabaseStage1)
                                        popup4.cancelled.connect(uncheckEncryptDatabaseSwitch)
                                    } else {
                                        let popup5 = PopupUtils.open(
                                            Qt.resolvedUrl('ConfirmDialog.qml'),
                                            settingsPage,
                                            { "dialogText": i18n.tr("Really disable database encryption?"),
                                              "okButtonText": i18n.tr("Disable encryption"),
                                        })

                                        popup5.confirmed.connect(decryptDatabaseStage1)
                                        popup5.cancelled.connect(recheckEncryptDatabaseSwitch)
                                    }
                                }
                            } // end if (checked != DeltaHandler.databaseIsEncryptedSetting())
                        } // end onCheckedChanged
                    } // end Switch id: encryptDatabaseSwitch
                }
            }

            ListItem {
                id: changeDatabasePasswordItem
                height: changeDbPwLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width
                visible: root.showAccountsExperimentalSettings

                ListItemLayout {
                    id: changeDbPwLayout
                    // TODO: String not translated yet
                    title.text: i18n.tr("Change Database Passphrase")

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                enabled: encryptDatabaseSwitch.checked
                onClicked: {
                    PopupUtils.open(Qt.resolvedUrl("ChangeDatabasePassword.qml"))
                }
            }

            Rectangle {
                id: prefNotifsSectionHeader
                height: prefNotifsSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefNotifsSectionHeaderLabel
                    anchors {
                        top: prefNotifsSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefNotifsSectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Notifications")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                height: sysNotifsEnabledLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: sysNotifsEnabledLayout
                    title.text: i18n.tr("Notifications")
                    summary.text: i18n.tr("Enable system notifications for new messages")
                    summary.wrapMode: Text.WordWrap

                    Switch {
                        id: sysNotifsEnabledSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: root.sendPushNotifications
                        onCheckedChanged: {
                            if (sysNotifsEnabledSwitch.checked != root.sendPushNotifications) {
                            // need to check whether it is really needed to change the setting
                            // because checkedChanged is be emitted when setting the switch at
                            // initialization
                                root.sendPushNotifications = sysNotifsEnabledSwitch.checked
                                DeltaHandler.notificationHelper.setEnablePushNotifications(root.sendPushNotifications)
                                if (root.sendPushNotifications && root.onUbuntuTouch) {
                                    PopupUtils.open(
                                        Qt.resolvedUrl('InfoPopup.qml'),
                                        null,
                                        { text: i18n.tr("To receive system notifications, background suspension must be disabled for the app and the app must be running.") }
                                    )

                                }
                            }
                        }
                    }
                }
            }

            ListItem {
                height: sysNotifsDetailedLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: sysNotifsDetailedLayout
                    title.text: i18n.tr("Show message content in notification")
                    summary.text: i18n.tr("Shows sender and first words of the message in notifications")
                    summary.wrapMode: Text.WordWrap
                    enabled: root.sendPushNotifications

                    Switch {
                        id: sysNotifsDetailedSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: root.detailedPushNotifications
                        onCheckedChanged: {
                            if (sysNotifsDetailedSwitch.checked != root.detailedPushNotifications) {
                                root.detailedPushNotifications = sysNotifsDetailedSwitch.checked
                                DeltaHandler.notificationHelper.setDetailedPushNotifications(root.detailedPushNotifications)
                            }
                        }
                    }
                }
            }

            ListItem {
                height: notifContactReqLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width
                divider.visible: true

                ListItemLayout {
                    id: notifContactReqLayout
                    // TODO string not translated yet
                    title.text: i18n.tr("Contact requests")
                    // TODO string not translated yet
                    summary.text: i18n.tr("Include contact requests in counters and notifications")
                    summary.wrapMode: Text.WordWrap

                    Switch {
                        id: notifyContRequSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: root.notifyContactRequests
                        onCheckedChanged: {
                            if (notifyContRequSwitch.checked != root.notifyContactRequests) {
                                root.notifyContactRequests = notifyContRequSwitch.checked
                                DeltaHandler.notificationHelper.setNotifyContactRequests(root.notifyContactRequests)
                                root.refreshOtherAccsIndicator()
                            }
                        }
                    }
                }
            }

            ListItem {
                height: aboutLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: aboutLayout
                    title.text: i18n.tr("About DeltaTouch")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    extraStack.push(Qt.resolvedUrl("About.qml"))
                }
            }

            Rectangle {
                id: profileSpecificSeparator
                height: profileSpecificSeparatorLabel.contentHeight + units.gu(4)
                width: parent.width
                Label {
                    id: profileSpecificSeparatorLabel
                    anchors {
                        top: profileSpecificSeparator.top
                        topMargin: units.gu(3)
                        horizontalCenter: profileSpecificSeparator.horizontalCenter
                    }
                    text: i18n.tr("Current Account")
                    //font.bold: true
                    fontSize: "large"
                }
                color: theme.palette.normal.background
            }

//            Rectangle {
//                id: prefBlockedSectionHeader
//                height: prefBlockedSectionHeaderLabel.contentHeight + units.gu(3)
//                width: parent.width
//                Label {
//                    id: prefBlockedSectionHeaderLabel
//                    anchors {
//                        top: prefBlockedSectionHeader.top
//                        topMargin: units.gu(3)
//                        left: prefBlockedSectionHeader.left
//                        leftMargin: units.gu(1)
//                    }
//                    // TODO: string not translated
//                    // TODO: maybe solve issue in a different way?
//                    text: i18n.tr("Blocked Contacts")
//                    font.bold: true
//                }
//                color: theme.palette.normal.background
//            }

            ListItem {
                height: blockedContactsLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: blockedContactsLayout
                    title.text: i18n.tr("Blocked Contacts")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    DeltaHandler.prepareBlockedContactsModel()
                    // the BlockedContacts page will be opened when
                    // the signal blockedcontactsmodelChanged is received
                    // see Connections below
                }
                enabled: DeltaHandler.hasConfiguredAccount
            }

//            Rectangle {
//                id: prefProfileSectionHeader
//                height: prefProfileSectionHeaderLabel.contentHeight + units.gu(3)
//                width: parent.width
//                Label {
//                    id: prefProfileSectionHeaderLabel
//                    anchors {
//                        top: prefProfileSectionHeader.top
//                        topMargin: units.gu(3)
//                        left: prefProfileSectionHeader.left
//                        leftMargin: units.gu(1)
//                    }
//                    // TODO: string not translated
//                    // TODO: maybe solve issue in a different way?
//                    text: i18n.tr("Profile")
//                    font.bold: true
//                }
//                color: theme.palette.normal.background
//            }

            ListItem {
                height: profilesLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: profilesLayout
                    title.text: i18n.tr("Edit Profile")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    if (DeltaHandler.hasConfiguredAccount) {
                        extraStack.push(Qt.resolvedUrl("ProfileSelf.qml"))
                    }
                }
            }

            Rectangle {
                id: prefChatsSectionHeader
                height: prefChatsSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefChatsSectionHeaderLabel
                    anchors {
                        top: prefChatsSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefChatsSectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Chats")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: showClassicMailsItem
                height: showClassicMailsLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: showClassicMailsLayout
                    title.text: i18n.tr("Show Classic E-Mails")

                    Label {
                        id: showClassicMailsLabel
                        width: settingsPage.width/4
                        text: showClassicMailsCurrentSetting
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentClassicMail, showClassicMailsItem)
                }
            }

            ListItem {
                id: autoDownloadItem
                height: autoDownloadLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: autoDownloadLayout
                    title.text: i18n.tr("Auto-Download Messages")

                    Label {
                        id: autoDownloadLabel
                        width: settingsPage.width/4
                        text: autoDownloadCurrentSetting
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentAutoDownload, autoDownloadItem)
                }
            }

            ListItem {
                height: secDeviceLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: secDeviceLayout
                    title.text: i18n.tr("Add Second Device")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    let popup2 = PopupUtils.open(
                        Qt.resolvedUrl('ConfirmDialog.qml'),
                        settingsPage,
                        { "dialogTitle": i18n.tr("Add Second Device"),
                          "dialogText": i18n.tr("This creates a QR code that the second device can scan to copy the account."),
                          "okButtonText": i18n.tr("Continue"),
                          "confirmButtonPositive": true
                    })
                    popup2.confirmed.connect(function() {
                        PopupUtils.close(popup2)
                        extraStack.push(Qt.resolvedUrl("AddSecondDevice.qml"))
                    })
                }
            }

            ListItem {
                height: connectivityLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: connectivityLayout
                    title.text: i18n.tr("Connectivity")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                enabled: root.syncAll
                onClicked: {
                    extraStack.push(Qt.resolvedUrl("Connectivity.qml"))
                }
            }

            Rectangle {
                id: prefPrivacySectionHeader
                height: prefPrivacySectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefPrivacySectionHeaderLabel
                    anchors {
                        top: prefPrivacySectionHeader.top
                        topMargin: units.gu(3)
                        left: prefPrivacySectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Privacy")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                height: readReceiptsLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: readReceiptsLayout
                    title.text: i18n.tr("Read Receipts")

                    Switch {
                        id: readReceiptsSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("mdns_enabled") === "1")
                        onCheckedChanged: {
                            if (readReceiptsSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("mdns_enabled") != "1") {
                                    DeltaHandler.setCurrentConfig("mdns_enabled", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("mdns_enabled") != "0") {
                                    DeltaHandler.setCurrentConfig("mdns_enabled", "0")
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: prefDelOldSectionHeader
                height: prefDelOldSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefDelOldSectionHeaderLabel
                    anchors {
                        top: prefDelOldSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefDelOldSectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Delete Old Messages")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: deleteFromDeviceItem
                height: deleteFromDeviceLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: deleteFromDeviceLayout
                    title.text: i18n.tr("Delete Messages from Device")

                    Label {
                        id: deleteFromDeviceLabel
                        width: settingsPage.width/4
                        text: deleteFromDeviceCurrentSetting
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentDeleteFromDevice, deleteFromDeviceItem)
                }
            }

            ListItem {
                id: deleteFromServerItem
                height: deleteFromServerLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: deleteFromServerLayout
                    title.text: i18n.tr("Delete Messages from Server")

                    Label {
                        id: deleteFromServerLabel
                        width: settingsPage.width/4
                        text: deleteFromServerCurrentSetting
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentDeleteFromServer, deleteFromServerItem)
                }
            }

//            Rectangle {
//                id: prefBackupSectionHeader
//                height: prefBackupSectionHeaderLabel.contentHeight + units.gu(3)
//                width: parent.width
//                Label {
//                    id: prefBackupSectionHeaderLabel
//                    anchors {
//                        top: prefBackupSectionHeader.top
//                        topMargin: units.gu(3)
//                        left: prefBackupSectionHeader.left
//                        leftMargin: units.gu(1)
//                    }
//                    // TODO: string not translated
//                    // TODO: maybe solve issue in a different way?
//                    text: i18n.tr("Backup")
//                    font.bold: true
//                }
//                color: theme.palette.normal.background
//            }

            ListItem {
                id: exportBackupItem
                height: exportBackupLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: exportBackupLayout
                    title.text: i18n.tr("Export Backup")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(progressBackupExport)
                    DeltaHandler.backupFileWritten.connect(startFileExport)
                }
            }

//            Rectangle {
//                id: prefAdvancedSectionHeader
//                height: prefAdvancedSectionHeaderLabel.contentHeight + units.gu(3)
//                width: parent.width
//                Label {
//                    id: prefAdvancedSectionHeaderLabel
//                    anchors {
//                        top: prefAdvancedSectionHeader.top
//                        topMargin: units.gu(3)
//                        left: prefAdvancedSectionHeader.left
//                        leftMargin: units.gu(1)
//                    }
//                    // TODO: string not translated
//                    // TODO: maybe solve issue in a different way?
//                    text: i18n.tr("Advanced")
//                    font.bold: true
//                }
//                color: theme.palette.normal.background
//            }

            ListItem {
                height: advancedLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: advancedLayout
                    title.text: i18n.tr("Advanced")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    extraStack.push(Qt.resolvedUrl("AdvancedSettings.qml"))
                }
            }

            Component {
                id: popoverComponentClassicMail
                Popover {
                    id: popoverClassicMail
                    Column {
                        id: containerLayout
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
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout1
                                title.text: i18n.tr("No, chats only")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("show_emails", "0")
                                PopupUtils.close(popoverClassicMail)
                                updateShowClassicMailsCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout2.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout2
                                title.text: i18n.tr("For accepted contacts")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("show_emails", "1")
                                PopupUtils.close(popoverClassicMail)
                                updateShowClassicMailsCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout3.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout3
                                title.text: i18n.tr("All")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("show_emails", "2")
                                PopupUtils.close(popoverClassicMail)
                                updateShowClassicMailsCurrentSetting()
                            }
                        }
                    }
                }
            }

            Component {
                id: popoverComponentAutoDownload
                Popover {
                    id: popoverAutoDownload
                    Column {
                        id: containerLayoutAuto
                        anchors {
                            left: parent.left
                            top: parent.top
                            right: parent.right
                        }
                        ListItem {
                            height: layout41.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout41
                                title.text: i18n.tr("All")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "0")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout42.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout42
                                title.text: i18n.tr("Up to %1").arg("40 KiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "40960")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout43.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout43
                                title.text: i18n.tr("Up to %1, most worse quality images").arg("160 KiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "163840")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout44.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout44
                                title.text: i18n.tr("Up to %1, most balanced quality images").arg("640 KiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "655360")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout45.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout45
                                title.text: i18n.tr("Up to %1").arg("5 MiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "5242880")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout46.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout46
                                title.text: i18n.tr("Up to %1").arg("25 MiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "26214400")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }
                    }
                }
            }

            Component {
                id: popoverComponentDeleteFromDevice
                Popover {
                    id: popoverDeleteFromDevice

                    function confirmDeleteFromDevice(secondsAsString, timetext) {
                        let popup = PopupUtils.open(
                            Qt.resolvedUrl("ConfirmDeleteFromDevice.qml"),
                            null,
                            { "deleteAfterXSeconds": secondsAsString, "deleteAfterXTime": timetext}
                        )
                        popup.confirmed.connect(function() {
                            PopupUtils.close(popup)
                            PopupUtils.close(popoverDeleteFromDevice)
                            updateDeleteFromDeviceCurrentSetting()
                        })
                        popup.cancelled.connect(function() {
                            PopupUtils.close(popup)
                            PopupUtils.close(popoverDeleteFromDevice)
                        })
                    }

                    Column {
                        id: containerLayoutDelDevice
                        anchors {
                            left: parent.left
                            top: parent.top
                            right: parent.right
                        }

                        ListItem {
                            height: layout51.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout51
                                title.text: i18n.tr("Never")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("delete_device_after", "0")
                                PopupUtils.close(popoverDeleteFromDevice)
                                updateDeleteFromDeviceCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout52.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout52
                                title.text: i18n.tr("After 1 hour")
                            }
                            onClicked: {
                                confirmDeleteFromDevice("3600", i18n.tr("After 1 hour"))
                            }
                        }

                        ListItem {
                            height: layout53.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout53
                                title.text: i18n.tr("After 1 day")
                            }
                            onClicked: {
                                confirmDeleteFromDevice("86400", i18n.tr("After 1 day"))
                            }
                        }

                        ListItem {
                            height: layout54.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout54
                                title.text: i18n.tr("After 1 week")
                            }
                            onClicked: {
                                confirmDeleteFromDevice("604800", i18n.tr("After 1 week"))
                            }
                        }

                        ListItem {
                            height: layout55.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout55
                                title.text: i18n.tr("After 4 weeks")
                            }
                            onClicked: {
                                confirmDeleteFromDevice("2419200", i18n.tr("After 4 weeks"))
                            }
                        }

                        ListItem {
                            height: layout56.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout56
                                title.text: i18n.tr("After 1 year")
                            }
                            onClicked: {
                                confirmDeleteFromDevice("31536000", i18n.tr("After 1 year"))
                            }
                        }
                    }
                }
            }

            Component {
                id: popoverComponentDeleteFromServer
                Popover {
                    id: popoverDeleteFromServer

                    function confirmDeleteFromServer(secondsAsString, timetext) {
                        let popup = PopupUtils.open(
                            Qt.resolvedUrl("ConfirmDeleteFromServer.qml"),
                            null,
                            { "deleteAfterXSeconds": secondsAsString, "deleteAfterXTime": timetext}
                        )
                        popup.confirmed.connect(function() {
                            PopupUtils.close(popup)
                            PopupUtils.close(popoverDeleteFromServer)
                            updateDeleteFromServerCurrentSetting()
                        })
                        popup.cancelled.connect(function() {
                            PopupUtils.close(popup)
                            PopupUtils.close(popoverDeleteFromServer)
                        })
                    }

                    Column {
                        id: containerLayoutDelServer
                        anchors {
                            left: parent.left
                            top: parent.top
                            right: parent.right
                        }

                        ListItem {
                            height: layout61.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout61
                                title.text: i18n.tr("Never")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("delete_server_after", "0")
                                PopupUtils.close(popoverDeleteFromServer)
                                updateDeleteFromServerCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout62.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout62
                                title.text: i18n.tr("At once")
                            }
                            onClicked: {
                                confirmDeleteFromServer("1", i18n.tr("At once"))
                            }
                        }

                        ListItem {
                            height: layout63.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout63
                                title.text: i18n.tr("After 30 seconds")
                            }
                            onClicked: {
                                confirmDeleteFromServer("30", i18n.tr("After 30 seconds"))
                            }
                        }

                        ListItem {
                            height: layout64.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout64
                                title.text: i18n.tr("After 1 minute")
                            }
                            onClicked: {
                                confirmDeleteFromServer("60", i18n.tr("After 1 minute"))
                            }
                        }

                        ListItem {
                            height: layout65.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout65
                                title.text: i18n.tr("After 1 hour")
                            }
                            onClicked: {
                                confirmDeleteFromServer("3600", i18n.tr("After 1 hour"))
                            }
                        }

                        ListItem {
                            height: layout66.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout66
                                title.text: i18n.tr("After 1 day")
                            }
                            onClicked: {
                                confirmDeleteFromServer("86400", i18n.tr("After 1 day"))
                            }
                        }

                        ListItem {
                            height: layout67.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout67
                                title.text: i18n.tr("After 1 week")
                            }
                            onClicked: {
                                confirmDeleteFromServer("604800", i18n.tr("After 1 week"))
                            }
                        }

                        ListItem {
                            height: layout68.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout68
                                title.text: i18n.tr("After 4 weeks")
                            }
                            onClicked: {
                                confirmDeleteFromServer("2419200", i18n.tr("After 4 weeks"))
                            }
                        }

                        ListItem {
                            height: layout69.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout69
                                title.text: i18n.tr("After 1 year")
                            }
                            onClicked: {
                                confirmDeleteFromServer("31536000", i18n.tr("After 1 year"))
                            }
                        }
                    } // end Column id: containerLayoutDelServer
                } // end Popover id: popoverDeleteFromServer
            } // end Component id: popoverComponentDeleteFromServer

            Component {
                id: popoverComponentTextZoom
                Popover {
                    id: popoverTextZoom
                    Column {
                        anchors {
                            left: parent.left
                            top: parent.top
                            right: parent.right
                        }
                        ListItem {
                            height: layout11.height
                            // should be automatically themed with something like
                            // theme.palette.normal.overlay, but this
                            // doesn't seem to work for Ambiance (and importing
                            // Lomiri.Components.Themes 1.3 doesn't solve it). 
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout11
                                title.text: i18n.tr("Small")
                                title.font.pixelSize: FontUtils.sizeToPixels("small")
                            }
                            onClicked: {
                                root.scaleLevel = 1
                                // to adapt entry fields etc.
                                DeltaHandler.emitFontSizeChangedSignal()

                                // to adapt scaling of the connectivity dot
                                root.updateConnectivity()
                                PopupUtils.close(popoverTextZoom)
                                extraStack.clear()
                            }
                        }

                        ListItem {
                            height: layout12.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout12
                                title.text: i18n.tr("Normal")
                                title.font.pixelSize: FontUtils.sizeToPixels("medium")
                            }
                            onClicked: {
                                root.scaleLevel = 2
                                DeltaHandler.emitFontSizeChangedSignal()
                                root.updateConnectivity()
                                PopupUtils.close(popoverTextZoom)
                                extraStack.clear()
                            }
                        }

                        ListItem {
                            height: layout13.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout13
                                title.text: i18n.tr("Large")
                                title.font.pixelSize: FontUtils.sizeToPixels("large")
                            }
                            onClicked: {
                                root.scaleLevel = 3
                                DeltaHandler.emitFontSizeChangedSignal()
                                root.updateConnectivity()
                                PopupUtils.close(popoverTextZoom)
                                extraStack.clear()
                            }
                        }

                        ListItem {
                            height: layout14.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout14
                                title.text: i18n.tr("Extra large")
                                title.font.pixelSize: FontUtils.sizeToPixels("x-large")
                            }
                            onClicked: {
                                root.scaleLevel = 4
                                DeltaHandler.emitFontSizeChangedSignal()
                                root.updateConnectivity()
                                PopupUtils.close(popoverTextZoom)
                                extraStack.clear()
                            }
                        }
                    }
                }
            }
        } // end Column id: flickContent
    } // end Flickable id: flickable

    Connections {
        target: DeltaHandler
        onBlockedcontactsmodelChanged: {
            extraStack.push(Qt.resolvedUrl("BlockedContacts.qml"))
        }

        onConnectivityChangedForActiveAccount: {
            updateConnectivity()
        }
    }

    Connections {
        target: root
        onIoChanged: {
            updateConnectivity()
        }
    }

    Component {
        id: progressBackupExport
        ProgressBackupExport {
            title: i18n.tr('Export Backup')
        }
    }
}
