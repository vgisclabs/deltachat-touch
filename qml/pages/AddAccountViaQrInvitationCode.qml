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
//import Qt.labs.platform 1.1
import QtMultimedia 5.12
//import QtQml.Models 2.12

import DeltaHandler 1.0

Page {
    id: addAccountViaQrPage

    // for the popup to be able to remove pages so only
    // the AccountConfig.qml page is visible in case
    // the configuration of the account failed (e.g., 
    // due to wrong credentials)
    property Page addAccPage

    signal setTempContextNull()
    signal deleteDecoder()

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
        DeltaHandler.qrDecoded.connect(startQrProcessing)
        DeltaHandler.qrDecodingFailed.connect(imageDecodingFailed)
        
        DeltaHandler.prepareQrDecoder()
        camera.startAndConfigure()
    }

    Connections {
        onSetTempContextNull: DeltaHandler.unrefTempContext()
        onDeleteDecoder: DeltaHandler.deleteQrDecoder()
    }

    function startQrProcessing(content) {
        camera.stopAll()
        qrActionSwitch(DeltaHandler.evaluateQrCode(content))
    }

    function imageDecodingFailed(errorMsg) {
        PopupUtils.open(errorPopup, addAccountViaQrPage, { text: errorMsg })
        // Function is called as a result of loading an image;
        // for that, the camera was stopped. Need to
        // start it again now.
        camera.startAndConfigure()
    }

    function qrActionSwitch(qrstate) {
        switch (qrstate) {
            case DeltaHandler.DT_QR_ACCOUNT:
                let popup = PopupUtils.open(
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
                    // need to call camera.startAndConfigure() to start
                    // the captureTimer again.
                    camera.startAndConfigure()
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
                    continueTimer.start()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_LOGIN:
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
                popup = PopupUtils.open(
                    Qt.resolvedUrl("QrConfirmPopup.qml"),
                    null,
                    { textOne: i18n.tr("Error"),
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
            PopupUtils.open(errorPopup)
            setTempContextNull()
        }
    }

    header: PageHeader {
        id: qrHeader
        title: i18n.tr("Scan QR Code")
    }

    Rectangle {
        id: qrScanRect
        width: addAccountViaQrPage.width
        height: addAccountViaQrPage.height - qrHeader.height
        anchors {
            top: qrHeader.bottom
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
            width: (addAccountViaQrPage.width > addAccountViaQrPage.height ? addAccountViaQrPage.height : addAccountViaQrPage.width) - qrHeader.height - units.gu(4)
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
            width: addAccountViaQrPage.width > addAccountViaQrPage.height ? (addAccountViaQrPage.width - units.gu(2) - videoRect.width - units.gu(3) - units.gu(3)) : (addAccountViaQrPage.width - units.gu(3) - units.gu(3))
            height: addAccountViaQrPage.width > addAccountViaQrPage.height ? (addAccountViaQrPage.height - units.gu(2) - qrHeader.height - units.gu(2)) : (addAccountViaQrPage.height - qrHeader.height - units.gu(2) - videoRect.height - units.gu(2) - units.gu(2))

            anchors {
                top: addAccountViaQrPage.width > addAccountViaQrPage.height ? qrScanRect.top : videoRect.bottom
                topMargin: units.gu(2)
                left: addAccountViaQrPage.width > addAccountViaQrPage.height ? videoRect.right : qrScanRect.left
                leftMargin: units.gu(3)
            }
            color: theme.palette.normal.background

            Label {
                id: holdCameraLabel
                width: scanButtonRect.width

                anchors {
                    top: scanButtonRect.top
                    left: scanButtonRect.left
                }
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: i18n.tr("Hold your camera over the QR code.")
            }

            Label {
                id: moreOptionsLabel
                width: scanButtonRect.width

                anchors {
                    top: holdCameraLabel.bottom
                    topMargin: units.gu(2)
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
                    camera.stopAll()
                    qrActionSwitch(DeltaHandler.evaluateQrCode(Clipboard.data.text))
                }
            }

            Button {
                id: loadQrImageButton
                width: scanButtonRect.width
                anchors {
                    top: pasteButton.bottom
                    topMargin: units.gu(2)
                    left: scanButtonRect.left
                }
                text: i18n.tr("Load QR Code as Image")
                onClicked: {
                    camera.stopAll()
                    layout.addPageToCurrentColumn(addAccountViaQrPage, Qt.resolvedUrl("PickerQrImageLoad.qml"))
                }
            }
        } // end Rectangle id: scanButtonRect
    } // end Rectangle id: qrScanRect

    Timer {
        id: continueTimer
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
            pageToRemove: addAccPage
            calledFromQrInviteCode: true
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
