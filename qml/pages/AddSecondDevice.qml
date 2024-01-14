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
import Qt.labs.platform 1.1
//import QtMultimedia 5.12
//import QtQml.Models 2.12

import DeltaHandler 1.0

// This page consists of the QR image which which the addition
// of a second device can be started and a second part.
// The second part is one of these (only one is active at one time):
// - Label "One moment...": Active when the page is created until
//   the QR image is ready
// - Flickable, containing the instructions how to add a second
//   device and a button that links to the help page on delta.chat
//   regarding second device
// - A progress bar (in progressRect) which starts when data is
//   transferred to a second device
//
// The second part is either placed below the QR image or at its right,
// depending on the orientation (portrait or landscape).
Page {
    id: addSecondDevicePage

    property bool landscape: addSecondDevicePage.width > addSecondDevicePage.height

    // Will be set to true when the QR code is copied to the clipboard.
    // If true and the user clicks to exit the page, an additional
    // remark will be shown in the confirmatory popup, see the
    // call to open ConfirmCancelSecondDevice.qml below.
    property bool copiedToClipboard: false

    Component.onDestruction: {
    }

    Component.onCompleted: {
        // if DeltaHandler.prepareBackupProvider() is called here
        // directly, "one moment..." will not be shown, the user will
        // instead be stuck on the settings page until the backup
        // provider preparation has finished
        prepareTimer.start()
    }

    Connections {
        target: DeltaHandler

        onBackupProviderCreationSuccess: {
            preparationLabel.visible = false

            qrImage.source = StandardPaths.locate(StandardPaths.CacheLocation, DeltaHandler.getBackupProviderSvg())
            qrImage.visible = true

            flick.visible = true
        }

        onBackupProviderCreationFailed: {
            preparationLabel.visible = false
            let popup = PopupUtils.open(
                Qt.resolvedUrl("ErrorMessage.qml"),
                null,
                { "title": i18n.tr("Error"), "text": errorMessage}
            )
            popup.done.connect(function() {
                goBackTimer.start()
            })
        }

        onImexEventReceived: {
            if (perMill == 0) {
                progBar.value = perMill
                let popup2 = PopupUtils.open(
                    Qt.resolvedUrl("ErrorMessage.qml"),
                    null,
                    { "title": i18n.tr("Error")}
                )
                popup2.done.connect(function() {
                    goBackTimer.start()
                })
            } else if (perMill == 1000) {
                progBar.value = perMill
                let popup3 = PopupUtils.open(
                    Qt.resolvedUrl("InfoPopup.qml"),
                    null,
                    { "text": i18n.tr("ℹ️ Account transferred to your second device.")}
                )
                popup3.done.connect(function() {
                    goBackTimer.start()
                })
            } else {
                flick.visible = false
                progressRect.visible = true
                progBar.value = perMill
            }
        }
    }

    header: PageHeader {
        id: header
        title: i18n.tr("Add Second Device")

        leadingActionBar.actions: undefined

        trailingActionBar.numberOfSlots: 1
        trailingActionBar.actions: [
            Action {
                iconName: 'close'
                text: i18n.tr('Cancel')
                onTriggered: {
                    let popup4 = PopupUtils.open(
                        Qt.resolvedUrl("ConfirmCancelSecondDevice.qml"),
                        null,
                        { "text": copiedToClipboard ? i18n.tr("This will invalidate the QR code copied to clipboard.") : ""}
                    )
                    popup4.confirmed.connect(function() {
                        DeltaHandler.cancelBackupProvider()
                        goBackTimer.start()
                    })
                }
            }
        ]
    }

    Label {
        // Would be better to show a progress bar while
        // dc_backup_provider_new() is running, but currently imex
        // signals can't be received during preparation of the backup
        // provider ubecause DeltaHandler is blocked
        // until the function returns, so we just show "One moment..."
        // when this page is loaded. See also
        // DeltaHandler.prepareBackupProvider().
        id: preparationLabel
        width: addSecondDevicePage.width - units.gu(8)
        anchors.centerIn: parent
        text: i18n.tr("One moment…")
        wrapMode: Text.WordWrap
    }

    Rectangle {
        id: progressRect
        width: addSecondDevicePage.width - (landscape ? (qrImage.width + units.gu(1)) : 0) - units.gu(4)
        height: progressLabel.height + units.gu(1) + progressShape.height
        
        anchors {
            top: landscape ? header.bottom : qrImage.bottom
            topMargin: units.gu(2)
            left: landscape ? qrImage.right : addSecondDevicePage.left
            leftMargin: units.gu(2)
        }

        color: theme.palette.normal.background
        visible: false

        Label {
            id: progressLabel
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            text: i18n.tr("Transferring…")
        }

        UbuntuShape {
            id: progressShape
            width: parent.width
            height: width / 5
            anchors {
                top: progressLabel.bottom
                topMargin: units.gu(1)
                left: parent.left
            }
            backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

            ProgressBar {
                id: progBar
                width: parent.width - units.gu(3)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                minimumValue: 0
                maximumValue: 1000
                value: 0
            }
        }
    }

    Flickable {
        // on the page, located below or right of the QR image, but
        // listed above it here to avoid overlapping of the image (don't
        // know why that happens, as the anchors, height etc. are set
        // below the image in portrait mode)
        id: flick
        width: addSecondDevicePage.width - (landscape ? qrImage.width : 0) - units.gu(2)
        anchors {
            top: landscape ? header.bottom : qrImage.bottom
            topMargin: units.gu(1)
            bottom: addSecondDevicePage.bottom
            left: landscape ? qrImage.right : addSecondDevicePage.left
            leftMargin: units.gu(1)
        }
        contentHeight: flickContent.childrenRect.height
        boundsBehavior: Flickable.OvershootBounds
        visible: false

        Column {
            id: flickContent
            width: parent.width

            Rectangle {
                width: parent.width
                height: (labelOneShape.height > labelOneText.contentHeight ? labelOneShape.height : labelOneText.contentHeight) + units.gu(2)

                color: theme.palette.normal.background

                UbuntuShape {
                    id: labelOneShape
                    width: labelOne.height + units.gu(1)
                    height: width
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: units.gu(1)
                    }
                    backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                    Label {
                        id: labelOne
                        text: "1"
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                    }
                }
                
                Label {
                    id: labelOneText
                    width: parent.width - labelOneShape.width - units.gu(2)
                    anchors {
                        left: labelOneShape.right
                        leftMargin: units.gu(1)
                        top: parent.top
                    }

                    text: i18n.tr("Install Delta Chat on your other device (https://get.delta.chat)") + " " + i18n.tr("(experimental, version 1.36 required)")
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                width: parent.width
                height: (labelTwoShape.height > labelTwoText.contentHeight ? labelTwoShape.height : labelTwoText.contentHeight) + units.gu(2)

                color: theme.palette.normal.background

                UbuntuShape {
                    id: labelTwoShape
                    width: labelTwo.height + units.gu(1)
                    height: width
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: units.gu(1)
                    }
                    backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                    Label {
                        id: labelTwo
                        text: "2"
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                    }
                }
                
                Label {
                    id: labelTwoText
                    width: parent.width - labelTwoShape.width - units.gu(2)
                    anchors {
                        left: labelTwoShape.right
                        leftMargin: units.gu(1)
                        top: parent.top
                    }

                    text: i18n.tr("Make sure both devices are on the same Wi-Fi or network")
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                width: parent.width
                height: (labelThreeShape.height > labelThreeText.contentHeight ? labelThreeShape.height : labelThreeText.contentHeight) + units.gu(2)

                color: theme.palette.normal.background

                UbuntuShape {
                    id: labelThreeShape
                    width: labelThree.height + units.gu(1)
                    height: width
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: units.gu(1)
                    }
                    backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                    Label {
                        id: labelThree
                        text: "3"
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                    }
                }
                
                Label {
                    id: labelThreeText
                    width: parent.width - labelThreeShape.width - units.gu(2)
                    anchors {
                        left: labelThreeShape.right
                        leftMargin: units.gu(1)
                        top: parent.top
                    }

                    text: i18n.tr("Start Delta Chat, tap “Add as Second Device” and scan the code shown here")
                    wrapMode: Text.WordWrap
                }
            }

            Button {
                id: troubleButton
                width: parent.width - units.gu(8)
                iconSource: root.darkmode ? "../assets/external-link-black.svg" : "../assets/external-link-white.svg"
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("Troubleshooting")
                color: theme.palette.normal.focus
                onClicked: Qt.openUrlExternally("https://delta.chat/en/help#multiclient")
            }

            Rectangle {
                // spacer (otherwise the troubleButton is flush with the bottom)
                width: parent.width
                height: units.gu(2)
                color: theme.palette.normal.background
            }
        }
    }

    Image {
        id: qrImage
        width: (!landscape ? parent.width : parent.height - header.height) - units.gu(2)
        height: width
        anchors {
            top: header.bottom
            topMargin: units.gu(1)
            left: parent.left
            leftMargin: units.gu(1)
        }
        fillMode: Image.PreserveAspectFit

        MouseArea {
            id: qrImageMouse
            anchors.fill: parent
            onClicked: {
                PopupUtils.open(popoverQrComp, qrImage)
            }
        }
    }

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
                    let tempcontent = Clipboard.newData()
                    tempcontent = DeltaHandler.getBackupProviderTxt()
                    Clipboard.push(tempcontent)
                    addSecondDevicePage.copiedToClipboard = true
                    PopupUtils.close(popoverQrCopyToClipboard)
                }
            }
        }
    }

    Timer {
        id: goBackTimer
        interval: 200
        repeat: false
        triggeredOnStart: false
        onTriggered: layout.removePages(primaryPage)
    }

    Timer {
        id: prepareTimer
        interval: 400
        repeat: false
        triggeredOnStart: false
        onTriggered: DeltaHandler.prepareBackupProvider()
    }
}
