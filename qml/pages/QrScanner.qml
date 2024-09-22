/*
 * Copyright (C) 2022  Lothar Ketterer
 *
 * This file is part of the app "DeltaTouch".
 *
 * DeltaTouch is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.  *
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
    // Once loaded, this page will immediately start scanning for QR codes.
    // If a code is recognized, DeltaHandler.evaluateQrImage() is called.
    // Unless qrstate is DT_QR_ERROR (in which case a popup informs the 
    // user about the error and resumes scanning after the user confirms),
    // the return value of evaluateQrImage() is emitted via detectedQrState()
    // and the page is removed from the stack.
    id: qrScannerPage

    signal deleteDecoder()

    signal qrDetected(string detectedCode)

    Component.onCompleted: {
        DeltaHandler.qrDecoded.connect(startQrProcessing)
        DeltaHandler.qrDecodingFailed.connect(imageDecodingFailed)
        qrDetected.connect(root.newUrlFromScan)
        
        DeltaHandler.prepareQrDecoder()
        camera.startAndConfigure()
    }

    Component.onDestruction: {
        camera.stopAll()
        deleteDecoder()
    }

    Connections {
        onDeleteDecoder: DeltaHandler.deleteQrDecoder()
    }

    function passQrImage(imagePath) {
        DeltaHandler.loadQrImage(imagePath)
    }

    function startQrProcessing(content) {
        camera.stopAll()
        
        let qrstate = DeltaHandler.evaluateQrCode(content)

        if (qrstate === DeltaHandler.DT_QR_ERROR) {
            // in case of an error, display the message and continue scanning
            // after the user confirms the error
            let popup10 = PopupUtils.open(
                Qt.resolvedUrl("ErrorMessage.qml"),
                null,
                { text: i18n.tr("Error: %1").arg(DeltaHandler.getQrTextOne()) }
            )
            popup10.done.connect(function() {
                camera.startAndConfigure()
            })
        } else {
            extraStack.pop()
            qrDetected(content)
        }
    }

    function imageDecodingFailed(errorMsg) {
        let popup1 = PopupUtils.open(errorPopup, qrScannerPage, { text: errorMsg })
        // Function is called as a result of loading an image;
        // for that, the camera was stopped. Need to
        // start it again now.
        popup1.done.connect(function() { camera.startAndConfigure() })
    }

    Loader {
        id: picImportLoader
    }

    Connections {
        target: picImportLoader.item
        onFileSelected: {
            let tempPath = DeltaHandler.copyToCache(urlOfFile);
            qrScannerPage.passQrImage(tempPath)
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
        width: qrScannerPage.width
        height: qrScannerPage.height - qrHeader.height
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
                    startQrProcessing(Clipboard.data.text)
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
                        DeltaHandler.fileImportSignalHelper.fileImported.connect(qrScannerPage.passQrImage)
                        extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })
                        // See comments in CreateOrEditGroup.qml
                        //let incubator = layout.addPageToCurrentColumn(qrScannerPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })

                        //if (incubator.status != Component.Ready) {
                        //    // have to wait for the object to be ready to connect to the signal,
                        //    // see documentation on AdaptivePageLayout and
                        //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                        //    incubator.onStatusChanged = function(status) {
                        //        if (status == Component.Ready) {
                        //            incubator.object.fileSelected.connect(qrScannerPage.passQrImage)
                        //        }
                        //    }
                        //} else {
                        //    // object was directly ready
                        //    incubator.object.fileSelected.connect(qrScannerPage.passQrImage)
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
        id: errorPopup

        ErrorMessage {
            title: i18n.tr("Error")
            // where to get the error from if dc_set_config_from_qr() failed?
            text: ""
        }
    }
}
