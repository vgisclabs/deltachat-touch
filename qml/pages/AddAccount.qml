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
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1

Page {
    id: addAccountPage
    anchors.fill: parent


    header: PageHeader {
        id: header

        title: i18n.tr("Add Account")

//        trailingActionBar.actions: [
//            Action {
//                iconName: 'settings'
//                text: i18n.tr('Settings')
//                onTriggered: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('SettingsPage.qml'))
//            },
//
//            Action {
//                iconName: 'info'
//                text: i18n.tr('About DeltaTouch')
//                onTriggered: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('About.qml'))
//            }
//        ]

    } //PageHeader id:header
        

    ListModel {
        id: addAccountModel
    
        dynamicRoles: true
        Component.onCompleted: {
            addAccountModel.append({ "name": i18n.tr("Log into your E-Mail Account"), "linkToPage": "AddOrConfigureEmailAccount.qml" } )
            addAccountModel.append({ "name": i18n.tr("Add as Second Device"), "linkToPage": "AddAccountAsSecondDevice.qml" } )
            addAccountModel.append({ "name": i18n.tr("Restore from Backup"), "linkToPage": "PickerBackupFile.qml" } )
            addAccountModel.append({ "name": i18n.tr("Scan Invitation Code"), "linkToPage": "AddAccountViaQrInvitationCode.qml" } )
        }
    }
    
    ListView {
        id: addAccountView
        height: addAccountPage.height - header.height - units.gu(1)
        width: addAccountPage.width
        anchors {
            left: addAccountPage.left
            right: addAccountPage.right
            top: header.bottom
            topMargin: units.gu(1)
            bottom: addAccountPage.bottom
        }
        model: addAccountModel
        delegate: accountDelegate
    }
    
    Component {
        id: accountDelegate

        ListItem {
            id: item
            height: listLayout.height + (divider.visible ? divider.height : 0)

            ListItemLayout {
                id: listLayout
                title.text: name

                Icon {
                    name: "go-next"
                    SlotsLayout.position: SlotsLayout.Trailing;
                    width: units.gu(2)
                }
            }

            onClicked: {
                if (linkToPage == "AddAccountViaQrInvitationCode.qml") {
                    // pass this page so it can be used as parameter for layout.removePages() later on in
                    // the process if needed, see ProgressConfigAccount (called pageToRemove there)
                    layout.addPageToCurrentColumn(addAccountPage, Qt.resolvedUrl(linkToPage), { "addAccPage": addAccountPage })
                } else {
                    layout.addPageToCurrentColumn(addAccountPage, Qt.resolvedUrl(linkToPage))
                }
            }
        }
    }
} // end of Page id: addAccountPage
