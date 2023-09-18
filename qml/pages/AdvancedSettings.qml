/*
 * Copyright (C) 2022  Lothar Ketterer
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
    id: advancedSettingsPage

    Component.onDestruction: {
    }

    Component.onCompleted: {
          updateVoiceMessageQualityCurrentSetting()
    }

    property string voiceMessageQualityCurrentSetting: ""


    // Updating the displayed setting for "Voice Message Quality",
    // see Label with id: voiceMessageQualityLabel
    function updateVoiceMessageQualityCurrentSetting()
    {
        switch (root.voiceMessageQuality) {
            case DeltaHandler.LowRecordingQuality:
                voiceMessageQualityCurrentSetting = i18n.tr("Worse quality, small size")
                break
            case DeltaHandler.BalancedRecordingQuality:
                voiceMessageQualityCurrentSetting = i18n.tr("Balanced")
                break
            case DeltaHandler.HighRecordingQuality:
                voiceMessageQualityCurrentSetting = i18n.tr("High")
                break
            default:
                voiceMessageQualityCurrentSetting = "?"
                break
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
            let popup2 = PopupUtils.open(Qt.resolvedUrl("CreateDatabasePassword.qml"), advancedSettingsPage)
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
            let popup6 = PopupUtils.open(Qt.resolvedUrl("ConfirmDatabaseConversionToEncrypted.qml"), advancedSettingsPage)
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
        let popup7 = PopupUtils.open(Qt.resolvedUrl("ProgressDatabaseEncryption.qml"), advancedSettingsPage)
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
            let popup9 = PopupUtils.open(Qt.resolvedUrl("ConfirmDatabaseConversionToUnencrypted.qml"), advancedSettingsPage)
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
        let popup11 = PopupUtils.open(Qt.resolvedUrl("ProgressDatabaseDecryption.qml"), advancedSettingsPage)
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
        title: i18n.tr("Advanced")

        //trailingActionBar.numberOfSlots: 2
//        trailingActionBar.actions: [
//            Action {
//                iconName: 'help'
//                text: i18n.tr('Help')
//                onTriggered: {
//                    layout.addPageToCurrentColumn(advancedSettingsPage, Qt.resolvedUrl('Help.qml'))
//                }
//            },
//            Action {
//                iconName: 'info'
//                text: i18n.tr('About DeltaTouch')
//                onTriggered: {
//                            layout.addPageToCurrentColumn(advancedSettingsPage, Qt.resolvedUrl('About.qml'))
//                }
//            }
//        ]
    }

    Flickable {
        id: flickableAdvanced
        anchors.fill: parent
        anchors.topMargin: (advancedSettingsPage.header.flickable ? 0 : advancedSettingsPage.header.height)
        anchors.bottomMargin: units.gu(2)
        contentHeight: flickContent.childrenRect.height

        Column {
            id: flickContent
            width: parent.width

//            Rectangle {
//                id: prefVoiceMessagesSectionHeader
//                height: prefVoiceMessagesSectionHeaderLabel.contentHeight + units.gu(3)
//                width: parent.width
//                Label {
//                    id: prefVoiceMessagesSectionHeaderLabel
//                    anchors {
//                        top: prefVoiceMessagesSectionHeader.top
//                        topMargin: units.gu(3)
//                        left: prefVoiceMessagesSectionHeader.left
//                        leftMargin: units.gu(1)
//                    }
//                    // TODO: string not translated
//                    // TODO: maybe solve issue in a different way?
//                    text: i18n.tr("Voice Message")
//                    font.bold: true
//                }
//                color: theme.palette.normal.background
//            }

            ListItem {
                id: voiceMessageQualityItem
                height: voiceMessageQualityLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: voiceMessageQualityLayout
                    title.text: i18n.tr("Voice Message Quality")
                    title.font.bold: true

                    Label {
                        id: voiceMessageQualityLabel
                        width: advancedSettingsPage.width/4
                        text: voiceMessageQualityCurrentSetting
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentVoiceMessageQuality, voiceMessageQualityItem)
                }
            }

            Rectangle {
                id: prefAutocryptSectionHeader
                height: prefAutocryptSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefAutocryptSectionHeaderLabel
                    anchors {
                        top: prefAutocryptSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefAutocryptSectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Autocrypt")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: autocryptItem
                height: autocryptLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: autocryptLayout
                    title.text: i18n.tr("Prefer End-To-End Encryption")


                    Switch {
                        id: autocryptSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("e2ee_enabled") === "1")
                        onCheckedChanged: {
                            if (autocryptSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("e2ee_enabled") != "1") {
                                    DeltaHandler.setCurrentConfig("e2ee_enabled", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("e2ee_enabled") != "0") {
                                    DeltaHandler.setCurrentConfig("e2ee_enabled", "0")
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: prefImapFolderSectionHeader
                height: prefImapFolderSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefImapFolderSectionHeaderLabel
                    anchors {
                        top: prefImapFolderSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefImapFolderSectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    text: i18n.tr("IMAP Folder Handling")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: sentFolderItem
                height: sentFolderLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: sentFolderLayout
                    title.text: i18n.tr("Watch Sent Folder")


                    Switch {
                        id: sentFolderSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("sentbox_watch") === "1")
                        onCheckedChanged: {
                            if (sentFolderSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("sentbox_watch") != "1") {
                                    DeltaHandler.setCurrentConfig("sentbox_watch", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("sentbox_watch") != "0") {
                                    DeltaHandler.setCurrentConfig("sentbox_watch", "0")
                                }
                            }
                        }
                    }
                }
            }

            ListItem {
                id: copyToSelfItem
                height: copyToSelfLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: copyToSelfLayout
                    title.text: i18n.tr("Send Copy to Self")
                    summary.text: i18n.tr("Required when using this account on multiple devices.")
                    summary.wrapMode: Text.WordWrap


                    Switch {
                        id: copyToSelfSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("bcc_self") === "1")
                        onCheckedChanged: {
                            if (copyToSelfSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("bcc_self") != "1") {
                                    DeltaHandler.setCurrentConfig("bcc_self", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("bcc_self") != "0") {
                                    DeltaHandler.setCurrentConfig("bcc_self", "0")
                                }
                            }
                        }
                    }
                }
            }

            ListItem {
                id: autoFolderMovesItem
                height: autoFolderMovesLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: autoFolderMovesLayout
                    title.text: i18n.tr("Move automatically to DeltaChat Folder")
                    summary.text: i18n.tr("Chat conversations are moved to avoid cluttering the Inbox")
                    summary.wrapMode: Text.WordWrap


                    Switch {
                        id: autoFolderMoveSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("mvbox_move") === "1")
                        onCheckedChanged: {
                            if (autoFolderMoveSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("mvbox_move") != "1") {
                                    DeltaHandler.setCurrentConfig("mvbox_move", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("mvbox_move") != "0") {
                                    DeltaHandler.setCurrentConfig("mvbox_move", "0")
                                }
                            }
                        }
                    }
                }
            }

            ListItem {
                id: onlyDCfolderItem
                height: onlyDCfolderLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: onlyDCfolderLayout
                    title.text: i18n.tr("Only Fetch from DeltaChat Folder")
                    summary.text: i18n.tr("Ignore other folders. Requires your server to move chat messages to the DeltaChat folder.")
                    summary.wrapMode: Text.WordWrap


                    Switch {
                        id: onlyDCfolderSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("only_fetch_mvbox") === "1")
                        onCheckedChanged: {
                            if (onlyDCfolderSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("only_fetch_mvbox") != "1") {
                                    DeltaHandler.setCurrentConfig("only_fetch_mvbox", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("only_fetch_mvbox") != "0") {
                                    DeltaHandler.setCurrentConfig("only_fetch_mvbox", "0")
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: manageKeysSectionHeader
                height: manageKeysSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: manageKeysSectionHeaderLabel
                    anchors {
                        top: manageKeysSectionHeader.top
                        topMargin: units.gu(3)
                        left: manageKeysSectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    text: i18n.tr("Manage Keys")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: keysExportItem
                height: keysExportLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: keysExportLayout
                    title.text: i18n.tr("Export Secret Keys")

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(Qt.resolvedUrl("ProgressKeysExport.qml"))
                }
            }

            ListItem {
                id: keysImportItem
                height: keysImportLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: keysImportLayout
                    title.text: i18n.tr("Import Secret Keys")

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(Qt.resolvedUrl("ProgressKeysImport.qml"))
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
                    text: "<b>" + i18n.tr("Database Encryption") + "</b> " + i18n.tr("(will affect all accounts)")
//                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: encryptDatabaseItem
                height: encryptDatabaseLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: encryptDatabaseLayout
                    // TODO: String not translated yet
                    title.text: i18n.tr("Encrypt Database")

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
                                        advancedSettingsPage,
                                        {"text": i18n.tr("One unconfigured account exists. Unconfigured accounts cannot be converted. Please configure all unconfigured accounts or remove them prior to changes to this setting.")
                                    })

                                    // reset the switch
                                    checked = DeltaHandler.databaseIsEncryptedSetting()

                                } else if (numberUnconfiguredAccounts > 1) {
                                    PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"),
                                        advancedSettingsPage,
                                        {"text": numberUnconfiguredAccounts + i18n.tr(" unconfigured accounts exist. Unconfigured accounts cannot be converted. Please configure all unconfigured accounts or remove them prior to changes to this setting.")
                                    })

                                    // reset the switch
                                    checked = DeltaHandler.databaseIsEncryptedSetting()

                                } else {
                                    // no unconfigured accounts, start with conversion
                                    if (checked) {
                                        // this popup will inform that db encryption is experimental, blobs are
                                        // not encrypted, nobody can help if pw is lost etc.
                                        let popup4 = PopupUtils.open(Qt.resolvedUrl("ConfirmEncryptDatabase.qml"), advancedSettingsPage)
                                        popup4.confirmed.connect(encryptDatabaseStage1)
                                        popup4.cancelled.connect(uncheckEncryptDatabaseSwitch)
                                    } else {
                                        let popup5 = PopupUtils.open(Qt.resolvedUrl("ConfirmStopEncryptingDatabase.qml"), advancedSettingsPage)
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
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: changeDbPwLayout
                    // TODO: String not translated yet
                    title.text: i18n.tr("Change Database Passphrase")

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                enabled: encryptDatabaseSwitch.checked
                onClicked: {
                    PopupUtils.open(Qt.resolvedUrl("ChangeDatabasePassword.qml"))
                }
            }
        }
    }

    Component {
        id: popoverComponentVoiceMessageQuality
        Popover {
            id: popoverVoiceMessageQuality
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
                        title.text: i18n.tr("High")
                    }
                    onClicked: {
                        root.voiceMessageQuality = DeltaHandler.HighRecordingQuality
                        updateVoiceMessageQualityCurrentSetting()
                        PopupUtils.close(popoverVoiceMessageQuality)
                    }
                }

                ListItem {
                    height: layout21.height
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout21
                        title.text: i18n.tr("Balanced")
                    }
                    onClicked: {
                        root.voiceMessageQuality = DeltaHandler.BalancedRecordingQuality
                        updateVoiceMessageQualityCurrentSetting()
                        PopupUtils.close(popoverVoiceMessageQuality)
                    }
                }

                ListItem {
                    height: layout31.height
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout31
                        title.text: i18n.tr("Worse quality, small size")
                    }
                    onClicked: {
                        root.voiceMessageQuality = DeltaHandler.LowRecordingQuality
                        updateVoiceMessageQualityCurrentSetting()
                        PopupUtils.close(popoverVoiceMessageQuality)
                    }
                }
            }
        }
    }
}
