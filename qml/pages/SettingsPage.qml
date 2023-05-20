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
        updateShowClassicMailsCurrentSetting()
        updateAutoDownloadCurrentSetting()
    }

    property string showClassicMailsCurrentSetting: ""
    property string autoDownloadCurrentSetting: ""

    // Opens the file export dialog once the backup
    // file has been written to the cache.
    function startFileExport()
    {
        layout.addPageToCurrentColumn(settingsPage, Qt.resolvedUrl('PickerBackupToExport.qml'))

    }

    // Updating the displayed setting for "Show Classic Emails",
    // see Label with id: showClassicMailsLabel
    function updateShowClassicMailsCurrentSetting()
    {
        switch (DeltaHandler.getCurrentConfig("show_emails")) {
            case "0":
                showClassicMailsCurrentSetting = i18n.tr("No, chats only")
                break
            case "1":
                showClassicMailsCurrentSetting = i18n.tr("For accepted contacts")
                break
            case "2":
                showClassicMailsCurrentSetting = i18n.tr("All")
                break
            default:
                showClassicMailsCurrentSetting = "?"
                break
        }
    }

    function updateAutoDownloadCurrentSetting() {
        switch (DeltaHandler.getCurrentConfig("download_limit")) {
            case "0":
                autoDownloadCurrentSetting = i18n.tr("All")
                break;

            case "40960":
                autoDownloadCurrentSetting = i18n.tr("Up to %1").arg("40 KiB")
                break;

            case "163840":
                autoDownloadCurrentSetting = i18n.tr("Up to %1, most worse quality images").arg("160 KiB")
                break;


            case "655360":
                autoDownloadCurrentSetting = i18n.tr("Up to %1, most balanced quality images").arg("640 KiB")
                break;

            case "5242880":
                autoDownloadCurrentSetting = i18n.tr("Up to %1").arg("5 MiB")
                break;

            case "26214400":
                autoDownloadCurrentSetting = i18n.tr("Up to %1").arg("25 MiB")
                break;

            default:
                autoDownloadCurrentSetting = "?"
                break;
        }
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
                text: i18n.tr('About DeltaTouch')
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
                    title.text: i18n.tr("Sync All")

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
                    title.text: i18n.tr("Known Accounts")

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
                    text: i18n.tr("Account specific settings")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: showClassicMailsItem
                height: showClassicMailsLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: showClassicMailsLayout
                    title.text: i18n.tr("Show Classic E-Mails")

                    Label {
                        id: showClassicMailsLabel
                        width: settingsPage.width/4
                        text: showClassicMailsCurrentSetting
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentClassicMail, showClassicMailsItem)
                }
            }

            ListItem {
                id: autoDownloadItem
                height: autoDownloadLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: autoDownloadLayout
                    title.text: i18n.tr("Auto-Download Messages")

                    Label {
                        id: autoDownloadLabel
                        width: settingsPage.width/4
                        text: autoDownloadCurrentSetting
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentAutoDownload, autoDownloadItem)
                }
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
                                DeltaHandler.setCurrentConfig("mdns_enabled", "1")
                            } else {
                                DeltaHandler.setCurrentConfig("mdns_enabled", "0")
                            }
                        }
                    }
                }
            }

            ListItem {
                id: exportBackupItem
                height: exportBackupLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: exportBackupLayout
                    title.text: i18n.tr("Export Backup")

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(progressBackupExport)
                    DeltaHandler.backupFileWritten.connect(startFileExport)
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

            ListItem {
                height: advancedLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: advancedLayout
                    title.text: i18n.tr("Advanced")

                    Icon {
                        name: "go-next"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    layout.addPageToCurrentColumn(settingsPage, Qt.resolvedUrl("AdvancedSettings.qml"))
                }
            }

            Component {
                id: popoverComponentClassicMail
                Popover {
                    id: popoverClassicMail
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
                            // Ubuntu.Components.Themes 1.3 doesn't solve it). 
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout1
                                title.text: i18n.tr("No, chats only")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("show_emails", "0")
                                PopupUtils.close(popoverClassicMail)
                                updateShowClassicMailsCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout2.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout2
                                title.text: i18n.tr("For accepted contacts")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("show_emails", "1")
                                PopupUtils.close(popoverClassicMail)
                                updateShowClassicMailsCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout3.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout3
                                title.text: i18n.tr("All")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("show_emails", "2")
                                PopupUtils.close(popoverClassicMail)
                                updateShowClassicMailsCurrentSetting()
                            }
                        }
                    }
                }
            }

            Component {
                id: popoverComponentAutoDownload
                Popover {
                    id: popoverAutoDownload
                    Column {
                        id: containerLayoutAuto
                        anchors {
                            left: parent.left
                            top: parent.top
                            right: parent.right
                        }
                        ListItem {
                            height: layout41.height
                            // should be automatically be themed with something like
                            // theme.palette.normal.overlay, but this
                            // doesn't seem to work for Ambiance (and importing
                            // Ubuntu.Components.Themes 1.3 doesn't solve it). 
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout41
                                title.text: i18n.tr("All")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "0")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout42.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout42
                                title.text: i18n.tr("Up to %1").arg("40 KiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "40960")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout43.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout43
                                title.text: i18n.tr("Up to %1, most worse quality images").arg("160 KiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "163840")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout44.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout44
                                title.text: i18n.tr("Up to %1, most balanced quality images").arg("640 KiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "655360")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout45.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout45
                                title.text: i18n.tr("Up to %1").arg("5 MiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "5242880")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout46.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout46
                                title.text: i18n.tr("Up to %1").arg("25 MiB")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("download_limit", "26214400")
                                PopupUtils.close(popoverAutoDownload)
                                updateAutoDownloadCurrentSetting()
                            }
                        }
                    }
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

    Component {
        id: progressBackupExport
        ProgressBackupExport {
            title: i18n.tr('Export Backup')
        }
    }
}
