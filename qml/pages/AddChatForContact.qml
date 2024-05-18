/*
 * Copyright (C) 2024  Lothar Ketterer
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
//import QtQuick.Shapes 1.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3 
//import QtQuick.Layouts 1.3
//import Qt.labs.settings 1.0
//import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: page

    property string address: ""

    Component.onCompleted: {
        emailField.text = address
    }

    header: PageHeader {
        id: header
        title: i18n.tr("New Contact")

        // Don't show "back" icon to avoid unclear situation. User
        // has to explicitly choose cancel or ok.
        leadingActionBar.actions: [
            Action {
                //iconName: 'close'
                iconSource: "qrc:///assets/suru-icons/close.svg"
                text: i18n.tr('Cancel')
                onTriggered: {
                    extraStack.pop()
                }
            }
        ]

        //trailingActionBar.numberOfSlots: 2
        trailingActionBar.actions: [
            Action {
                //iconName: 'ok'
                iconSource: "qrc:///assets/suru-icons/ok.svg"
                text: i18n.tr('OK')
                onTriggered: {
                    if (DeltaHandler.isValidAddr(emailField.displayText)) {
                        extraStack.pop()
                        DeltaHandler.contactsmodel.startChatWithAddress(emailField.displayText, nameField.displayText)
                    } else {
                        PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"),
                            page,
                            {"text": i18n.tr("Please enter a valid e-mail address")
                        })
                    }
                }
            }
        ]
    }

    Column {
        anchors {
            top: header.bottom
            topMargin: units.gu(2)
        }

        Button {
            width: page.width - units.gu(4)

            anchors {
                left: parent.left
                leftMargin: units.gu(2)
            }

            //iconName: "view-grid-symbolic"
            iconSource: "qrc:///assets/suru-icons/view-grid-symbolic.svg"
            text: i18n.tr("Scan QR Code")
            onClicked: {
                // Very ugly hack, see Main.qml for details
                root.openScanQrPageOnBottomEdgeCollapse()
                extraStack.pop()
                bottomEdge.collapse()
            }
        }

        Item {
            // spacer item
            height: units.gu(2)
            width: height
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter

            Item {
                height: units.gu(1)
                width: units.gu(2)
            }

            Rectangle {
                height: 1
                width: (page.width / 2 ) - orLabel.contentWidth - units.gu(2)
                anchors.verticalCenter: orLabel.verticalCenter
                color: theme.palette.normal.foregroundText
            }

            Item {
                height: units.gu(1)
                width: units.gu(1)
            }

            Label {
                id: orLabel
                text: i18n.tr("or")
                font.bold: true
            }

            Item {
                height: units.gu(1)
                width: units.gu(1)
            }

            Rectangle {
                height: 1
                width: (page.width / 2 ) - orLabel.contentWidth - units.gu(2)
                anchors.verticalCenter: orLabel.verticalCenter
                color: theme.palette.normal.foregroundText
            }
        }

        Item {
            // spacer item
            height: units.gu(2)
            width: height
        }

        Label {
            id: nameLabel
            anchors {
                left: parent.left
                leftMargin: units.gu(3)
            }
            text: i18n.tr('Name')
        }

        Item {
            // spacer item
            height: units.gu(0.5)
            width: height
        }

        TextField {
            id: nameField
            width: page.width - units.gu(4)
            anchors {
                left: parent.left
                leftMargin: units.gu(2)
            }

            onFocusChanged: {
                if (root.oskViaDbus) {
                    if (focus) {
                        DeltaHandler.openOskViaDbus()
                    } else {
                        DeltaHandler.closeOskViaDbus()
                    }
                }
            }
        }

        Item {
            // spacer item
            height: units.gu(2)
            width: height
        }

        Label {
            id: emailLabel
            anchors {
                left: parent.left
                leftMargin: units.gu(3)
            }
            text: i18n.tr('E-Mail Address')
        }

        Item {
            // spacer item
            height: units.gu(0.5)
            width: height
        }

        TextField {
            id: emailField
            width: nameField.width
            anchors {
                left: parent.left
                leftMargin: units.gu(2)
            }

            onFocusChanged: {
                if (root.oskViaDbus) {
                    if (focus) {
                        DeltaHandler.openOskViaDbus()
                    } else {
                        DeltaHandler.closeOskViaDbus()
                    }
                }
            }
        }
    }
} // end Page id: page
