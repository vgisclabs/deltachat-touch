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
import Lomiri.Components.Popups 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: addAccountPage
    anchors.fill: parent

    property int numberOfAccounts: DeltaHandler.numberOfAccounts()
    property string oldUrlHandlingPage
    readonly property string thisPagePath: "qml/AddAccount"

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

        oldUrlHandlingPage = root.urlHandlingPage
        root.urlHandlingPage = thisPagePath
    }

    Component.onDestruction: {
        root.urlHandlingPage = oldUrlHandlingPage
    }

    Loader {
        id: backupImportLoader
    }

    Connections {
        target: root
        onUnprocessedUrl: {
            if (root.urlHandlingPage !== thisPagePath) {
                return
            }

            let qrstate = DeltaHandler.evaluateQrCode(rawUrl)
            switch (qrstate) {
                // CAVE backup here means second device, it's not the "restore
                // from backup" thing
                case DeltaHandler.DT_QR_BACKUP: // fallthrough
                case DeltaHandler.DT_QR_BACKUP2:
                    let popup9 = PopupUtils.open(Qt.resolvedUrl("ProgressQrBackupImport.qml"))
                    popup9.success.connect(function() { clearStackTimer.start() })
                    break;
                case DeltaHandler.DT_QR_ACCOUNT:
                    extraStack.push(Qt.resolvedUrl("OnboardingChatmail.qml"), { "provider": DeltaHandler.getQrTextOne(), "isDcLogin": false })
                    break;
                case DeltaHandler.DT_QR_LOGIN:
                    extraStack.push(Qt.resolvedUrl("OnboardingChatmail.qml"), { "provider": DeltaHandler.getQrTextOne(), "isDcLogin": true })
                    break;
                default: 
                    let popup8 = PopupUtils.open(
                        Qt.resolvedUrl("ErrorMessage.qml"),
                        null,
                        { text: i18n.tr("The scanned QR code cannot be used to set up a new account.") }
                    )
                    break;
            }
        }
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

    Connections {
        // not sure if this is really needed, but to be on the safe side
        target: DeltaHandler

        onNewConfiguredAccount: {
            numberOfAccounts = DeltaHandler.numberOfAccounts()
        }   

        onNewUnconfiguredAccount: {
            numberOfAccounts = DeltaHandler.numberOfAccounts()
        }   

        onFinishedSetConfigFromQr: {
            // see signal finishedSetConfigFromQr in deltahandler.h
            if (urlHandlingPage === thisPagePath) {
                if (successful) {
                    PopupUtils.open(
                        Qt.resolvedUrl("ProgressConfigAccount.qml"),
                        chatlistPage,
                        { "title": i18n.tr('Configuring...') }
                    )
                } else {
                    PopupUtils.open(
                        Qt.resolvedUrl("errorMessage.qml"),
                        chatlistPage,
                        { "title": i18n.tr('Error') }
                    )
                    setTempContextNull()
                }
            }
        }
    }

    header: PageHeader {
        id: header

        title: i18n.tr("Create New Profile")

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


    Image {
        id: backgroundImage
        anchors.fill: parent
        opacity: 0.05
        source: root.darkmode ? Qt.resolvedUrl('qrc:///assets/background_dark.svg') : Qt.resolvedUrl('qrc:///assets/background_bright.svg')
        fillMode: Image.PreserveAspectFit
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
                                    let popup4 = PopupUtils.open(
                                        Qt.resolvedUrl('ConfirmDialog.qml'),
                                        addAccountPage,
                                        { "dialogTitle": i18n.tr("Really encrypt the database?"),
                                          "dialogText": DeltaHandler.numberOfAccounts() > 0 ?  i18n.tr("• Database encryption is experimental, use at your own risk. BACKUP YOUR ACCOUNTS OR ADD A SECOND DEVICE FIRST.\n\n• It will only cover text messages and username/password of your accounts. Pictures, voice messages, files etc. will remain unencrypted.\n\n• If the phassphrase is lost, your data will be lost as well.\n\n• You will have to enter the phassphrase upon each startup of the app.") : i18n.tr("• Database encryption is experimental, use at your own risk.\n\n• It will only cover text messages and username/password of your accounts. Pictures, voice messages, files etc. will remain unencrypted.\n\n• If the phassphrase is lost, your data will be lost as well.\n\n• You will have to enter the phassphrase upon each startup of the app."),
                                          "okButtonText": i18n.tr("Continue"),
                                    })

                                    popup4.confirmed.connect(encryptDatabaseStage1)
                                    popup4.cancelled.connect(uncheckEncryptDatabaseSwitch)
                                } else {
                                    let popup5 = PopupUtils.open(
                                        Qt.resolvedUrl('ConfirmDialog.qml'),
                                        addAccountPage,
                                        { "dialogText": i18n.tr("Really disable database encryption?"),
                                          "okButtonText": i18n.tr("Disable encryption"),
                                    })

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

    Item {
        anchors {
            top: experimentalSettingsColumn.visible ? experimentalSettingsColumn.bottom : header.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        Column {
            id: buttonColumn
            width: parent.width > units.gu(54) ? units.gu(50) : (parent.width - units.gu(4))
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            spacing: units.gu(2)

            Rectangle {
                width: secureDecentralizedLabel.contentWidth
                height: secureDecentralizedLabel.contentHeight
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"

                Label {
                    id: secureDecentralizedLabel
                    width: buttonColumn.width
                    anchors {
                        top: parent.top
                        left: parent.left
                    }
                    wrapMode: Text.WordWrap
                    text: i18n.tr("Secure Decentralized Chat")
                }
            }

            Item {
                id: spacerItem
                width: parent.width
                height: units.gu(2)
            }

            Button {
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("Create New Profile")
                color: theme.palette.normal.positive
                onClicked: extraStack.push(Qt.resolvedUrl("OnboardingChatmail.qml"))
            }

            Button {
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("I Already Have a Profile")
                onClicked: {
                    let popup3 = PopupUtils.open(Qt.resolvedUrl("AlreadyHaveProfilePopup.qml"), addAccountPage)
                    popup3.addSecondDevice.connect(function() {
                        PopupUtils.close(popup3)
                        extraStack.push(Qt.resolvedUrl("QrScanner.qml"))
                    })
                    popup3.restoreBackup.connect(function() {
                        PopupUtils.close(popup3)
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
                    })
                    popup3.cancelled.connect(function() {
                        PopupUtils.close(popup3)
                    })
                } 
            }

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

    function startBackupImport(backupFile) {
        if (DeltaHandler.isBackupFile(backupFile)) {
            // Actual import will be started in the popup.
            PopupUtils.open(Qt.resolvedUrl("ProgressBackupImport.qml"), addAccountPage, {
                "backupSource": backupFile,
                "title": i18n.tr('Restore from Backup')
            })
        } else {
            PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"), addAccountPage, {
                text: i18n.tr("Error: %1").arg("Not a backup file")
            })
        }
    }

    Timer {
        id: clearStackTimer
        interval: 300
        repeat: false
        triggeredOnStart: false
        onTriggered: extraStack.clear()
    }

} // end of Page id: addAccountPage
