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
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import QtQuick.Layouts 1.3
//import Ubuntu.Components.Popups 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
//import QtMultimedia 5.12
//import QtQml.Models 2.12

import DeltaHandler 1.0

Page {
    id: addAccountViaQrPage

    signal setTempContextNull()

    Component.onDestruction: {
        // emit this because a QR code to set up an account might
        // have been scanned, but the configuration was unsuccessful.
        // In this case, tempContext is set in C++, but needs to be
        // unset now.
        //
        // C++ side will take care of unnecessary calls.
        setTempContextNull()
    }

    Component.onCompleted: {
        DeltaHandler.finishedSetConfigFromQr.connect(continueQrAccountCreation)
        DeltaHandler.readyForQrBackupImport.connect(continueQrBackupImport)
    }

    Connections {
        onSetTempContextNull: DeltaHandler.unrefTempContext()
    }

    function continueQrAccountCreation(wasSuccessful) {
        if (wasSuccessful) {
            // TODO: Unlike in the call from AddOrConfigureEmailAccount.qml,
            // the account should not persist if the configuration fails (or should it?)
            PopupUtils.open(configProgress)
        } else {
            PopupUtils.open(creationErrorMessage)
            setTempContextNull()
        }
    }

    function continueQrBackupImport() {
        PopupUtils.open(progressQrBackupImport)
    }

    header: PageHeader {
        id: qrHeader
        title: i18n.tr("Scan QR Code")

        //trailingActionBar.numberOfSlots: 2
       // trailingActionBar.actions: [
       //   //  Action {
       //   //      iconName: 'help'
       //   //      text: i18n.tr('Help')
       //   //      onTriggered: {
       //   //          layout.addPageToCurrentColumn(addAccountViaQrPage, Qt.resolvedUrl('Help.qml'))
       //   //      }
       //   //  },
       //     Action {
       //         iconName: 'info'
       //         text: i18n.tr('About DeltaTouch')
       //         onTriggered: {
       //                     layout.addPageToCurrentColumn(addAccountViaQrPage, Qt.resolvedUrl('About.qml'))
       //         }
       //     }
       // ]
    }



    Label {
        id: pasteLabel
        width: addAccountViaQrPage.width - units.gu (6)
        anchors {
            top: qrHeader.bottom
            topMargin: units.gu(3)
            left: addAccountViaQrPage.left
            leftMargin: units.gu(3)
        }
        // TODO string not translated yet
        text: i18n.tr("Scanning QR codes directly is not supported yet. Please use another app (e.g., Tagger) to scan and copy the code to the clipboard, then paste it here using the button below.")
        wrapMode: Text.Wrap
    }

    Button {
        id: pasteButton
        width: addAccountViaQrPage.width - units.gu(6)
        anchors {
            top: pasteLabel.bottom
            topMargin: units.gu(3)
            left: addAccountViaQrPage.left
            leftMargin: units.gu(3)
        }
        text: i18n.tr("Paste from Clipboard")
        iconName: "edit-paste"

        onClicked: {
            let qrstate = DeltaHandler.evaluateQrCode(Clipboard.data.text)

            switch (qrstate) {
                case DeltaHandler.DT_QR_BACKUP:
                    let popup = PopupUtils.open(
                        Qt.resolvedUrl("QrConfirmPopup.qml"),
                        null,
                        { textOne: i18n.tr("Copy the account from the other device to this device?"),
                          titleString: i18n.tr("Add as Second Device") }
                    )
                    popup.confirmed.connect(function() {
                        PopupUtils.close(popup)
                        // don't start the timer here as the page will be closed
                        // in a subsequent action
                        DeltaHandler.continueQrCodeAction()
                    })
                    break;
                case DeltaHandler.DT_QR_ERROR:
                    popup = PopupUtils.open(
                        Qt.resolvedUrl("QrConfirmPopup.qml"),
                        null,
                        { textOne: i18n.tr("Error: %1").arg(DeltaHandler.getQrTextOne()),
                          titleString: i18n.tr("Error") }
                    )
                    popup.confirmed.connect(function() {
                        PopupUtils.close(popup)
                        timer.start()
                    })
                    break;
                case DeltaHandler.DT_UNKNOWN:
                console.log("========= DT_UNKNOWN")
                    popup = PopupUtils.open(
                        Qt.resolvedUrl("QrConfirmPopup.qml"),
                        null,
                        { textOne: i18n.tr("Unknown"),
                          titleString: i18n.tr("QR Code") }
                    )
                    popup.confirmed.connect(function() {
                        PopupUtils.close(popup)
                        timer.start()
                    })
                    break;
                default: 
                    popup = PopupUtils.open(
                        Qt.resolvedUrl("QrConfirmPopup.qml"),
                        null,
                        { textOne: i18n.tr("Error"),
                          titleString: i18n.tr("QR Code") }
                    )
                    popup.confirmed.connect(function() {
                        PopupUtils.close(popup)
                        timer.start()
                    })
                    break;
            }
        }
    }

    Timer {
        id: timer
        interval: 100
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            layout.removePages(addAccountViaQrPage)
            DeltaHandler.continueQrCodeAction()
        }
    }

    Component {
        id: configProgress

        ProgressConfigAccount { // see file ProgressConfigAccount.qml
            title: i18n.tr('Configuring...')
        }
    }

    Component {
        id: creationErrorMessage

        ErrorMessage {
            title: i18n.tr("Error")
            // where to get the error from if dc_set_config_from_qr() failed?
            //text: i18n.tr("??")
        }
    }

    Component {
        id: progressQrBackupImport

        ProgressQrBackupImport { // see file ProgressQrBackupImport.qml
        }
    }
}
