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
            Action {
                iconName: 'close'
                text: i18n.tr('Cancel')
                onTriggered: {
                    onClicked: layout.removePages(layout.primaryPage)
                }
            },
            Action {
                iconName: 'ok'
                text: i18n.tr('OK')
                onTriggered: {
                    usernameField.focus = false
                    signatureField.focus = false
                    DeltaHandler.setProfileValue("displayname", usernameField.text)
                    DeltaHandler.setProfileValue("selfstatus", signatureField.text)
                    DeltaHandler.finalizeProfileEdit()
                    layout.removePages(layout.primaryPage)
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

            LomiriShape {
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
                sourceFillMode: LomiriShape.PreserveAspectCrop
            }


            Rectangle {
                // ugly hack to be able to position
                // editImageShape with an offset of 
                // just units.gu(1)
                id: positionHelperEditImage
                height: units.gu(2)
                width: height
                anchors {
                    verticalCenter: profilePic.top
                    horizontalCenter: profilePic.right
                }
                color: theme.palette.normal.background
            }

            LomiriShape {
                id: editImageShape
                height: units.gu(4)
                width: height
                anchors {
                    top: positionHelperEditImage.top
                    right: positionHelperEditImage.right
                }
                //color: theme.palette.normal.background
                color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                Icon {
                    anchors.fill: parent
                    name: "edit"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        PopupUtils.open(componentProfilePicActions, editImageShape)
                    }
                }
            }

            Component {
                id: componentProfilePicActions
                Popover {
                    id: popoverProfilePicActions
                    Column {
                        id: containerLayout
                        anchors {
                            left: parent.left
                            top: parent.top
                            right: parent.right
                        }
                        ListItem {
                            height: layout1.height
                            // should be automatically be themed with something like
                            // theme.palette.normal.overlay, but this
                            // doesn't seem to work for Ambiance (and importing
                            // Lomiri.Components.Themes 1.3 doesn't solve it). 
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout1
                                title.text: i18n.tr("Select Profile Image")
                            }
                            onClicked: {
                                PopupUtils.close(popoverProfilePicActions)
                                layout.addPageToCurrentColumn(profilePage, Qt.resolvedUrl('PickerProfilePic.qml'))
                            }
                        }

                        ListItem {
                            height: layout2.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout2
                                title.text: i18n.tr("Delete Profile Image")
                            }
                            onClicked: {
                                PopupUtils.close(popoverProfilePicActions)
                                DeltaHandler.setProfileValue("selfavatar", "")
                                profilePicImage.source = ""
                            }
                        }
                    }
                } // Popover id: containerLayout
            } // Component id: popoverChatPicActions

            Label {
                id: usernameLabel
                anchors {
                    top: profilePic.bottom
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
