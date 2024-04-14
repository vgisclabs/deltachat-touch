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
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
//import Qt.labs.settings 1.0
//import Qt.labs.platform 1.1
import QtMultimedia 5.12
//import QtQml.Models 2.12

import DeltaHandler 1.0

Page {
    id: addAccountAsSecondPage

    signal setTempContextNull()
    signal deleteDecoder()

    Component.onDestruction: {
        camera.stopAll()
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
        PopupUtils.open(errorPopup, addAccountAsSecondPage, { text: errorMsg })
        // Function is called as a result of loading an image;
        // for that, the camera was stopped. Need to
        // start it again now.
        camera.startAndConfigure()
    }

    function qrActionSwitch(qrstate) {
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
                    // don't start continueTimer here as the page will be closed
                    // in a subsequent action
                    DeltaHandler.continueQrCodeAction()
                })
                popup.cancel.connect(function() {
                    PopupUtils.close(popup)
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

    function goBack() {
        // TODO: This will go back to the AddAccount page, go back to the
        // AccountConfig page instead?  Or check whether a configured account
        // exists, and then go back to the Main page?
        layout.removePages(addAccountAsSecondPage)
    }

    function continueQrAccountCreation(wasSuccessful) {
        if (wasSuccessful) {
            PopupUtils.open(configProgress)
        } else {
            PopupUtils.open(errorPopup)
            // TODO is this needed? It's called onDestruction, so it should be
            // called in each case anyway?
            setTempContextNull()
        }
    }

    function continueQrBackupImport() {
        let popup2 = PopupUtils.open(progressQrBackupImport)
        popup2.failed.connect(goBack)
        popup2.cancelled.connect(goBack)
    }

    function passQrImage(imagePath) {
        if (root.onUbuntuTouch) {
            root.fileImported.disconnect(addAccountAsSecondPage.passQrImage)
        }
        DeltaHandler.loadQrImage(imagePath)
    }

    Loader {
        id: picImportLoader
    }

    Connections {
        target: picImportLoader.item
        onFileSelected: {
            let tempPath = DeltaHandler.copyToCache(urlOfFile);
            addAccountAsSecondPage.passQrImage(tempPath)
            picImportLoader.source = ""
        }
        onCancelled: {
            picImportLoader.source = ""
        }
    }

    header: PageHeader {
        id: qrHeader
        title: i18n.tr("Scan QR Code")
    }

    Rectangle {
        id: qrScanRect
        width: addAccountAsSecondPage.width
        height: addAccountAsSecondPage.height - qrHeader.height
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
                stop()
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
            width: (addAccountAsSecondPage.width > addAccountAsSecondPage.height ? addAccountAsSecondPage.height : addAccountAsSecondPage.width) - qrHeader.height - units.gu(4)
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
            width: addAccountAsSecondPage.width > addAccountAsSecondPage.height ? (addAccountAsSecondPage.width - units.gu(2) - videoRect.width - units.gu(3) - units.gu(3)) : (addAccountAsSecondPage.width - units.gu(3) - units.gu(3))
            height: addAccountAsSecondPage.width > addAccountAsSecondPage.height ? (addAccountAsSecondPage.height - units.gu(2) - qrHeader.height - units.gu(2)) : (addAccountAsSecondPage.height - qrHeader.height - units.gu(2) - videoRect.height - units.gu(2) - units.gu(2))

            anchors {
                top: addAccountAsSecondPage.width > addAccountAsSecondPage.height ? qrScanRect.top : videoRect.bottom
                topMargin: units.gu(2)
                left: addAccountAsSecondPage.width > addAccountAsSecondPage.height ? videoRect.right : qrScanRect.left
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
                    if (root.onUbuntuTouch) {
                        // Ubuntu Touch
                        DeltaHandler.newFileImportSignalHelper()
                        DeltaHandler.fileImportSignalHelper.fileImported.connect(addAccountAsSecondPage.passQrImage)
                        layout.addPageToCurrentColumn(addAccountAsSecondPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })
                        // See comments in CreateOrEditGroup.qml
                        //let incubator = layout.addPageToCurrentColumn(addAccountAsSecondPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })

                        //if (incubator.status != Component.Ready) {
                        //    // have to wait for the object to be ready to connect to the signal,
                        //    // see documentation on AdaptivePageLayout and
                        //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                        //    incubator.onStatusChanged = function(status) {
                        //        if (status == Component.Ready) {
                        //            incubator.object.fileSelected.connect(addAccountAsSecondPage.passQrImage)
                        //        }
                        //    }
                        //} else {
                        //    // object was directly ready
                        //    incubator.object.fileSelected.connect(addAccountAsSecondPage.passQrImage)
                        //}
                    } else {
                        // non-Ubuntu Touch
                        picImportLoader.source = "FileImportDialog.qml"
                        picImportLoader.item.setFileType(DeltaHandler.ImageType)
                        picImportLoader.item.open()
                    }
                }
            }
        } // end Rectangle scanButtonRect
    } // end Rectangle id: qrScanRect

    Timer {
        id: continueTimer
        interval: 100
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            layout.removePages(addAccountAsSecondPage)
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
        id: errorPopup

        ErrorMessage {
            title: i18n.tr("Error")
            // where to get the error from if dc_set_config_from_qr() failed?
            text: ""
        }
    }

    Component {
        id: progressQrBackupImport

        ProgressQrBackupImport { // see file ProgressQrBackupImport.qml
        }
    }
}
