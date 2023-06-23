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
    id: accountConfigPage
    anchors.fill: parent


    header: PageHeader {
        id: header

        title: i18n.tr("Known Accounts")

        leadingActionBar.actions: [
            Action {
                iconName: "go-previous"
                text: i18n.tr("Back")
                onTriggered: {
                    // only allow leaving account configuration
                    // if there's a configured account
                    layout.removePages(accountConfigPage)
                }
                visible: DeltaHandler.hasConfiguredAccount
            }
        ]

        trailingActionBar.actions: [
//            Action {
//                iconName: 'help'
//                text: i18n.tr('Help')
//                // TODO make help page for the Account config page
//                onTriggered: layout.addPageToCurrentColumn(accountConfigPage, Qt.resolvedUrl('About.qml'))
//            },

            Action {
                iconName: 'add'
                text: i18n.tr('Add Account')
                onTriggered: layout.addPageToCurrentColumn(accountConfigPage, Qt.resolvedUrl('AddAccount.qml'))
            }
        ]
    } //PageHeader id:header

    ListItemActions {
        id: leadingAccountAction
        actions: Action {
            iconName: "delete"
            onTriggered: {
                // the index is passed as parameter and can
                // be accessed via 'value'
                PopupUtils.open(
                    Qt.resolvedUrl('ConfirmAccountDeletion.qml'),
                    null,
                    { 'accountArrayIndex': value, }
                )
            }
        }
    }

    ListItemActions {
        id: trailingAccountAction
        actions: [
            Action {
                iconName: "edit"
                onTriggered: {
                    DeltaHandler.accountsmodel.configureAccount(value)
                    layout.addPageToCurrentColumn(accountConfigPage, Qt.resolvedUrl('AddOrConfigureEmailAccount.qml'))
                }
            },
            Action {
                // TODO: Is this info really helpful? Maybe remove it.
                iconName: "info"
                onTriggered: {
                    let tempString = i18n.tr("Info") + ":\n" + DeltaHandler.accountsmodel.getInfoOfAccount(value) + "\n\n" + i18n.tr("Error") + ":\n" + (DeltaHandler.accountsmodel.getLastErrorOfAccount(value) == "" ? i18n.tr("None") : DeltaHandler.accountsmodel.getLastErrorOfAccount(value))
                    PopupUtils.open(
                        Qt.resolvedUrl('InfoPopup.qml'),
                        null,
                        { text: tempString }
                    )
                }
            }
        ]
    }


    Component {
        id: accountsDelegate

        ListItem {
            id: accountsItem
            height: accountsListItemLayout.height + (divider.visible ? divider.height : 0)
            divider.visible: true

            onClicked: {
                if (model.isConfigured) {
                    DeltaHandler.selectAccount(index)
                    layout.removePages(primaryPage)
                }
                else {
                    PopupUtils.open(errorMessage)
                }
            }

            leadingActions: leadingAccountAction
            trailingActions: trailingAccountAction

            ListItemLayout {
                id: accountsListItemLayout
                title.text: model.username == '' ? '[' + i18n.tr('no username set') + ']' : model.username
                subtitle.text: model.address

                UbuntuShape {
                    id: profPicShape
                    height: units.gu(5)
                    width: height
                    SlotsLayout.position: SlotsLayout.Leading
                    source: Image {
                        id: profPic
                        anchors.fill: parent
                        source: model.profilePic == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, model.profilePic)
                    }
                    sourceFillMode: UbuntuShape.PreserveAspectCrop
                    aspect: UbuntuShape.Flat
                } // end of UbuntuShape id:profilePicShape

                Rectangle {
                    id: configStatusRect
                    SlotsLayout.position: SlotsLayout.Trailing
                    height: units.gu(3)
                    width: height
                    color: accountsItem.color
                    Label {
                        id: configStatusLabel
                        text: '!'
                        font.bold: true
                        color: theme.palette.normal.negative 
                        anchors {
                            centerIn: parent
                        }
                        textSize: Label.XLarge
                        visible: !model.isConfigured
                    }
                    //Icon {
                    //    id: configStatusIcon
                    //    color: theme.palette.normal.positive
                    //    anchors {
                    //        fill: parent
                    //    }
                    //    name: "ok"
                    //    visible: model.isConfigured

                    //}
                }
            } // ListItemLayout id: accountsListItemLayout
        } // ListItem accountsItem
    } // Component accountsDelegate

    ListView {
        id: view
        clip: true 
        //height: accountConfigPage.height - header.height
        width: parent.width
        anchors {
            top: header.bottom
            topMargin: units.gu(1)
            bottom: accountConfigPage.bottom
        }
        model: DeltaHandler.accountsmodel
        delegate: accountsDelegate
//        spacing: units.gu(1)
    }

    Component {
        id: errorMessage

        ErrorMessage {
            title: i18n.tr("Error")
            // TODO: probably create new string? Something like
            // "Swipe right and click edit to complete configuration. Choosing info after swiping will give a hint about the last error."
            text: i18n.tr("Account is not configured.")
        }
    }
} // end of Page id: accountConfigPage
