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
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3 // for the popover component
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
                }
            }
        ]
    }

    signal textHasChanged(string query)
    signal indexSelected(int index)

    Column {
        id: specialEntryColumn
        anchors {
            left: parent.left
            top: addChatHeader.bottom
            topMargin: units.gu(2)
        }

        TextField {
            id: enterNameOrEmailField
            width: addChatPage.width - units.gu(4)

            anchors {
                left: parent.left
                leftMargin: units.gu(2)
            }

            placeholderText: i18n.tr('Enter name or e-mail address')

            // Without inputMethodHints set to Qg.ImhNoPredictiveText, the
            // clear button only works in x86_64, but does not work
            // correctly for  aarch64 and armhf.
            inputMethodHints: Qt.ImhNoPredictiveText
            onDisplayTextChanged: {
                addChatPage.textHasChanged(displayText)
            }
        }

        ListItem {
            id: newContactItem
            height: newContactLayout.height + (divider.visible ? divider.height : 0)
            width: addChatPage.width

            visible: enterNameOrEmailField.displayText === ""
            ListItemLayout {
                id: newContactLayout
                title.text: i18n.tr('New Contact')
                title.font.bold: true

                LomiriShape {
                    id: addIconShape1
                    height: units.gu(5)
                    width: height
                    SlotsLayout.position: SlotsLayout.Leading
                    source: addPic1

                    Image {
                        id: addPic1
                        source: Qt.resolvedUrl('../../assets/addNew.svg')
                        visible: false
                    }


                    color: "grey"
                    sourceFillMode: LomiriShape.PreserveAspectCrop
                    aspect: LomiriShape.Flat
                } 
            }

            onClicked: {
                layout.addPageToCurrentColumn(chatlistPage, Qt.resolvedUrl("AddChatForContact.qml"))
            }
        }

        ListItem {
            id: newGroupItem
            height: newGroupLayout.height + (divider.visible ? divider.height : 0)
            width: addChatPage.width

            visible: enterNameOrEmailField.displayText === ""
            ListItemLayout {
                id: newGroupLayout
                title.text: i18n.tr('New Group')
                title.font.bold: true

                LomiriShape {
                    id: addIconShape2
                    height: units.gu(5)
                    width: height
                    SlotsLayout.position: SlotsLayout.Leading
                    source: addPic2

                    Image {
                        id: addPic2
                        source: Qt.resolvedUrl('../../assets/addNew.svg')
                        visible: false
                    }


                    color: "grey"
                    sourceFillMode: LomiriShape.PreserveAspectCrop
                    aspect: LomiriShape.Flat
                }
            }

            onClicked: {
                bottomEdge.collapse()
                DeltaHandler.startCreateGroup()
                layout.addPageToCurrentColumn(chatlistPage, Qt.resolvedUrl("CreateOrEditGroup.qml"), { "createNewGroup": true })
            }
        }
    }

    // TODO: Maybe use this to delete contacts? May not be an
    // intuitive place to do so, though
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
                // check if the item is the top one labeled "Add Contact"
                if (model.profilePic == "replace_by_addNew") {
                    layout.addPageToCurrentColumn(chatlistPage, Qt.resolvedUrl("AddChatForContact.qml"), { "address": enterNameOrEmailField.displayText })
                } else {
                    addChatPage.indexSelected(index)
                }
            }

//            leadingActions: leadingContactsAction

            ListItemLayout {
                id: contactsListItemLayout
                title.text: model.displayname == '' ? i18n.tr('Unknown') : model.displayname
                subtitle.text: model.address
                title.font.bold: model.profilePic == "replace_by_addNew" ? true : false
                
                Image {
                    id: verifiedSymbol
                    source: Qt.resolvedUrl('../../assets/verified.svg')
                    visible: model.isVerified
                    SlotsLayout.position: SlotsLayout.Trailing
                    height: units.gu(3)
                    width: height
                }

                LomiriShape {
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
                    sourceFillMode: LomiriShape.PreserveAspectCrop
                    aspect: LomiriShape.Flat
                } // end of LomiriShape id: profPicShape
            } // ListItemLayout id: accountsListItemLayout
        } // ListItem accountsItem
    } // Component accountsDelegate

    ListView {
        id: view
        clip: true 
        //height: accountConfigPage.height - header.height
        width: addChatPage.width
        anchors {
            top: specialEntryColumn.bottom
            bottom: addChatPage.bottom
        }
        model: DeltaHandler.contactsmodel
        delegate: contactsDelegate
//        spacing: units.gu(1)
    }

    Component.onCompleted: {
        addChatPage.textHasChanged.connect(DeltaHandler.contactsmodel.updateQuery)
        addChatPage.indexSelected.connect(DeltaHandler.contactsmodel.startChatWithIndex)

        // reset the text in the TextField, otherwise the
        // query would remain for the next time the
        // model is used
        bottomEdge.collapseStarted.connect(function() { enterNameOrEmailField.text = "" })
    }
} // end Page id: addChatPage
