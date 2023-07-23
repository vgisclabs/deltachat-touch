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
 *
 * The scanning part of the code (Camera, VideoOutput etc) is modified
 * from Authenticator NG, original authors:
 * Copyright © 2018-2020 Rodney Dawes
 * Copyright: 2013 Michael Zanetti <michael_zanetti@gmx.net>
 * see
 * https://gitlab.com/dobey/authenticator-ng/-/blob/trunk/src/qml/ScanPage.qml
 */

import QtQuick 2.12
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import QtQuick.Layouts 1.3
//import Ubuntu.Components.Popups 1.3
//import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import QtMultimedia 5.12
//import QtQml.Models 2.12
//import QtQuick.Window 2.0

import DeltaHandler 1.0

Page {
    id: qrShowScanPage

    signal setTempContextNull()
    signal deleteDecoder()

    // for switching between the sections, so the action
    // upon switching is only executed once
    property bool scanSectionActive: false

    Component.onDestruction: {
        captureTimer.stop()
        // emit this because a QR code to set up an account might
        // have been scanned, but the configuration was unsuccessful.
        // In this case, tempContext is set in C++, but needs to be
        // unset now.
        //
        // C++ side will take care of unnecessary calls.
        setTempContextNull()

        deleteDecoder()
    }

    Component.onCompleted: {
        DeltaHandler.finishedSetConfigFromQr.connect(continueQrAccountCreation)
        DeltaHandler.readyForQrBackupImport.connect(continueQrBackupImport)
        DeltaHandler.qrDecoded.connect(startQrProcessing)

        scanSectionActive = false
        qrImage.visible = true
        qrScanRect.visible = false
    }

    Connections {
        onSetTempContextNull: DeltaHandler.unrefTempContext()
        onDeleteDecoder: DeltaHandler.deleteQrDecoder()
    }

    function startQrProcessing(content) {
        camera.stopAll()
        qrActionSwitch(DeltaHandler.evaluateQrCode(content))
    }

    function qrActionSwitch(qrstate) {
        switch (qrstate) {
            case DeltaHandler.DT_QR_ASK_VERIFYCONTACT:
                console.log("qr state is DT_QR_ASK_VERIFYCONTACT")
                let popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Chat with %1?").arg(DeltaHandler.getQrContactEmail()) }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    // TODO: Trying to close the page here by calling
                    // layout.removePages(qrShowScanPage)
                    // always results in an error
                    // QQmlExpression: Attempted to evaluate an expression in an invalid context
                    // Same if DeltaHandler.continueQrCodeAction() emits a signal closeQrPage()
                    // that is connected to a method here which calls layout.removePages.
                    // Just not caring about closing and adding another page to the layout from Main
                    // results in this page still being active (as tested by a repeating
                    // timer), and the added page not having a back button.
                    // Adding a var that would be set to true here and evaluating it after the switch block
                    // doesn't work because it would be set only after the button is pressed in the popup.
                    // By that time, the switch block has long been finished.
                    //
                    // Only working solution found so far is to perform follow-up actions by a timer.
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_ASK_VERIFYGROUP:
                console.log("qr state is DT_QR_ASK_VERIFYGROUP")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Do you want to join the group \"%1\"?").arg(DeltaHandler.getQrTextOne()) }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_FPR_OK:
                console.log("qr state is DT_QR_FPR_OK")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("The fingerprint of %1 is valid!").arg(DeltaHandler.getQrContactEmail()),
                      titleString: i18n.tr("Fingerprint") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_FPR_MISMATCH:
                console.log("qr state is DT_QR_FPR_MISMATCH")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("The scanned fingerprint does not match the last seen for %1.").arg(DeltaHandler.getQrContactEmail()),
                      titleString: i18n.tr("Error") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_FPR_WITHOUT_ADDR:
                console.log("qr state is DT_QR_FPR_WITHOUT_ADDR")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("This QR code contains a fingerprint but no e-mail address.\n\nFor an out-of-band-verification, please establish an encrypted connection to the recipient first."),
                      titleString: i18n.tr("Fingerprint") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_ACCOUNT:
                console.log("qr state is DT_QR_ACCOUNT")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Create new e-mail address on \"%1\" and log in there?").arg(DeltaHandler.getQrTextOne()) }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    // don't start continueTimer here as the page will be closed
                    // in a subsequent action
                    DeltaHandler.continueQrCodeAction()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_BACKUP:
                console.log("qr state is DT_QR_BACKUP")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Copy the account from the other device to this device?"),
                      titleString: i18n.tr("Add as Second Device") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    // don't start continueTimer here as the page will be closed
                    // in a subsequent action
                    DeltaHandler.continueQrCodeAction()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_WEBRTC_INSTANCE:
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Sorry, not implemented yet :-(") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                console.log("qr state is DT_QR_WEBRTC_INSTANCE")
                break;
            case DeltaHandler.DT_QR_ADDR:
                console.log("qr state is DT_QR_ADDR")
                // TODO (also TODO in deltahandler.cpp!)
                break;
            case DeltaHandler.DT_QR_TEXT:
                console.log("qr state is DT_QR_TEXT")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Scanned QR code text:\n\n%1").arg(DeltaHandler.getQrTextOne()),
                    titleString: i18n.tr("QR Code"),
                    showClipboardButton: true,
                    clipboardContent: DeltaHandler.getQrTextOne() }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_URL:
                console.log("qr state is DT_QR_URL")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Scanned QR code URL:\n\n%1").arg(DeltaHandler.getQrTextOne()),
                    titleString: i18n.tr("QR Code"),
                    showClipboardButton: true,
                    showClickUrlButton: true,
                    clipboardContent: DeltaHandler.getQrTextOne() }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_ERROR:
                console.log("qr state is DT_QR_ERROR")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Error: %1").arg(DeltaHandler.getQrTextOne()),
                      titleString: i18n.tr("Error") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_WITHDRAW_VERIFYCONTACT:
                console.log("qr state is DT_QR_WITHDRAW_VERIFYCONTACT")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("This QR code can be scanned by others to contact you.\n\nYou can deactivate the QR code here and reactivate it by scanning it again."),
                      titleString: i18n.tr("Deactivate QR Code") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_WITHDRAW_VERIFYGROUP:
                console.log("qr state is DT_QR_WITHDRAW_VERIFYGROUP")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("This QR code can be scanned by others to join the group \"%1\".\n\nYou can deactivate the QR code here and reactivate it by scanning it again.").arg(DeltaHandler.getQrTextOne()),
                      titleString: i18n.tr("Deactivate QR Code") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_REVIVE_VERIFYCONTACT:
                console.log("qr state is DT_QR_REVIVE_VERIFYCONTACT")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("This QR code could be scanned by others to contact you.\n\nThe QR code is not active on this device."),
                      titleString: i18n.tr("Activate QR Code") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_REVIVE_VERIFYGROUP:
                console.log("qr state is DT_QR_REVIVE_VERIFYGROUP")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("This QR code could be scanned by others to join the group \"%1\".\n\nThe QR code is not active on this device.").arg(DeltaHandler.getQrTextOne()),
                      titleString: i18n.tr("Activate QR Code") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_LOGIN:
                console.log("qr state is DT_QR_LOGIN")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Log into \"%1\"?").arg(DeltaHandler.getQrTextOne()) }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    // don't start continueTimer here as the page will be closed
                    // in a subsequent action
                    DeltaHandler.continueQrCodeAction()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_UNKNOWN:
                console.log("qr state is DT_UNKNOWN")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Unknown"),
                      titleString: i18n.tr("QR Code") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            default: 
                console.log("Received unknown QR state")
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Unknown"),
                      titleString: i18n.tr("QR Code") }
                )
                popup.confirmed.connect(function() {
                    PopupUtils.close(popup)
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
        }
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
        let popup2 = PopupUtils.open(progressQrBackupImport)
        popup2.failed.connect(goBackToMain)
        popup2.cancelled.connect(goBackToMain)
    }

    function goBackToMain() {
        layout.removePages(primaryPage)
    }

    header: PageHeader {
        id: qrHeader
        title: i18n.tr("QR Invite Code")
    }

    Sections {
        id: qrSections
        height: units.gu(5)
        width: qrShowScanPage.width
        anchors {
            top: header.bottom
            left: qrShowScanPage.left
            right: qrShowScanPage.right
        }
        actions: [
            Action {
                text: i18n.tr("QR Invite Code")
                onTriggered: {
                    if (scanSectionActive) {
                        scanSectionActive = false
                        qrImage.visible = true
                        qrScanRect.visible = false
                        camera.stopAll()
                        DeltaHandler.deleteQrDecoder()
                    }
                }
            },
            Action {
                text: i18n.tr("Scan QR Code")
                onTriggered: {
                    if (!scanSectionActive) {
                        DeltaHandler.prepareQrDecoder()
                        scanSectionActive = true
                        qrImage.visible = false
                        qrScanRect.visible = true
                        camera.startAndConfigure()
                    }
                }
            }
        ]
    }

    Image {
        id: qrImage
        width: (parent.width < parent.height - qrHeader.height - qrSections.height ? parent.width : parent.height - qrHeader.height - qrSections.height) - units.gu(2)
        height: width
        anchors {
            top: qrSections.bottom
            topMargin: units.gu(2)
            left: parent.left
            leftMargin: units.gu(1)
        }
        source: StandardPaths.locate(StandardPaths.CacheLocation, DeltaHandler.getQrInviteSvg())
        fillMode: Image.PreserveAspectFit

        MouseArea {
            id: qrImageMouse
            anchors.fill: parent
            onClicked: {
                PopupUtils.open(popoverQrComp, qrImage)
            }
        }
    }

    Rectangle {
        id: qrScanRect
        width: qrShowScanPage.width
        height: qrShowScanPage.height - header.height - qrSections.height
        anchors {
            top: qrSections.bottom
            left: parent.left
        }
        color: theme.palette.normal.background

        Camera {
            id: camera

            focus.focusMode: Camera.FocusMacro + Camera.FocusContinuous
            focus.focusPointMode: Camera.FocusPointCenter

            exposure.exposureMode: Camera.ExposureBarcode
            exposure.meteringMode: Camera.MeteringSpot

            imageProcessing.sharpeningLevel: 0.5
            imageProcessing.denoisingLevel: 0.25

            viewfinder.minimumFrameRate: 30.0
            viewfinder.maximumFrameRate: 30.0

            function startAndConfigure() {
                start()
                videoOutput.source = camera
                captureTimer.start()
                focus.focusMode = Camera.FocusContinuous
                focus.focusPointMode = Camera.FocusPointCenter
            }

            function stopAll() {
                captureTimer.stop()
                // // if stop() is called, the camera will take a VERY long
                // // time to recover. If the user switches back to the 
                // // section with the invite code and then back to the
                // // scanning section, the videoOutput rectangle will stay
                // // black and no code will be scanned for a long time.
                // // Don't know why, sometimes putting the app in the background
                // // shortly will fix it party. But in addition, focussing will not
                // // work after starting the camera again. So just
                // // don't stop().
                // stop()
            }
        }

        Timer {
            id: captureTimer
            interval: 250
            repeat: true
            onTriggered: {
                videoOutput.grabToImage(function(result) {
                DeltaHandler.evaluateQrImage(result.image);
                });
            }
        }

        Rectangle {
            id: videoRect
            width: (qrShowScanPage.width > qrShowScanPage.height ? qrShowScanPage.height : qrShowScanPage.width) - header.height - qrSections.height - units.gu(4)
            height: width
            anchors {
                top: qrScanRect.top
                topMargin: units.gu(2)
                left: qrScanRect.left
                leftMargin: qrScanRect.width > qrScanRect.height ? units.gu(2) : (qrScanRect.width - width) / 2
            }
            color: theme.palette.normal.background

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                source: camera
                focus: true
                autoOrientation: true
            }
        }

        Rectangle {
            id: scanButtonRect
            width: qrShowScanPage.width > qrShowScanPage.height ? (qrShowScanPage.width - units.gu(2) - videoRect.width - units.gu(3) - units.gu(3)) : (qrShowScanPage.width - units.gu(3) - units.gu(3))
            height: qrShowScanPage.width > qrShowScanPage.height ? (qrShowScanPage.height - units.gu(2) - header.height - qrSections.height - units.gu(2)) : (qrShowScanPage.height - header.height - qrSections.height - units.gu(2) - videoRect.height - units.gu(2) - units.gu(2))

            anchors {
                top: qrShowScanPage.width > qrShowScanPage.height ? qrScanRect.top : videoRect.bottom
                topMargin: units.gu(2)
                left: qrShowScanPage.width > qrShowScanPage.height ? videoRect.right : qrScanRect.left
                leftMargin: units.gu(3)
            }
            color: theme.palette.normal.background

            Label {
                id: moreOptionsLabel
                width: scanButtonRect.width

                anchors {
                    top: scanButtonRect.top
                    left: scanButtonRect.left
                }
                font.bold: true
                text: i18n.tr("More Options")
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                id: pasteButton
                width: scanButtonRect.width
                anchors {
                    top: moreOptionsLabel.bottom
                    topMargin: units.gu(2)
                    left: scanButtonRect.left
                }
                text: i18n.tr("Paste from Clipboard")

                onClicked: {
                    qrActionSwitch(DeltaHandler.evaluateQrCode(Clipboard.data.text))
                }
            }

//            // TODO: implement
//            Button {
//                id: loadQrImageButton
//                width: scanButtonRect.width
//                anchors {
//                    top: pasteButton.bottom
//                    topMargin: units.gu(2)
//                    left: scanButtonRect.left
//                }
//                text: i18n.tr("Load QR Code as Image")
//            }
        } // end Rectangle id: scanButtonRect
    } // end Rectangle id: qrScanRect

    Component {
        id: popoverQrComp
        Popover {
            id: popoverQrCopyToClipboard
            ListItem {
                height: layout1.height
                // should be automatically be themed with something like
                // theme.palette.normal.overlay, but this
                // doesn't seem to work for Ambiance (and importing
                // Ubuntu.Components.Themes 1.3 doesn't solve it). 
                color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                ListItemLayout {
                    id: layout1
                    title.text: i18n.tr("Copy to Clipboard")
                }
                onClicked: {
                     onClicked: Clipboard.push(DeltaHandler.getQrInviteTxt())
                     PopupUtils.close(popoverQrCopyToClipboard)
                }
            }
        }
    }

    Timer {
        id: continueTimer
        interval: 100
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            layout.removePages(primaryPage)
            DeltaHandler.continueQrCodeAction()
        }
    }

    Timer {
        // TODO: needed?
        id: cancelTimer
        interval: 100
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            layout.removePages(primaryPage)
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
