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
import Ubuntu.Components.Popups 1.3 // for the popover component
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: accountConfigPage
    anchors.fill: parent

    function loadAddAccountPage() {
        layout.addPageToCurrentColumn(accountConfigPage, Qt.resolvedUrl('AddAccount.qml'))
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
            let popup2 = PopupUtils.open(Qt.resolvedUrl("CreateDatabasePassword.qml"), accountConfigPage)
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
            let popup6 = PopupUtils.open(Qt.resolvedUrl("ConfirmDatabaseConversionToEncrypted.qml"), accountConfigPage)
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
        let popup7 = PopupUtils.open(Qt.resolvedUrl("ProgressDatabaseEncryption.qml"), accountConfigPage)
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
            let popup9 = PopupUtils.open(Qt.resolvedUrl("ConfirmDatabaseConversionToUnencrypted.qml"), accountConfigPage)
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
        let popup11 = PopupUtils.open(Qt.resolvedUrl("ProgressDatabaseDecryption.qml"), accountConfigPage)
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
        id: header

        title: i18n.tr("Known Accounts")

        leadingActionBar.actions: [
            Action {
                iconName: "go-previous"
                text: i18n.tr("Back")
                onTriggered: {
                    layout.removePages(accountConfigPage)
                }
                // only allow leaving account configuration
                // if there's a configured account
                visible: DeltaHandler.hasConfiguredAccount
            }
        ]

        trailingActionBar.actions: [
//            Action {
//                iconName: 'help'
//                text: i18n.tr('Help')
//                // TODO make help page for the Account config page
//                onTriggered: layout.addPageToCurrentColumn(accountConfigPage, Qt.resolvedUrl('About.qml'))
//            },

            Action {
                iconName: 'settings'
                text: i18n.tr('Settings')
                onTriggered: {
                    // TODO
                    PopupUtils.open(Qt.resolvedUrl(
                        "AccountsExperimentalSettingsSwitch.qml"),
                        null,
                        { "experimentalEnabled": root.showAccountsExperimentalSettings }
                    )
                }
            },

            Action {
                iconName: 'info'
                text: i18n.tr('Info')
                onTriggered: layout.addPageToCurrentColumn(accountConfigPage, Qt.resolvedUrl('About.qml'))
            },

            Action {
                iconName: 'add'
                text: i18n.tr('Add Account')
                onTriggered: {
                    if (DeltaHandler.databaseIsEncryptedSetting() && !DeltaHandler.hasDatabasePassphrase()) {
                        let popup = PopupUtils.open(Qt.resolvedUrl("RequestDatabasePassword.qml"), accountConfigPage)
                        popup.success.connect(loadAddAccountPage)
                    } else {
                        layout.addPageToCurrentColumn(accountConfigPage, Qt.resolvedUrl('AddAccount.qml'))
                    }
                }
            }
        ]
    } //PageHeader id:header

    Column {
        id: experimentalSettingsColumn
        width: parent.width

        anchors {
            top: header.bottom
            left: parent.left
        }

        visible: root.showAccountsExperimentalSettings

        ListItem {
            id: encDbItem
            height: layout1.height + (divider.visible ? divider.height : 0)
            width: experimentalSettingsColumn.width

            ListItemLayout {
                id: layout1
                title.text: i18n.tr("Encrypted database (experimental)")
                title.font.bold: true

                Switch {
                    id: encryptDatabaseSwitch
                    checked: DeltaHandler.databaseIsEncryptedSetting()
                    SlotsLayout.position: SlotsLayout.Trailing
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
                                    accountConfigPage,
                                    {"text": i18n.tr("One unconfigured account exists. Unconfigured accounts cannot be converted. Please configure all unconfigured accounts or remove them prior to changes to this setting.")
                                })

                                // reset the switch
                                checked = DeltaHandler.databaseIsEncryptedSetting()

                            } else if (numberUnconfiguredAccounts > 1) {
                                PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"),
                                    accountConfigPage,
                                    {"text": numberUnconfiguredAccounts + i18n.tr(" unconfigured accounts exist. Unconfigured accounts cannot be converted. Please configure all unconfigured accounts or remove them prior to changes to this setting.")
                                })

                                // reset the switch
                                checked = DeltaHandler.databaseIsEncryptedSetting()

                            } else {
                                // no unconfigured accounts, start with conversion
                                if (checked) {
                                    // this popup will inform that db encryption is experimental, blobs are
                                    // not encrypted, nobody can help if pw is lost etc.
                                    let popup4 = PopupUtils.open(Qt.resolvedUrl("ConfirmEncryptDatabase.qml"), accountConfigPage)
                                    popup4.confirmed.connect(encryptDatabaseStage1)
                                    popup4.cancelled.connect(uncheckEncryptDatabaseSwitch)
                                } else {
                                    let popup5 = PopupUtils.open(Qt.resolvedUrl("ConfirmStopEncryptingDatabase.qml"), accountConfigPage)
                                    popup5.confirmed.connect(decryptDatabaseStage1)
                                    popup5.cancelled.connect(recheckEncryptDatabaseSwitch)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ListItemActions {
        id: leadingAccountAction
        actions: Action {
            iconName: "delete"
            onTriggered: {
                // the index is passed as parameter and can
                // be accessed via 'value'
                PopupUtils.open(
                    Qt.resolvedUrl('ConfirmAccountDeletion.qml'),
                    null,
                    { 'accountArrayIndex': value, }
                )
            }
        }
    }

    ListItemActions {
        id: trailingAccountAction
        actions: [
            Action {
                iconName: "edit"
                onTriggered: {
                    DeltaHandler.accountsmodel.configureAccount(value)
                    layout.addPageToCurrentColumn(accountConfigPage, Qt.resolvedUrl('AddOrConfigureEmailAccount.qml'))
                }
            },
            Action {
                iconName: "info"
                onTriggered: {
                    let tempString = i18n.tr("Account ID: %1").arg(DeltaHandler.accountsmodel.getIdOfAccount(value)) + "\n\n" + i18n.tr("Info") + ":\n" + DeltaHandler.accountsmodel.getInfoOfAccount(value) + "\n\n" + i18n.tr("Error") + ":\n" + (DeltaHandler.accountsmodel.getLastErrorOfAccount(value) == "" ? i18n.tr("None") : DeltaHandler.accountsmodel.getLastErrorOfAccount(value))
                    PopupUtils.open(
                        Qt.resolvedUrl('InfoPopup.qml'),
                        null,
                        { text: tempString }
                    )
                }
            }
        ]
    }


    Component {
        id: accountsDelegate

        ListItem {
            id: accountsItem
            height: accountsListItemLayout.height + (divider.visible ? divider.height : 0)
            divider.visible: true

            property int freshMsgCount: model.freshMsgCount

            onClicked: {
                if (model.isConfigured) {
                    DeltaHandler.selectAccount(index)
                    layout.removePages(primaryPage)
                }
                else {
                    PopupUtils.open(errorMessage)
                }
            }

            leadingActions: leadingAccountAction
            trailingActions: trailingAccountAction

            ListItemLayout {
                id: accountsListItemLayout
                title.text: model.username == '' ? '[' + i18n.tr('no username set') + ']' : model.username
                subtitle.text: model.address

                UbuntuShape {
                    id: profPicShape
                    height: units.gu(5)
                    width: height
                    SlotsLayout.position: SlotsLayout.Leading
                    source: Image {
                        id: profPic
                        anchors.fill: parent
                        source: model.profilePic == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, model.profilePic)
                    }
                    sourceFillMode: UbuntuShape.PreserveAspectCrop
                    aspect: UbuntuShape.Flat
                } // end of UbuntuShape id:profilePicShape

                Rectangle {
                    id: configStatusRect
                    SlotsLayout.position: SlotsLayout.Trailing
                    height: units.gu(3)
                    width: (configStatusIcon.visible ? configStatusIcon.width + units.gu(1) : 0) + (newMsgCountShape.visible ? newMsgCountShape.width + units.gu(1) : 0) + units.gu(1)
                    color: accountsItem.color
                    Label {
                        id: configStatusLabel
                        text: '!'
                        font.bold: true
                        color: theme.palette.normal.negative 
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        textSize: Label.XLarge
                        visible: !model.isConfigured
                    }

                    Icon {
                        id: configStatusIcon
                        height: units.gu(3)
                        width: height
                        color: theme.palette.normal.positive
                        anchors {
                            right: parent.right
                            rightMargin: units.gu(1)
                            top: parent.top
                        }
                        name: "lock"
                        visible: model.isClosed
                    }

                    UbuntuShape {
                        id: newMsgCountShape
                        height: newMsgCountLabel.height + units.gu(0.6)
                        width: height

                        anchors {
                            verticalCenter: configStatusIcon.verticalCenter
                            //top: timestamp.bottom
                            //topMargin: units.gu(0.3) + units.gu(scaleLevel/10)
                            right: configStatusIcon.visible ? configStatusIcon.left : parent.right
                            rightMargin: units.gu(1)
                        }
                        backgroundColor: root.unreadMessageCounterColor
                        
                        visible: freshMsgCount > 0 && model.isConfigured

                        Label {
                            id: newMsgCountLabel
                            anchors {
                                top: newMsgCountShape.top
                                topMargin: units.gu(0.3)
                                horizontalCenter: newMsgCountShape.horizontalCenter
                            }
                            text: freshMsgCount > 99 ? "99+" : freshMsgCount
                            //fontSize: root.scaledFontSizeSmaller
                            font.bold: true
                            color: "white"
                        }
                    }
                }
            } // ListItemLayout id: accountsListItemLayout
        } // ListItem accountsItem
    } // Component accountsDelegate

    ListView {
        id: view
        clip: true 
        //height: accountConfigPage.height - header.height
        width: parent.width
        anchors {
            top: root.showAccountsExperimentalSettings ? experimentalSettingsColumn.bottom : header.bottom
            topMargin: units.gu(1)
            bottom: accountConfigPage.bottom
        }
        model: DeltaHandler.accountsmodel
        delegate: accountsDelegate
//        spacing: units.gu(1)
    }

    Component {
        id: errorMessage

        ErrorMessage {
            title: i18n.tr("Error")
            // TODO: probably create new string? Something like
            // "Swipe right and click edit to complete configuration. Choosing info after swiping will give a hint about the last error."
            text: i18n.tr("Account is not configured.")
        }
    }
} // end of Page id: accountConfigPage
