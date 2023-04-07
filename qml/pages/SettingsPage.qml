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

import DeltaHandler 1.0

Page {
    id: settingsPage

    Component.onDestruction: {
        
    }

    Component.onCompleted: {
        offlineSwitch.checked = root.syncAll
    }

    header: PageHeader {
        id: settingsHeader
        title: i18n.tr("Settings")

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
                text: i18n.tr('About')
                onTriggered: {
                            layout.addPageToCurrentColumn(settingsPage, Qt.resolvedUrl('About.qml'))
                }
            }
        ]
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.topMargin: (settingsPage.header.flickable ? 0 : settingsPage.header.height)
        anchors.bottomMargin: units.gu(2)
        contentHeight: flickContent.childrenRect.height

        Column {
            id: flickContent
            width: parent.width

            ListItem {
                height: offlineLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: offlineLayout
                    title.text: i18n.tr("Sync all")

                    Switch {
                        id: offlineSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        onCheckedChanged: {
                            root.syncAll = offlineSwitch.checked
                            root.startStopIO()
                        }
                    }
                }
            }

            ListItem {
                height: accountsItemLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: accountsItemLayout
                    title.text: i18n.tr("Accounts")

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    layout.addPageToCurrentColumn(settingsPage, Qt.resolvedUrl("AccountConfig.qml"))
                }
            }

            Rectangle {
                id: profileSpecificSeparator
                height: profileSpecificSeparatorLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: profileSpecificSeparatorLabel
                    anchors {
                        top: profileSpecificSeparator.top
                        topMargin: units.gu(3)
                        horizontalCenter: profileSpecificSeparator.horizontalCenter
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Profile specific settings")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                height: readReceiptsLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: readReceiptsLayout
                    title.text: i18n.tr("Read Receipts")

                    Switch {
                        id: readReceiptsSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("mdns_enabled") === "1")
                        // TODO: If checked is set like this, checkedChanged will be triggered
                        // when it is set to true. Maybe set in onCompleted, guarded by a property
                        // (e.g., noActionOnCheckedChanged) which is evaluated in onCheckedChanged
                        // below?
                        onCheckedChanged: {
                            if (readReceiptsSwitch.checked) {
                                console.log("================== setting mdns_enabled = 1")
                                DeltaHandler.setCurrentConfig("mdns_enabled", "1")
                            } else {
                                DeltaHandler.setCurrentConfig("mdns_enabled", "0")
                                console.log("================== setting mdns_enabled = 0")
                            }
                        }
                    }
                }
            }

            ListItem {
                height: blockedContactsLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: blockedContactsLayout
                    title.text: i18n.tr("Blocked Contacts")
                    //text.color: "red" //DeltaHandler.hasConfiguredAccount ? theme.palette.normal.baseText : theme.palette.disabled.baseText

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    DeltaHandler.prepareBlockedContactsModel()
                    // the BlockedContacts page will be opened when
                    // the signal blockedcontactsmodelChanged is received
                    // see Connections below
                }
                enabled: DeltaHandler.hasConfiguredAccount
            }

            ListItem {
                height: profilesLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: profilesLayout
                    title.text: i18n.tr("Profile")

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    layout.addPageToCurrentColumn(settingsPage, Qt.resolvedUrl("Profile.qml"))
                }
            }
        }
    }

    Connections {
        target: DeltaHandler
        onBlockedcontactsmodelChanged: {
            layout.addPageToCurrentColumn(settingsPage, Qt.resolvedUrl("BlockedContacts.qml"))
        }
    }
}
