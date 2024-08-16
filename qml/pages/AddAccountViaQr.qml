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
    id: addAccountViaQrPage

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

    function passQrImage(imagePath) {
        DeltaHandler.loadQrImage(imagePath)
    }

    function startQrProcessing(content) {
        camera.stopAll()
        qrActionSwitch(DeltaHandler.evaluateQrCode(content))
    }

    function imageDecodingFailed(errorMsg) {
        let popup1 = PopupUtils.open(errorPopup, addAccountViaQrPage, { text: errorMsg })
        // Function is called as a result of loading an image;
        // for that, the camera was stopped. Need to
        // start it again now.
        popup1.done.connect(function() { camera.startAndConfigure() })
    }

    function qrActionSwitch(qrstate) {
        switch (qrstate) {
            case DeltaHandler.DT_QR_BACKUP: // fallthrough
            case DeltaHandler.DT_QR_BACKUP2:
                let popup4 = PopupUtils.open(
                    Qt.resolvedUrl("ConfirmDialog.qml"),
                    null,
                    { dialogText: i18n.tr("Copy the account from the other device to this device?"),
                      dialogTitle: i18n.tr("Add as Second Device") }
                )
                popup4.confirmed.connect(function() {
                    DeltaHandler.continueQrCodeAction()
                })
                popup4.cancelled.connect(function() {
                    // need to call camera.startAndConfigure() to start
                    // the captureTimer again.
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_ACCOUNT:
                let popup5 = PopupUtils.open(
                    Qt.resolvedUrl("ConfirmDialog.qml"),
                    null,
                    { dialogText: i18n.tr("Create new e-mail address on \"%1\" and log in there?").arg(DeltaHandler.getQrTextOne()) }
                )
                popup5.confirmed.connect(function() {
                    DeltaHandler.continueQrCodeAction()
                })
                popup5.cancelled.connect(function() {
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_LOGIN:
                let popup6 = PopupUtils.open(
                    Qt.resolvedUrl("ConfirmDialog.qml"),
                    null,
                    { dialogText: i18n.tr("Log into \"%1\"?").arg(DeltaHandler.getQrTextOne()) }
                )
                popup6.confirmed.connect(function() {
                    DeltaHandler.continueQrCodeAction()
                })
                popup6.cancelled.connect(function() {
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_QR_ERROR:
                let popup7 = PopupUtils.open(
                    Qt.resolvedUrl("ErrorMessage.qml"),
                    null,
                    { text: i18n.tr("Error: %1").arg(DeltaHandler.getQrTextOne()) }
                )
                popup7.done.connect(function() {
                    camera.startAndConfigure()
                })
                break;
            case DeltaHandler.DT_UNKNOWN: // fallthrough
            default: 
                let popup8 = PopupUtils.open(
                    Qt.resolvedUrl("ErrorMessage.qml"),
                    null,
                    { text: i18n.tr("The scanned QR code cannot be used to set up a new account.") }
                )
                popup8.done.connect(function() {
                    camera.startAndConfigure()
                })
                break;
        }
    }

    function continueQrAccountCreation(wasSuccessful, calledDuringUrlHandling) {
        // only act if signal was emitted as a result of an active scan of
        // a QR code (i.e., not as a result of an URL passed as parameter
        // to the app itself; see comments in deltahandler.h and Main.qml for the
        // finishedSetConfigFromQr signal)
        if (!calledDuringUrlHandling) {
            if (wasSuccessful) {
                // TODO: Unlike in the call from AddOrConfigureEmailAccount.qml,
                // the account should not persist if the configuration fails (or should it?)
                let popup3 = PopupUtils.open(configProgress)
                popup3.success.connect(function() { extraStack.clear() })
                popup3.failed.connect(function() { extraStack.pop() })
            } else {
                PopupUtils.open(errorPopup)
                setTempContextNull()
            }
        }
    }

    function continueQrBackupImport(calledDuringUrlHandling) {
        // only act if signal was emitted as a result of an active scan of
        // a QR code (i.e., not as a result of an URL passed as parameter
        // to the app itself; see comments in deltahandler.h and Main.qml for the
        // readyForQrBackupImport signal)
        if (!calledDuringUrlHandling) {
            let popup2 = PopupUtils.open(progressQrBackupImport)
            popup2.failed.connect(function() { extraStack.pop() })
            popup2.cancelled.connect(function() { extraStack.pop() })
            popup2.success.connect(function() { extraStack.clear() })
        }
    }

    Loader {
        id: picImportLoader
    }

    Connections {
        target: picImportLoader.item
        onFileSelected: {
            let tempPath = DeltaHandler.copyToCache(urlOfFile);
            addAccountViaQrPage.passQrImage(tempPath)
            picImportLoader.source = ""
        }
        onCancelled: {
            picImportLoader.source = ""
        }
    }

    header: PageHeader {
        id: qrHeader
        title: i18n.tr("Scan QR Code")

        leadingActionBar.actions: [
            Action {
                //iconName: "go-previous"
                iconSource: "qrc:///assets/suru-icons/go-previous.svg"
                text: i18n.tr("Back")
                onTriggered: {
                    extraStack.pop()
                }
            }
        ]
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
            width: (qrScanRect.width > qrScanRect.height ? (qrScanRect.width / 2 > qrScanRect.height ? qrScanRect.height : qrScanRect.width / 2) : (qrScanRect.height / 2 > qrScanRect.width ? qrScanRect.width : qrScanRect.height / 2)) - units.gu(4)
            height: width
            anchors {
                top: qrScanRect.top
                topMargin: units.gu(2)
                left: qrScanRect.left
                leftMargin: qrScanRect.height < qrScanRect.width * 0.8 ? units.gu(2) : ((qrScanRect.width - width) / 2)
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
            width: qrScanRect.height < qrScanRect.width * 0.8 ? (qrScanRect.width - units.gu(2) - videoRect.width - units.gu(3) - units.gu(3)) : (qrScanRect.width - units.gu(3) - units.gu(3))
            height: qrScanRect.height < qrScanRect.width * 0.8 ? (qrScanRect.height - units.gu(2) - units.gu(2)) : (qrScanRect.height - units.gu(2) - videoRect.height - units.gu(2) - units.gu(2))

            anchors {
                top: qrScanRect.height < qrScanRect.width * 0.8 ? qrScanRect.top : videoRect.bottom
                topMargin: units.gu(2)
                left: qrScanRect.height < qrScanRect.width * 0.8 ? videoRect.right : qrScanRect.left
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
                        DeltaHandler.fileImportSignalHelper.fileImported.connect(addAccountViaQrPage.passQrImage)
                        extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })
                        // See comments in CreateOrEditGroup.qml
                        //let incubator = layout.addPageToCurrentColumn(addAccountViaQrPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })

                        //if (incubator.status != Component.Ready) {
                        //    // have to wait for the object to be ready to connect to the signal,
                        //    // see documentation on AdaptivePageLayout and
                        //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                        //    incubator.onStatusChanged = function(status) {
                        //        if (status == Component.Ready) {
                        //            incubator.object.fileSelected.connect(addAccountViaQrPage.passQrImage)
                        //        }
                        //    }
                        //} else {
                        //    // object was directly ready
                        //    incubator.object.fileSelected.connect(addAccountViaQrPage.passQrImage)
                        //}
                    } else {
                        // non-Ubuntu Touch
                        picImportLoader.source = "FileImportDialog.qml"
                        picImportLoader.item.setFileType(DeltaHandler.ImageType)
                        picImportLoader.item.open()
                    }
                }
            }
        } // end Rectangle id: scanButtonRect
    } // end Rectangle id: qrScanRect

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
