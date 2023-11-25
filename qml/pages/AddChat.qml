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
import Ubuntu.Components.Popups 1.3 // for the popover component
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: addChatPage
    anchors.fill: parent

    header: PageHeader {
        id: addChatHeader
        title: i18n.tr("New Chat")

        leadingActionBar.actions: [
            Action {
                iconName: 'go-down'
                text: i18n.tr('Cancel')
                onTriggered: {
                    bottomEdge.collapse()
                    // reset the text in the TextField, otherwise the
                    // query would remain for the next time the
                    // model is used
                    enterNameOrEmailField.text = ""
                }
            }
        ]
    }

    signal textHasChanged(string query)
    signal indexSelected(int index)

    Button {
        id: newGroupButton
        //width: parent.width < units.gu(40) ? parent.width - units.gu(8) : units.gu(32)
        width: (implicitWidth > newVerifiedGroupButton.implicitWidth ? implicitWidth : newVerifiedGroupButton.implicitWidth) + units.gu(4)
        anchors {
            left: parent.left
            leftMargin: units.gu(2)
            top: addChatHeader.bottom
            topMargin: units.gu(2)
        }
        text: i18n.tr('New Group')
        onClicked: {
            bottomEdge.collapse()
            // reset the text in the TextField, otherwise the
            // selection would also be active for the add members list
            enterNameOrEmailField.text = ""
            DeltaHandler.startCreateGroup(false)
            layout.addPageToCurrentColumn(chatlistPage, Qt.resolvedUrl("CreateOrEditGroup.qml"), {"createNewGroup": true, "createVerifiedGroup": false})
        }
    }

    Button {
        id: newVerifiedGroupButton
        //width: parent.width < units.gu(40) ? parent.width - units.gu(8) : units.gu(32)
        width: (newGroupButton.implicitWidth > implicitWidth ? newGroupButton.implicitWidth : implicitWidth) + units.gu(4)
        anchors {
            left: parent.left
            leftMargin: units.gu(2)
            top: newGroupButton.bottom
            topMargin: units.gu(2)
        }
        text: i18n.tr('New Verified Group')
        onClicked: {
            bottomEdge.collapse()
            // reset the text in the TextField, otherwise the
            // selection would also be active for the add members list
            enterNameOrEmailField.text = ""
            DeltaHandler.startCreateGroup(true)
            layout.addPageToCurrentColumn(chatlistPage, Qt.resolvedUrl("CreateOrEditGroup.qml"), {"createNewGroup": true, "createVerifiedGroup": true})
        }
    }

    Label {
        id: enterNameOrEmailLabel
        anchors {
            horizontalCenter: enterNameOrEmailField.horizontalCenter
            top: newVerifiedGroupButton.bottom
            margins: units.gu(3)
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
        // clear button only works in x86_64, but does not work
        // correctly for  aarch64 and armhf.
        inputMethodHints: Qt.ImhNoPredictiveText
        onDisplayTextChanged: {
            addChatPage.textHasChanged(displayText)
        }
    }

//    ListItemActions {
//        id: leadingContactsAction
//        actions: Action {
//            iconName: "delete"
//            onTriggered: {
//                // the index is passed as parameter and can
//                // be accessed via 'value'
//                // TODO
//                //PopupUtils.open(Qt.resolvedUrl('ConfirmAccountDeletion.qml'), null, {
//                //    'accountArrayIndex': value,
//                //})
//            }
//        }
//    }

    Component {
        id: contactsDelegate

        ListItem {
            id: contactsItem
            height: contactsListItemLayout.height + (divider.visible ? divider.height : 0)
            divider.visible: true

            onClicked: {
                addChatPage.indexSelected(index)
            }

//            leadingActions: leadingContactsAction

            ListItemLayout {
                id: contactsListItemLayout
                title.text: model.displayname == '' ? i18n.tr('Unknown') : model.displayname
                subtitle.text: model.address
                
                Image {
                    id: verifiedSymbol
                    source: Qt.resolvedUrl('../../assets/verified.svg')
                    visible: model.isVerified
                    SlotsLayout.position: SlotsLayout.Trailing
                    height: units.gu(3)
                    width: height
                }

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

                //Rectangle {
                //    id: configStatusRect
                //    SlotsLayout.position: SlotsLayout.Trailing
                //    height: units.gu(3)
                //    width: height
                //    color: theme.palette.normal.background
                //    Label {
                //        id: configStatusLabel
                //        text: '!'
                //        font.bold: true
                //        color: theme.palette.normal.negative 
                //        anchors {
                //            centerIn: parent
                //        }
                //        textSize: Label.XLarge
                //        visible: !model.isConfigured
                //    }
                //    //Icon {
                //    //    id: configStatusIcon
                //    //    color: theme.palette.normal.positive
                //    //    anchors {
                //    //        fill: parent
                //    //    }
                //    //    name: "ok"
                //    //    visible: model.isConfigured

                //    //}
                //}
            } // ListItemLayout id: accountsListItemLayout
        } // ListItem accountsItem
    } // Component accountsDelegate

    ListView {
        id: view
        clip: true 
        //height: accountConfigPage.height - header.height
        width: addChatPage.width
        anchors {
            top: enterNameOrEmailField.bottom
            topMargin: units.gu(1)
            bottom: addChatPage.bottom
        }
        model: DeltaHandler.contactsmodel
        delegate: contactsDelegate
//        spacing: units.gu(1)
    }

    Component.onCompleted: {
        addChatPage.textHasChanged.connect(DeltaHandler.contactsmodel.updateQuery)
        addChatPage.indexSelected.connect(DeltaHandler.contactsmodel.startChatWithIndex)
    }
} // end Page id: aboutPage
