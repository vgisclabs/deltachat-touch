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
import Lomiri.Components.Popups 1.3
import Qt.labs.settings 1.0
import QtMultimedia 5.12
import QtQml.Models 2.12
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: profilePage

    Loader {
        id: picImportLoader
    }

    Connections {
        target: picImportLoader.item
        onFileSelected: {
            profilePage.setProfilePic(urlOfFile)
            picImportLoader.source = ""
        }
        onCancelled: {
            picImportLoader.source = ""
        }
    }

    function updateProfilePic(newPath) {
        profilePicImage.source = StandardPaths.locate(StandardPaths.CacheLocation, newPath)
    }

    function setProfilePic(imagePath) {
        let tempPath = DeltaHandler.copyToCache(imagePath);
        DeltaHandler.setProfileValue("selfavatar", tempPath)
    }

    function openFileDialog() {
        // only for non-UT
        picImportLoader.source = "FileImportDialog.qml"
        picImportLoader.item.setFileType(DeltaHandler.ImageType)
        picImportLoader.item.open()
    }

    Component.onCompleted: {
        // TODO: probably not needed as it is checked in SettingsPage.qml?
        if (!DeltaHandler.hasConfiguredAccount) {
            extraStack.pop()
        }
        DeltaHandler.startProfileEdit()
        DeltaHandler.newTempProfilePic.connect(updateProfilePic)
    }

    header: PageHeader {
        id: profileHeader
        title: i18n.tr("Edit Profile")

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

        //trailingActionBar.numberOfSlots: 2
        trailingActionBar.actions: [
            Action {
                //iconName: 'ok'
                iconSource: "qrc:///assets/suru-icons/ok.svg"
                text: i18n.tr('OK')
                onTriggered: {
                    usernameField.focus = false
                    signatureField.focus = false
                    DeltaHandler.setProfileValue("displayname", usernameField.text)
                    DeltaHandler.setProfileValue("selfstatus", signatureField.text)
                    DeltaHandler.finalizeProfileEdit()
                    extraStack.clear()
                }
            }
        ]
    }

    Flickable {
        id: flickable

        anchors {
            top: profileHeader.bottom
            topMargin: units.gu(2)
            bottom: parent.bottom
            bottomMargin: units.gu(2)
            left: parent.left
            leftMargin: units.gu(2)
            right: parent.right
            rightMargin: units.gu(2)
        }

        contentHeight: flickColumn.height

        Column {
            id: flickColumn
            width: parent.width
            spacing: units.gu(1)

            Label {
                id: profileAddrLabel
                width: parent.width
                anchors {
                    left: parent.left
                }
                text: i18n.tr("Profile") + ": " + DeltaHandler.getCurrentEmail()
    //            fontSize: "large"
            }

            Item {
                id: spacerItem1
                height: units.gu(0.1)
                width: units.gu(1)
            }

            Rectangle {
                height: profilePic.height
                width: profilePic.width + units.gu(4)
                anchors.left: parent.left

                color: "transparent"

                LomiriShape {
                    id: profilePic
                    width: units.gu(15)
                    height: width
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: units.gu(2)
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
                        //name: "edit"
                        source: "qrc:///assets/suru-icons/edit.svg"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            PopupUtils.open(componentProfilePicActions, editImageShape)
                        }
                    }
                }
            }

            Item {
                id: spacerItem2
                height: units.gu(0.1)
                width: units.gu(1)
            }

            Label {
                id: usernameLabel
                anchors {
                    left: parent.left
                }
                text: i18n.tr("Your Name")
            }

            TextField {
                id: usernameField
                width: parent.width
                anchors {
                    left: parent.left
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
                // Only do this on mobile where an OSK is visible (i.e., on UT, only
                // if the sidebar is not visible. On non-UT, if oskViaDbus is true).
                // TODO: Is there a signal when the keyboard appears? This would be
                // much cleaner than using a timer.
                onFocusChanged: {
                    if (focus && root.onUbuntuTouch && !root.showAccSwitchSidebar) {
                        flickTimerUsername.start()
                    }

                    if (root.oskViaDbus) {
                        if (focus) {
                            DeltaHandler.openOskViaDbus()
                            flickTimerUsername.start()
                        } else {
                            DeltaHandler.closeOskViaDbus()
                        }
                    }
                }
            }

            Item {
                id: spacerItem3
                height: units.gu(0.1)
                width: units.gu(1)
            }

            Label {
                id: signatureLabel
                anchors {
                    left: parent.left
                }
                text: i18n.tr("Signature Text")
            }
    
            TextField {
                id: signatureField
                width: parent.width
                anchors {
                    left: parent.left
                }
                text: DeltaHandler.getCurrentSignature()

                onFocusChanged: {
                    if (focus && root.onUbuntuTouch && !root.showAccSwitchSidebar) {
                        flickTimerSignature.start()
                    }

                    if (root.oskViaDbus) {
                        if (focus) {
                            DeltaHandler.openOskViaDbus()
                            flickTimerSignature.start()
                        } else {
                            DeltaHandler.closeOskViaDbus()
                        }
                    }
                }
            }
        } // Column id: flickColumn
    } // Flickable

    Timer {
        id: flickTimerUsername
        interval: 200
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            // Calculate Y value of the TextField that the user is about
            // to enter something. Y value means the number of pixels
            // from the top of the Flickable content to the bottom of the TextField.
            let fieldBottomY = profileAddrLabel.height + profilePic.height + usernameLabel.height + usernameField.height + units.gu(5)

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

    Timer {
        id: flickTimerSignature
        interval: 200
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            // see comments for flickTimerUsername above
            let fieldBottomY = profileAddrLabel.height + profilePic.height + usernameLabel.height + usernameField.height + signatureLabel.height + signatureField.height + units.gu(8)
            if (flickable.height < fieldBottomY - flickable.contentY) {
                flickable.contentY = fieldBottomY - flickable.height
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

                        if (root.onUbuntuTouch) {
                            DeltaHandler.newFileImportSignalHelper()
                            DeltaHandler.fileImportSignalHelper.fileImported.connect(profilePage.setProfilePic)
                            extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })
                            // See comments in CreateOrEditGroup.qml
                            //let incubator = layout.addPageToCurrentColumn(profilePage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })

                            //if (incubator.status != Component.Ready) {
                            //    // have to wait for the object to be ready to connect to the signal,
                            //    // see documentation on AdaptivePageLayout and
                            //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                            //    incubator.onStatusChanged = function(status) {
                            //        if (status == Component.Ready) {
                            //            incubator.object.fileSelected.connect(profilePage.setProfilePic)
                            //        }
                            //    }
                            //} else {
                            //    // object was directly ready
                            //    incubator.object.fileSelected.connect(profilePage.setProfilePic)
                            //}
                        } else {
                            profilePage.openFileDialog()
                        }
                    }
                } // ListItem

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
} // Page id: profilePage
