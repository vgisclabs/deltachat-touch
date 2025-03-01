/*
 * Copyright (C) 2022-2024 Lothar Ketterer
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
//import Lomiri.Components.Popups 1.3
//import Qt.labs.settings 1.0
//import QtMultimedia 5.12
//import QtQml.Models 2.12
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: profilePage

    property var contactID
    property bool editMode: false
    property bool isDevice: DeltaHandler.otherContactIsDevice(contactID)
    property string username: DeltaHandler.getOtherDisplayname(contactID)
    property string verifiedBy: DeltaHandler.getOtherVerifiedBy(contactID)
    property string lastSeenString: DeltaHandler.getOtherLastSeen(contactID) == "" ? i18n.tr("Last seen: Unknown") : i18n.tr("Last seen at %1").arg(DeltaHandler.getOtherLastSeen(contactID))
    property string profileImagePath: DeltaHandler.getOtherProfilePic(contactID)
    property string contactStatus: DeltaHandler.getOtherStatus(contactID)

    header: PageHeader {
        id: profileHeader
        title: i18n.tr("View Profile")

        leadingActionBar.actions: [
            Action {
                //iconName: 'close'
                iconSource: "qrc:///assets/suru-icons/close.svg"
                text: i18n.tr('Cancel')
                onTriggered: {
                    onClicked: extraStack.pop()
                }
            }
        ]
    }

    Flickable {
        id: flickable
        anchors {
            top: profileHeader.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        contentHeight: flickContent.childrenRect.height

        Item {
            id: flickContent
            width: parent.width

            LomiriShape {
                id: profilePic
                width: units.gu(15)
                height: width
                anchors {
                    top: parent.top
                    topMargin: units.gu(2)
                    left: parent.left
                    leftMargin: units.gu(2)
                }

                source: profileImagePath == "" ? undefined : avatarImage

                Image {
                    id: avatarImage
                    visible: false
                    source: StandardPaths.locate(StandardPaths.AppConfigLocation, profileImagePath)

                }

                Label {
                    id: avatarInitialLabel
                    text: DeltaHandler.getOtherInitial(contactID)
                    font.pixelSize: units.gu(10)
                    color: "white"
                    visible: profileImagePath == ""
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (profileImagePath != "") {
                            // don't use imageStack as it is layered below extraStack
                            extraStack.push(Qt.resolvedUrl("ImageViewer.qml"), { "imageSource": avatarImage.source, "enableDownloading": false, "onExtraStack": true })
                        }
                    }
                }

                color: DeltaHandler.getOtherColor(contactID)

                sourceFillMode: LomiriShape.PreserveAspectCrop
            } // end LomiriShape id: profilePic

            
            Image {
                id: protectionIcon
                height: units.gu(6)

                anchors {
                    top: parent.top
                    left: parent.left
                    leftMargin: profilePic.width
                }

                source: Qt.resolvedUrl('../assets/verified.svg')
                fillMode: Image.PreserveAspectFit

                visible: DeltaHandler.showContactCheckmark(contactID)
            }

            Label {
                id: usernameLabel
                anchors {
                    verticalCenter: editButtonShape.verticalCenter
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                text: username 

                // needed for right-to-left text such as Arabic
                horizontalAlignment: Text.AlignLeft
                width: profilePage.width - editButtonShape.width - units.gu(6)
                //font.bold: true
                wrapMode: Text.Wrap
                textSize: Label.Large
                visible: !editMode
            }

            LomiriShape {
                id: editButtonShape
                height: units.gu(4)
                width: height
                anchors {
                    top: profilePic.bottom
                    topMargin: units.gu(3)
                    left: parent.left
                    leftMargin: usernameLabel.contentWidth + units.gu(4)
                }
                color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                Icon {
                    //name: "edit"
                    source: "qrc:///assets/suru-icons/edit.svg"
                    height: units.gu(3.5)
                    width: height
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        usernameField.text = username
                        editMode = true
                    }
                }

                visible: !editMode && !isDevice
            }

            TextField {
                id: usernameField
                width: parent.width - units.gu(16)
                anchors {
                    verticalCenter: cancelButtonShape.verticalCenter
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                visible: editMode
                // When clicking into the TextField, the keyboard appears and
                // obstructs the TextField. The Flickable can be shifted so the
                // bottom is visible by
                // flickable.contentY = flickable.contentHeight - flickable.height
                // However, when instructing this directly in onActiveFocusChanged,
                // it doesn't work because flickable.height is still the old height
                // without the change caused by the keyboard. Waiting for 200 ms
                // via flickTimer and then changing the flickable Y position works.
                // Only do this on mobile where an OSK is visible (i.e., on UT, only
                // if the sidebar is not visible. On non-UT, if oskViaDbus is true).
                // TODO: Is there a signal when the keyboard appears? This would be
                // much cleaner than using a timer.
                onFocusChanged: {
                    if (focus && root.onUbuntuTouch && !root.showAccSwitchSidebar) {
                        flickTimer.start()
                    }

                    if (root.oskViaDbus) {
                        if (focus) {
                            DeltaHandler.openOskViaDbus()
                            flickTimer.start()
                        } else {
                            DeltaHandler.closeOskViaDbus()
                        }
                    }
                }
            }

            LomiriShape {
                id: okButtonShape
                height: units.gu(4)
                width: height
                anchors {
                    top: profilePic.bottom
                    topMargin: units.gu(3)
                    left: cancelButtonShape.right
                    leftMargin: units.gu(2)
                }
                color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                Icon {
                    //name: "ok"
                    source: "qrc:///assets/suru-icons/ok.svg"
                    height: units.gu(3.5)
                    width: height
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        usernameField.focus = false
                        username = DeltaHandler.setOtherUsername(contactID, usernameField.text)
                        editMode = false
                    }
                }

                visible: editMode
            }

            LomiriShape {
                id: cancelButtonShape
                height: units.gu(4)
                width: height
                anchors {
                    top: profilePic.bottom
                    topMargin: units.gu(3)
                    left: usernameField.right
                    leftMargin: units.gu(2)
                }
                color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                Icon {
                    //name: "close"
                    source: "qrc:///assets/suru-icons/close.svg"
                    height: units.gu(3.5)
                    width: height
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        usernameField.text = ""
                        editMode = false
                    }
                }

                visible: editMode
            }

            Label {
                id: addrLabel
                text: isDevice ? i18n.tr("Locally generated messages") : DeltaHandler.getOtherAddress(contactID)
                anchors {
                    top: usernameLabel.bottom
                    topMargin: units.gu(2)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
            }

            Image {
                id: verifiedImage
                width: units.gu(4)
                height: width
                anchors {
                    top: addrLabel.bottom
                    topMargin: units.gu(2)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                source: Qt.resolvedUrl("../../assets/verified.svg")
                visible: verifiedBy != "" && !isDevice
            }

            Label {
                id: verifiedLabel
                anchors {
                    verticalCenter: verifiedImage.verticalCenter
                    left: verifiedImage.right
                    leftMargin: units.gu(1)
                }
                text: verifiedBy === "me" ? i18n.tr("Introduced by me") : i18n.tr("Introduced by %1").arg(verifiedBy)
                visible: verifiedBy != "" && !isDevice
            }

            Icon {
                id: lastSeenIcon
                width: units.gu(4)
                height: width
                anchors {
                    top: verifiedBy != "" ? verifiedImage.bottom : addrLabel.bottom
                    topMargin: units.gu(1)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                //name: "clock"
                source: "qrc:///assets/suru-icons/clock.svg"
                visible: !isDevice
            }

            Label {
                id: lastSeenLabel
                anchors {
                    verticalCenter: lastSeenIcon.verticalCenter
                    left: lastSeenIcon.right
                    leftMargin: units.gu(1)
                }
                text: lastSeenString
                visible: !isDevice
            }

            Label {
                id: signatureHeader
                anchors {
                    top: isDevice ? addrLabel.bottom : lastSeenIcon.bottom
                    topMargin: units.gu(2)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                visible: contactStatus != ""
                text: i18n.tr("Signature Text")
            }

            Label {
                id: signatureLabel
                width: profilePage.width - units.gu(4)
                anchors {
                    top: signatureHeader.bottom
                    topMargin: units.gu(1)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                visible: contactStatus != ""
                wrapMode: Text.WordWrap
                text: contactStatus
            }
        } // Item id: flickContent
    } // Flickable

    Timer {
        id: flickTimer
        interval: 200
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            // Calculate Y value of the TextField that the user is about
            // to enter something. Y value means the number of pixels
            // from the top of the Flickable content to the bottom of the TextField.
            let fieldBottomY = profilePic.height + editButtonShape.height + units.gu(6)

            // Check if the TextField is shown on the screen. This is the
            // case if the height of the flickable is not less than
            // the Y value of the TextField minus flickable.contentY (contentY
            // is the offset to which the flickable has been flicked up, i.e.,
            // the number of pixels at the top of the flickable that are not
            // visible at the moment).
            if (flickable.height < fieldBottomY - flickable.contentY) {
                // this will flick up so the TextField is right at the bottom
                flickable.contentY = fieldBottomY - flickable.height
            }
        }
    }
} // Page id: profilePage
