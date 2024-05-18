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
//import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
//import QtMultimedia 5.12
//import QtQml.Models 2.12

import DeltaHandler 1.0

Page {
    id: qrInvitePage

    Component.onDestruction: {
        
    }

    Component.onCompleted: {
    }

    header: PageHeader {
        id: qrHeader
        title: i18n.tr("QR Invite Code")

        trailingActionBar.actions: [
            Action {
                //iconName: "contextual-menu"
                iconSource: "qrc:///assets/suru-icons/contextual-menu.svg"
                text: i18n.tr("More Options")
                onTriggered: {
                    // Popup contains a few buttons:
                    // - copy to clipboard: basically the same as in the "share" action
                    //   for non-UT below, everything is done in the popup itself for that
                    // - Deactivate the QR code (which automatically creates a new one):
                    //   This one needs the logic below to first confirm whether
                    //   the user really wants to deactivate, then check whether
                    //   deactivation was successful, and lastly refresh the image,
                    //   which is also not trivial
                    let popup1 = PopupUtils.open(Qt.resolvedUrl("QrMenuPopup.qml"), qrInvitePage, { "qrInviteLink": DeltaHandler.getTempGroupQrLink() })
                    popup1.continueAskUserQrDeactivation.connect(function() {
                        // if the signal continueAskUserQrDeactivation is received,
                        // the user has clicked to deactive the QR code. Ask
                        // for confirmation.
                        let popup2 = PopupUtils.open(
                            Qt.resolvedUrl("ConfirmDialog.qml"),
                            qrInvitePage,
                            {
                                dialogText: i18n.tr("This QR code can be scanned by others to join the group \"%1\".\n\nYou can deactivate the QR code here and reactivate it by scanning it again.").arg(DeltaHandler.getTempGroupName()),
                                okButtonText: i18n.tr("Deactivate QR Code")
                            }
                        )
                        popup2.confirmed.connect(function() {
                            let paramStr = ""
                            paramStr += DeltaHandler.getCurrentAccountId()
                            paramStr += ", "
                            let requestString = DeltaHandler.constructJsonrpcRequestString("set_config_from_qr", paramStr + "\"" + DeltaHandler.getTempGroupQrTxt() + "\"")
                            let responseStr = DeltaHandler.sendJsonrpcBlockingCall(requestString)
                            let errorStr = DeltaHandler.getErrorFromJsonrpcResponse(responseStr)
                            if (errorStr === "") {
                                // No error, load new QR code. Can't just set qrImage.source
                                // to a new call of DeltaHandler.getTempGroupQrSvg() because
                                // it takes the core some secs to generate a new image.
                                // The timer refreshes the image every second for 10
                                // seconds.
                                // Also, see comments in DeltaHandler.getTempGroupQrSvg()
                                // regarding the refresh of the Image source.
                                newQrImageTimer.newQrImageCounter = 0
                                newQrImageTimer.start()
                            } else {
                                PopupUtils.open(errorPopup, qrInvitePage, { text: errorStr })
                            }
                        })
                    })
                }
            },
            Action {
                //iconName: "share"
                iconSource: "qrc:///assets/suru-icons/share.svg"
                text: i18n.tr("Share")
                onTriggered: {
                    if (root.onUbuntuTouch) {
                        extraStack.push(Qt.resolvedUrl('StringExportDialog.qml'), { "stringToShare": DeltaHandler.getTempGroupQrLink() })
                    } else {
                        PopupUtils.open(Qt.resolvedUrl("QrSharePopup.qml"), qrInvitePage, { "qrInviteLink": DeltaHandler.getTempGroupQrLink() })
                    }
                }
            }
        ]
    }

    Image {
        id: qrImage
        width: (parent.width < parent.height - qrHeader.height ? parent.width : parent.height - qrHeader.height) - units.gu(2)
        height: width
        anchors {
            top: header.bottom
            topMargin: units.gu(1)
            left: parent.left
            leftMargin: units.gu(1)
        }
        source: StandardPaths.locate(StandardPaths.CacheLocation, DeltaHandler.getTempGroupQrSvg())
        fillMode: Image.PreserveAspectFit
    }

    Timer {
        id: newQrImageTimer
        // CAVE when starting the timer, make sure
        // to set newQrImageTimer.newQrImageCounter to 0
        property int newQrImageCounter: 0
        interval: 1000
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            qrImage.source = ""
            qrImage.source = StandardPaths.locate(StandardPaths.CacheLocation, DeltaHandler.getTempGroupQrSvg())
            newQrImageCounter++
            if (newQrImageCounter === 10) {
                stop()
            }
        }
    }

    Component {
        id: errorPopup

        ErrorMessage {
            title: i18n.tr("Error")
            // where to get the error from if dc_set_config_from_qr() failed?
            text: ""
        }
    }

}
