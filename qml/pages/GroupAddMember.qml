/*
 * Copyright (C) 2023  Lothar Ketterer
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
//import Ubuntu.Components.Popups 1.3 // for the popover component
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
//import Qt.labs.settings 1.0
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: addMemberToGroupPage
    anchors.fill: parent
    header: PageHeader {
        id: addMemberToGroupHeader
        title: i18n.tr('Add Members')

        leadingActionBar.actions: [
            Action {
                iconName: 'close'
                text: i18n.tr('Cancel')
                onTriggered: {
                    clearQuery()
                    leavingAddMemberToGroupPage(false)
                    layout.removePages(addMemberToGroupPage)
                }
            }
        ]

        //trailingActionBar.numberOfSlots: 2
        trailingActionBar.actions: [
            Action {
                iconName: 'ok'
                text: i18n.tr('OK')
                onTriggered: {
                    clearQuery()
                    leavingAddMemberToGroupPage(true)
                    layout.removePages(addMemberToGroupPage)
                }
            }
        ]
    }

    signal textHasChanged(string query)
    signal addToGroup(int myindex)
    signal removeFromGroup(int myindex)
    signal leavingAddMemberToGroupPage(bool actionRequested)
    
    function clearQuery() {
        enterNameOrEmailField.text = ""
    }

    Label {
        id: enterNameOrEmailLabel
        anchors {
            horizontalCenter: enterNameOrEmailField.horizontalCenter
            top: addMemberToGroupHeader.bottom
            topMargin: units.gu(1)
        }
        text: i18n.tr('Enter name or e-mail address')
    }

    TextField {
        id: enterNameOrEmailField
        width: parent.width < units.gu(45) ? parent.width - units.gu(8) : units.gu(37)
        anchors {
            left: parent.left
            leftMargin: units.gu(2)
            top: enterNameOrEmailLabel.bottom
            topMargin: units.gu(1)
        }

        // Without inputMethodHints set to Qg.ImhNoPredictiveText, the
        // clear button only works in x86_64, but not aarch64 and armhf.
        // For the latter two, if the displayed text does not contain a
        // blank, it just doesn't vanish when the button is pressed, but
        // cannot be removed by backspace either. Pressing another
        // character will then clear the field and the pressed character
        // will appear.
        inputMethodHints: Qt.ImhNoPredictiveText
        onDisplayTextChanged: {
            addMemberToGroupPage.textHasChanged(displayText)
        }
    }

    Component {
        id: contactsDelegate

        ListItem {
            id: contactsItem
            height: contactsListItemLayout.height + (divider.visible ? divider.height : 0)
            divider.visible: true

            onClicked: {
                if (!model.isAlreadyMemberOfGroup) {
                //let isSelected = model.isToBeAddedToGroup
                //addMemberToGroupPage.indexSelected(index, isSelected)
                    if (model.isToBeAddedToGroup) {
                        removeFromGroup(index)
                    } else {
                        addToGroup(index)
                    }
                }
            }

            ListItemLayout {
                id: contactsListItemLayout
                title.text: model.displayname == '' ? i18n.tr('Unknown') : model.displayname
                subtitle.text: model.address

                UbuntuShape {
                    id: profPicShape
                    height: units.gu(5)
                    width: height
                    SlotsLayout.position: SlotsLayout.Leading
                    source: model.profilePic == "" ? undefined : profPic

                    Image {
                        id: profPic
                        source: { 
                            if (model.profilePic == "replace_by_addNew") {
                                return Qt.resolvedUrl('../../assets/addNew.svg')
                            } else {
                                return StandardPaths.locate(StandardPaths.AppConfigLocation, model.profilePic)
                            }
                        }
                        visible: false
                    }

                    Label {
                        id: avatarInitialLabel
                        text: model.avatarInitial
                        fontSize: "x-large"
                        color: "white"
                        visible: model.profilePic == ""
                        anchors.centerIn: parent
                    }

                    color: model.avatarColor
                    sourceFillMode: UbuntuShape.PreserveAspectCrop
                    aspect: UbuntuShape.Flat
                } // end of UbuntuShape id: profPicShape

                Image {
                    id: verifiedSymbol
                    source: Qt.resolvedUrl('../../assets/verified.svg')
                    visible: model.isVerified
                    height: memberSelectedIcon.height
                    width: height
                    SlotsLayout.position: SlotsLayout.Trailing
                }

                Icon {
                    id: memberSelectedIcon
                    width: units.gu(3)
                    name: model.isAlreadyMemberOfGroup ? "select" : (model.isToBeAddedToGroup ? "select" : "select-none")
                    opacity: model.isAlreadyMemberOfGroup ? 0.5 : 1
                    SlotsLayout.position: SlotsLayout.Trailing
                }
            } // ListItemLayout id: contactsListItemLayout
        } // ListItem id: contactsItem
    } // Component id: contactsDelegate

    ListView {
        id: view
        clip: true 
        //height: accountConfigPage.height - header.height
        width: addMemberToGroupPage.width
        anchors {
            top: enterNameOrEmailField.bottom
            topMargin: units.gu(1)
            bottom: addMemberToGroupPage.bottom
        }
        model: DeltaHandler.contactsmodel
        delegate: contactsDelegate
//        spacing: units.gu(1)
    }

    Component.onCompleted: {
        addMemberToGroupPage.textHasChanged.connect(DeltaHandler.contactsmodel.updateQuery)
        addMemberToGroupPage.addToGroup.connect(DeltaHandler.contactsmodel.addIndexToMemberlist)
        addMemberToGroupPage.removeFromGroup.connect(DeltaHandler.contactsmodel.removeIndexFromMemberlist)
        DeltaHandler.contactsmodel.queryDone.connect(addMemberToGroupPage.clearQuery)
        addMemberToGroupPage.leavingAddMemberToGroupPage.connect(DeltaHandler.contactsmodel.finalizeMemberChanges)
    }
} // end Page id: aboutPage
