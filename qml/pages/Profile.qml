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
import QtQuick.Layouts 1.3
import Ubuntu.Components.Popups 1.3
import Qt.labs.settings 1.0
import QtMultimedia 5.12
import QtQml.Models 2.12
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: profilePage

    function updateProfilePic(newPath) {
        profilePicImage.source = StandardPaths.locate(StandardPaths.CacheLocation, newPath)
    }

    Component.onCompleted: {
        // TODO: probably not needed as it is checked in SettingsPage.qml?
        if (!DeltaHandler.hasConfiguredAccount) {
            layout.removePages(layout.primaryPage)
        }
        DeltaHandler.startProfileEdit()
        DeltaHandler.newTempProfilePic.connect(updateProfilePic)
    }

    header: PageHeader {
        id: profileHeader
        title: i18n.tr("Edit Profile")

        // Switch off the back icon to avoid unclear situation. User
        // has to explicitly choose cancel or ok.
        leadingActionBar.actions: undefined

        //trailingActionBar.numberOfSlots: 2
        trailingActionBar.actions: [
          //  Action {
          //      iconName: 'help'
          //      text: i18n.tr('Help')
          //      onTriggered: {
          //          layout.addPageToCurrentColumn(settingsPage, Qt.resolvedUrl('Help.qml'))
          //      }
          //  },
            Action {
                iconName: 'info'
                text: i18n.tr('About DeltaTouch')
                onTriggered: {
                            layout.addPageToCurrentColumn(profilePage, Qt.resolvedUrl('About.qml'))
                }
            }
        ]
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.topMargin: (profilePage.header.flickable ? 0 : profilePage.header.height) + units.gu(2)
        anchors.bottomMargin: units.gu(2)
        contentHeight: flickContent.childrenRect.height

        Item {
            id: flickContent
            width: parent.width
            Label {
                id: profileAddrLabel
                width: parent.width
                anchors {
                    top: parent.top
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                text: i18n.tr("Profile") + ": " + DeltaHandler.getCurrentEmail()
    //            fontSize: "large"
            }

            UbuntuShape {
                id: profilePic
                width: units.gu(15)
                height: width
                anchors {
                    top: profileAddrLabel.bottom
                    topMargin: units.gu(2)
                    left: parent.left
                    leftMargin: units.gu(4)
                }
                color: "grey"
                source: Image {
                    id: profilePicImage
                    source: StandardPaths.locate(StandardPaths.AppConfigLocation, DeltaHandler.getCurrentProfilePic())
                }
                sourceFillMode: UbuntuShape.PreserveAspectCrop
            }

            Button {
                id: selectPicButton
                width: (implicitWidth > deletePicButton.implicitWidth ? implicitWidth : deletePicButton.implicitWidth) + units.gu(2)
                anchors {
                    top: profilePic.bottom
                    topMargin: units.gu(2)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                text: i18n.tr("Select Profile Image")
                onClicked: {
                    layout.addPageToCurrentColumn(profilePage, Qt.resolvedUrl('PickerProfilePic.qml'))
                }
            }
            
            Button {
                id: deletePicButton
                width: (selectPicButton.implicitWidth > implicitWidth ? selectPicButton.implicitWidth : implicitWidth) + units.gu(2)
                anchors {
                    top: selectPicButton.bottom
                    topMargin: units.gu(2)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                text: i18n.tr("Delete Profile Image")
                onClicked: {
                    DeltaHandler.setProfileValue("selfavatar", "")
                    profilePicImage.source = ""
                }
            }

            Label {
                id: usernameLabel
                anchors {
                    top: deletePicButton.bottom
                    topMargin: units.gu(3)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                text: i18n.tr("Your Name")
            }

            TextField {
                id: usernameField
                width: parent.width - units.gu(4)
                anchors {
                    top: usernameLabel.bottom
                    topMargin: units.gu(1)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                text: DeltaHandler.getCurrentUsername()
                
                // When clicking into the TextField, the keyboard appears and
                // obstructs the TextField. The Flickable can be shifted so the
                // bottom is visible by
                // flickable.contentY = flickable.contentHeight - flickable.height
                // However, when instructing this directly in onActiveFocusChanged,
                // it doesn't work because flickable.height is still the old height
                // without the change caused by the keyboard. Waiting for 200 ms
                // via flickTimer and then changing the flickable Y position works.
                // TODO: Is there a signal when the keyboard appears? This would be
                // much cleaner than using a timer.
                onActiveFocusChanged: {
                    if (activeFocus) {
                        flickTimer.start()
                    }
                }
            }

            Label {
                id: signatureLabel
                anchors {
                    top: usernameField.bottom
                    topMargin: units.gu(3)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                text: i18n.tr("Signature Text")
            }
    
            TextField {
                id: signatureField
                width: parent.width - units.gu(4)
                anchors {
                    top: signatureLabel.bottom
                    topMargin: units.gu(1)
                    left: parent.left
                    leftMargin: units.gu(2)
                }
                text: DeltaHandler.getCurrentSignature()
            }

            Rectangle {
                id: okCancelRect
                height: cancelButton.height
                width: cancelButton.width + okButton.width + units.gu(3)
                anchors {
                    //top: signatureField.bottom
                    top: signatureField.bottom
                    topMargin: units.gu(3)
                    left: parent.left
                    leftMargin: units.gu(4)
                }
                color: theme.palette.normal.background


                Button {
                    id: cancelButton
                    width: (implicitWidth > okButton.implicitWidth ? implicitWidth : okButton.implicitWidth) + units.gu(2)
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: i18n.tr('Cancel')
                    // TODO
                    onClicked: layout.removePages(layout.primaryPage)
                }

                Button {
                    id: okButton
                    width: (cancelButton.implicitWidth > implicitWidth ? cancelButton.implicitWidth : implicitWidth) + units.gu(2)
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: i18n.tr('OK')
                    onClicked: {
                        usernameField.focus = false
                        signatureField.focus = false
                        DeltaHandler.setProfileValue("displayname", usernameField.text)
                        DeltaHandler.setProfileValue("selfstatus", signatureField.text)
                        DeltaHandler.finalizeProfileEdit()
                        layout.removePages(layout.primaryPage)
                    }
                }
            } // Rectangle id: okCancelRect
        } // Item id: flickContent

        Timer {
            id: flickTimer
            interval: 200
            repeat: false
            triggeredOnStart: false
            onTriggered: flickable.contentY = flickable.contentHeight - flickable.height
        }
    } // Flickable
} // Page id: profilePage
