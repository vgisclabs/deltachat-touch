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
        updateDeleteFromDeviceCurrentSetting()
        updateDeleteFromServerCurrentSetting()
    }

    property string showClassicMailsCurrentSetting: ""
    property string autoDownloadCurrentSetting: ""
    property string deleteFromDeviceCurrentSetting: ""
    property string deleteFromServerCurrentSetting: ""

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
    
    function updateDeleteFromDeviceCurrentSetting() {
        switch (DeltaHandler.getCurrentConfig("delete_device_after")) {
            case "0":
                deleteFromDeviceCurrentSetting = i18n.tr("Never")
                break;

            case "3600":
                deleteFromDeviceCurrentSetting = i18n.tr("After 1 hour")
                break;

            case "86400":
                deleteFromDeviceCurrentSetting = i18n.tr("After 1 day")
                break;

            case "604800":
                deleteFromDeviceCurrentSetting = i18n.tr("After 1 week")
                break;

            case "2419200":
                deleteFromDeviceCurrentSetting = i18n.tr("After 4 weeks")
                break;

            case "31536000":
                deleteFromDeviceCurrentSetting = i18n.tr("After 1 year")
                break;

            default: 
                deleteFromDeviceCurrentSetting = i18n.tr("?")
                break;
        }
    }

    function updateDeleteFromServerCurrentSetting() {
        switch (DeltaHandler.getCurrentConfig("delete_server_after")) {
            case "0":
                deleteFromServerCurrentSetting = i18n.tr("Never")
                break;

            case "1":
                deleteFromServerCurrentSetting = i18n.tr("At once")
                break;

            case "30":
                deleteFromServerCurrentSetting = i18n.tr("After 30 seconds")
                break;

            case "60":
                deleteFromServerCurrentSetting = i18n.tr("After 1 minute")
                break;

            case "3600":
                deleteFromServerCurrentSetting = i18n.tr("After 1 hour")
                break;

            case "86400":
                deleteFromServerCurrentSetting = i18n.tr("After 1 day")
                break;

            case "604800":
                deleteFromServerCurrentSetting = i18n.tr("After 1 week")
                break;

            case "2419200":
                deleteFromServerCurrentSetting = i18n.tr("After 4 weeks")
                break;

            case "31536000":
                deleteFromServerCurrentSetting = i18n.tr("After 1 year")
                break;

            default: 
                deleteFromServerCurrentSetting = i18n.tr("?")
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
        //anchors.bottomMargin: units.gu(2)
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
                    //font.bold: true
                    fontSize: "large"
                }
                color: theme.palette.normal.background
            }

            Rectangle {
                id: prefBlockedSectionHeader
                height: prefBlockedSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefBlockedSectionHeaderLabel
                    anchors {
                        top: prefBlockedSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefBlockedSectionHeader.left
                        leftMargin: units.gu(1)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Blocked Contacts")
                    font.bold: true
                }
                color: theme.palette.normal.background
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

            Rectangle {
                id: prefProfileSectionHeader
                height: prefProfileSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefProfileSectionHeaderLabel
                    anchors {
                        top: prefProfileSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefProfileSectionHeader.left
                        leftMargin: units.gu(1)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Profile")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                height: profilesLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: profilesLayout
                    title.text: i18n.tr("Edit Profile")

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

            Rectangle {
                id: prefChatsSectionHeader
                height: prefChatsSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefChatsSectionHeaderLabel
                    anchors {
                        top: prefChatsSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefChatsSectionHeader.left
                        leftMargin: units.gu(1)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Chats")
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

            Rectangle {
                id: prefPrivacySectionHeader
                height: prefPrivacySectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefPrivacySectionHeaderLabel
                    anchors {
                        top: prefPrivacySectionHeader.top
                        topMargin: units.gu(3)
                        left: prefPrivacySectionHeader.left
                        leftMargin: units.gu(1)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Privacy")
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
                                DeltaHandler.setCurrentConfig("mdns_enabled", "1")
                            } else {
                                DeltaHandler.setCurrentConfig("mdns_enabled", "0")
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: prefDelOldSectionHeader
                height: prefDelOldSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefDelOldSectionHeaderLabel
                    anchors {
                        top: prefDelOldSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefDelOldSectionHeader.left
                        leftMargin: units.gu(1)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Delete Old Messages")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: deleteFromDeviceItem
                height: deleteFromDeviceLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: deleteFromDeviceLayout
                    title.text: i18n.tr("Delete Messages from Device")

                    Label {
                        id: deleteFromDeviceLabel
                        width: settingsPage.width/4
                        text: deleteFromDeviceCurrentSetting
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
                    PopupUtils.open(popoverComponentDeleteFromDevice, deleteFromDeviceItem)
                }
            }

            ListItem {
                id: deleteFromServerItem
                height: deleteFromServerLayout.height + (divider.visible ? divider.height : 0)
                width: settingsPage.width

                ListItemLayout {
                    id: deleteFromServerLayout
                    title.text: i18n.tr("Delete Messages from Server")

                    Label {
                        id: deleteFromServerLabel
                        width: settingsPage.width/4
                        text: deleteFromServerCurrentSetting
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
                    PopupUtils.open(popoverComponentDeleteFromServer, deleteFromServerItem)
                }
            }

            Rectangle {
                id: prefBackupSectionHeader
                height: prefBackupSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefBackupSectionHeaderLabel
                    anchors {
                        top: prefBackupSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefBackupSectionHeader.left
                        leftMargin: units.gu(1)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Backup")
                    font.bold: true
                }
                color: theme.palette.normal.background
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

            Rectangle {
                id: prefAdvancedSectionHeader
                height: prefAdvancedSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefAdvancedSectionHeaderLabel
                    anchors {
                        top: prefAdvancedSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefAdvancedSectionHeader.left
                        leftMargin: units.gu(1)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Advanced")
                    font.bold: true
                }
                color: theme.palette.normal.background
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

            Component {
                id: popoverComponentDeleteFromDevice
                Popover {
                    id: popoverDeleteFromDevice
                    Column {
                        id: containerLayoutDelDevice
                        anchors {
                            left: parent.left
                            top: parent.top
                            right: parent.right
                        }

                        ListItem {
                            height: layout51.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout51
                                title.text: i18n.tr("Never")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("delete_device_after", "0")
                                PopupUtils.close(popoverDeleteFromDevice)
                                updateDeleteFromDeviceCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout52.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout52
                                title.text: i18n.tr("After 1 hour")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromDevice.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "3600", "deleteAfterXTime": i18n.tr("After 1 hour")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromDevice)
                                    updateDeleteFromDeviceCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout53.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout53
                                title.text: i18n.tr("After 1 day")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromDevice.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "86400", "deleteAfterXTime": i18n.tr("After 1 day")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromDevice)
                                    updateDeleteFromDeviceCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout54.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout54
                                title.text: i18n.tr("After 1 week")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromDevice.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "604800", "deleteAfterXTime": i18n.tr("After 1 week")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromDevice)
                                    updateDeleteFromDeviceCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout55.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout55
                                title.text: i18n.tr("After 4 weeks")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromDevice.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "2419200", "deleteAfterXTime": i18n.tr("After 4 weeks")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromDevice)
                                    updateDeleteFromDeviceCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout56.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout56
                                title.text: i18n.tr("After 1 year")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromDevice.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "31536000", "deleteAfterXTime": i18n.tr("After 1 year")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromDevice)
                                    updateDeleteFromDeviceCurrentSetting()
                                })
                            }
                        }
                    }
                }
            }

            Component {
                id: popoverComponentDeleteFromServer
                Popover {
                    id: popoverDeleteFromServer
                    Column {
                        id: containerLayoutDelServer
                        anchors {
                            left: parent.left
                            top: parent.top
                            right: parent.right
                        }

                        ListItem {
                            height: layout61.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout61
                                title.text: i18n.tr("Never")
                            }
                            onClicked: {
                                DeltaHandler.setCurrentConfig("delete_server_after", "0")
                                PopupUtils.close(popoverDeleteFromServer)
                                updateDeleteFromServerCurrentSetting()
                            }
                        }

                        ListItem {
                            height: layout62.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout62
                                title.text: i18n.tr("At once")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromServer.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "1", "deleteAfterXTime": i18n.tr("At once")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromServer)
                                    updateDeleteFromServerCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout63.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout63
                                title.text: i18n.tr("After 30 seconds")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromServer.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "30", "deleteAfterXTime": i18n.tr("After 30 seconds")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromServer)
                                    updateDeleteFromServerCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout64.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout64
                                title.text: i18n.tr("After 1 minute")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromServer.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "60", "deleteAfterXTime": i18n.tr("After 1 minute")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromServer)
                                    updateDeleteFromServerCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout65.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout65
                                title.text: i18n.tr("After 1 hour")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromServer.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "3600", "deleteAfterXTime": i18n.tr("After 1 hour")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromServer)
                                    updateDeleteFromServerCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout66.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout66
                                title.text: i18n.tr("After 1 day")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromServer.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "86400", "deleteAfterXTime": i18n.tr("After 1 day")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromServer)
                                    updateDeleteFromServerCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout67.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout67
                                title.text: i18n.tr("After 1 week")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromServer.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "604800", "deleteAfterXTime": i18n.tr("After 1 week")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromServer)
                                    updateDeleteFromServerCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout68.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout68
                                title.text: i18n.tr("After 4 weeks")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromServer.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "2419200", "deleteAfterXTime": i18n.tr("After 4 weeks")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromServer)
                                    updateDeleteFromServerCurrentSetting()
                                })
                            }
                        }

                        ListItem {
                            height: layout69.height
                            color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                            ListItemLayout {
                                id: layout69
                                title.text: i18n.tr("After 1 year")
                            }
                            onClicked: {
                                let popup = PopupUtils.open(
                                    Qt.resolvedUrl("ConfirmDeleteFromServer.qml"),
                                    null,
                                    { "deleteAfterXSeconds": "31536000", "deleteAfterXTime": i18n.tr("After 1 year")}
                                )
                                popup.confirmed.connect(function() {
                                    PopupUtils.close(popup)
                                    PopupUtils.close(popoverDeleteFromServer)
                                    updateDeleteFromServerCurrentSetting()
                                })
                            }
                        }
                    } // end Column id: containerLayoutDelServer
                } // end Popover id: popoverDeleteFromServer
            } // end Component id: popoverComponentDeleteFromServer
        } // end Column id: flickContent
    } // end Flickable id: flickable

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
