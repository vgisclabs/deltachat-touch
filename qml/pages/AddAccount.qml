/*
 * Copyright (C) 2023, 2024  Lothar Ketterer
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
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: addAccountPage
    anchors.fill: parent

    property int numberOfAccounts: DeltaHandler.numberOfAccounts()

    Component.onCompleted: {
        // If the passphrase is not present in DeltaHandler, let the user enter
        // it until the same PW has been entered twice.
        // Background: If there's no account yet, but the user has set the
        // encrypted database setting to true and then closed the app without
        // creating an account first, the previously entered PW is not present
        // in memory after a new start of the app, so the PW has to be asked at
        // least once. To take care of typos, the PW is asked twice in this
        // case.
        if (DeltaHandler.databaseIsEncryptedSetting() && !DeltaHandler.hasDatabasePassphrase()) {
            let popup = PopupUtils.open(Qt.resolvedUrl("RequestDatabasePassword.qml"), addAccountPage)
        }
    }

    Connections {
        // not sure if this is really needed, but to be on the safe side
        target: DeltaHandler

        onNewConfiguredAccount: {
            numberOfAccounts = DeltaHandler.numberOfAccounts()
        }   

        onNewUnconfiguredAccount: {
            numberOfAccounts = DeltaHandler.numberOfAccounts()
        }   
    }

    header: PageHeader {
        id: header

        title: i18n.tr("Add Account")

        leadingActionBar.actions: [
            Action {
                //iconName: "go-previous"
                iconSource: "qrc:///assets/suru-icons/go-previous.svg"
                text: i18n.tr("Back")
                onTriggered: {
                    extraStack.pop()
                }
                // only allow leaving account configuration
                // if there's a configured account
                visible: numberOfAccounts !== 0
            }
        ]

        trailingActionBar.actions: [
            Action {
                //iconName: 'settings'
                iconSource: "qrc:///assets/suru-icons/settings.svg"
                text: i18n.tr('Settings')
                onTriggered: {
                    // TODO
                    PopupUtils.open(Qt.resolvedUrl(
                        // re-using the popup from the AccountConfig page
                        "AccountConfigPageSettings.qml"),
                        null,
                        { "experimentalEnabled": root.showAccountsExperimentalSettings, "showExperimentalSettingOnly": true }
                    )
                }
                visible: DeltaHandler.numberOfAccounts() === 0
            },
            Action {
                //iconName: 'info'
                iconSource: "qrc:///assets/suru-icons/info.svg"
                text: i18n.tr('About DeltaTouch')
                onTriggered: extraStack.push(Qt.resolvedUrl('About.qml'))
            }
        ]

    } //PageHeader id:header
        
    function startBackupImport(backupFile) {
        if (DeltaHandler.isBackupFile(backupFile)) {
            // Actual import will be started in the popup.
            PopupUtils.open(progressBackupImport, addAccountPage, { "backupSource": backupFile })
        } else {
            PopupUtils.open(errorMessage)
        }

    }
    
    Loader {
        id: backupImportLoader
    }

    Connections {
        target: backupImportLoader.item
        onFileSelected: {
            addAccountPage.startBackupImport(urlOfFile)
            backupImportLoader.source = ""
        }
        onCancelled: {
            backupImportLoader.source = ""
        }
    }

    ListModel {
        id: addAccountModel
    
        dynamicRoles: true
        Component.onCompleted: {
            addAccountModel.append({ "name": i18n.tr("Log into your E-Mail Account"), "linkToPage": "AddOrConfigureEmailAccount.qml" } )
            addAccountModel.append({ "name": i18n.tr("Add as Second Device"), "linkToPage": "AddAccountViaQr.qml" } )
            addAccountModel.append({ "name": i18n.tr("Restore from Backup"), "linkToPage": "restoreFromBackup--noLink" } )
            addAccountModel.append({ "name": i18n.tr("Scan Invitation Code"), "linkToPage": "AddAccountViaQr.qml" } )
        }
    }
    
    Column {
        id: experimentalSettingsColumn
        width: parent.width

        anchors {
            top: header.bottom
            left: parent.left
        }

        // Only show the option for encrypted database if there are no accounts yet.
        // Reason is that the user is forced to this page when no account exists
        // yet, but they should be able to select encryption for
        // the very first account. Afterwards, any change to the encrypted setting
        // would trigger a workflow to de/encrypt, and this should not
        // be done on this page here.
        visible: root.showAccountsExperimentalSettings && DeltaHandler.numberOfAccounts() === 0

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
                            // In contrast to the behaviour in AccountConfig.qml, we don't need
                            // that much complexity here as this switch is only shown if
                            // no accounts exist yet, see comment for the "visible" property
                            // above. We're checking, however, if there really is no account
                            // yet.
                            if (DeltaHandler.numberOfAccounts() > 0) {
                                console.log("AddAccount.qml: Warning: Switch for encrypted database changed although number of accounts is > 0. Resetting to original setting.")
                                checked = DeltabaseIsEncryptedSetting()
                            } else {
                                if (checked) {
                                    // this popup will inform that db encryption is experimental, blobs are
                                    // not encrypted, nobody can help if pw is lost etc.
                                    let popup4 = PopupUtils.open(Qt.resolvedUrl("ConfirmEncryptDatabase.qml"), addAccountPage)
                                    popup4.confirmed.connect(encryptDatabaseStage1)
                                    popup4.cancelled.connect(uncheckEncryptDatabaseSwitch)
                                } else {
                                    let popup5 = PopupUtils.open(Qt.resolvedUrl("ConfirmStopEncryptingDatabase.qml"), addAccountPage)
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

    ListView {
        id: addAccountView
        height: addAccountPage.height - header.height - units.gu(1)
        width: addAccountPage.width
        anchors {
            left: addAccountPage.left
            right: addAccountPage.right
            top: experimentalSettingsColumn.visible ? experimentalSettingsColumn.bottom : header.bottom
            topMargin: units.gu(1)
            bottom: addAccountPage.bottom
        }
        model: addAccountModel
        delegate: accountDelegate
    }
    
    Component {
        id: accountDelegate

        ListItem {
            id: item
            height: listLayout.height + (divider.visible ? divider.height : 0)

            ListItemLayout {
                id: listLayout
                title.text: name

                Icon {
                    //name: "go-next"
                    source: "qrc:///assets/suru-icons/go-next.svg"
                    SlotsLayout.position: SlotsLayout.Trailing;
                    width: units.gu(2)
                }
            }

            onClicked: {
                if (linkToPage == "restoreFromBackup--noLink") {
                    if (root.onUbuntuTouch) {
                        // Ubuntu Touch
                        DeltaHandler.newFileImportSignalHelper()
                        DeltaHandler.fileImportSignalHelper.fileImported.connect(addAccountPage.startBackupImport)
                        extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.FileType })
                        // TODO: regarding the below, maybe after the switch "let xy = extraStack.push(...); xy.bla.connect(...)" works?
                        //
                        // See comments in CreateOrEditGroup.qml
                        //let incubator = layout.addPageToCurrentColumn(addAccountPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.FileType })

                        //if (incubator.status != Component.Ready) {
                        //    // have to wait for the object to be ready to connect to the signal,
                        //    // see documentation on AdaptivePageLayout and
                        //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                        //    incubator.onStatusChanged = function(status) {
                        //        if (status == Component.Ready) {
                        //            incubator.object.fileSelected.connect(addAccountPage.startBackupImport)
                        //        }
                        //    }
                        //} else {
                        //    // object was directly ready
                        //    incubator.object.fileSelected.connect(addAccountPage.startBackupImport)
                        //}
                    } else {
                        // non-Ubuntu Touch
                        backupImportLoader.source = "FileImportDialog.qml"
                        backupImportLoader.item.setFileType(DeltaHandler.FileType)
                        backupImportLoader.item.open()
                    }
                } else {
                    extraStack.push(Qt.resolvedUrl(linkToPage))
                }
            }
        }
    }

    Component {
        id: progressBackupImport
        ProgressBackupImport {
            title: i18n.tr('Restore from Backup')
        }
    }

    Component {
        id: errorMessage
        ErrorMessage {
            title: i18n.tr('Error')
            // TODO: string not translated yet
            text: i18n.tr('The selected file is not a valid backup file.')
        }
    }

    /* ==========================================================
     * ===== Functions related to encryption of database ========
     * =====  (copied from AccountConfig and simplified) ========
     * ========================================================== */
     
    function uncheckEncryptDatabaseSwitch() {
        // Called if any popup during the stages for encryption is
        // cancelled. In this case, the switch has to be unset again.
        encryptDatabaseSwitch.checked = false
    }

    function encryptDatabaseStage1() {
        if (!DeltaHandler.hasDatabasePassphrase()) {
            // No phassphrase known to DeltaHandler, so a new one is set up
            let popup2 = PopupUtils.open(Qt.resolvedUrl("CreateDatabasePassword.qml"), addAccountPage)
            popup2.success.connect(encryptDatabaseStage2)
            popup2.cancelled.connect(uncheckEncryptDatabaseSwitch)
        } else {
            // Passphrase already set in DeltaHandler, use it
            // TODO: is this case possible?
            encryptDatabaseStage2() 
        }
    }

    function encryptDatabaseStage2() {
        // In contrast to AccountConfig.qml, there cannot
        // be an existing account, see previous steps.
        // So this function is much simpler here than in
        // AccountConfig.qml
        DeltaHandler.changeEncryptedDatabaseSetting(encryptDatabaseSwitch.checked)
    }

    /* =============== END encryption of database =============== */


    /* ==========================================================
     * ===== Functions related to decryption of database ========
     * =====  (copied from AccountConfig and simplified) ========
     * ========================================================== */

    function decryptDatabaseStage1() {
        // Function much simpler than the corresponding one in
        // AccountConfig.qml, as there are no accounts yet
        DeltaHandler.invalidateDatabasePassphrase()
        DeltaHandler.changeEncryptedDatabaseSetting(encryptDatabaseSwitch.checked)
    }

    /* =============== END decryption of database =============== */
} // end of Page id: addAccountPage
