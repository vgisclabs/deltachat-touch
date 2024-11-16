/*
 * Copyright (C) 2023, 2024 Lothar Ketterer
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
import Qt.labs.platform 1.1
import QtMultimedia 5.12
import QtQml.Models 2.12

import DeltaHandler 1.0

Page {
    id: advancedSettingsPage

    Component.onDestruction: {
    }

    Component.onCompleted: {
          updateVoiceMessageQualityCurrentSetting()
    }

    property string voiceMessageQualityCurrentSetting: ""


    // Updating the displayed setting for "Voice Message Quality",
    // see Label with id: voiceMessageQualityLabel
    function updateVoiceMessageQualityCurrentSetting()
    {
        switch (root.voiceMessageQuality) {
            case DeltaHandler.LowRecordingQuality:
                voiceMessageQualityCurrentSetting = i18n.tr("Worse quality, small size")
                break
            case DeltaHandler.BalancedRecordingQuality:
                voiceMessageQualityCurrentSetting = i18n.tr("Balanced")
                break
            case DeltaHandler.HighRecordingQuality:
                voiceMessageQualityCurrentSetting = i18n.tr("High")
                break
            default:
                voiceMessageQualityCurrentSetting = "?"
                break
        }
    }


    header: PageHeader {
        id: settingsHeader
        title: i18n.tr("Advanced")

        leadingActionBar.actions: [
            Action {
                //iconName: "go-previous"
                iconSource: "qrc:///assets/suru-icons/go-previous.svg"
                text: i18n.tr("Back")
                onTriggered: {
                    extraStack.pop()
                }
            }
        ]

        //trailingActionBar.numberOfSlots: 2
//        trailingActionBar.actions: [
//            Action {
//                //iconName: 'help'
//                iconSource: "qrc:///assets/suru-icons/help.svg"
//                text: i18n.tr('Help')
//                onTriggered: {
//                    layout.addPageToCurrentColumn(advancedSettingsPage, Qt.resolvedUrl('Help.qml'))
//                }
//            },
//            Action {
//                //iconName: 'info'
//                iconSource: "qrc:///assets/suru-icons/info.svg"
//                text: i18n.tr('About DeltaTouch')
//                onTriggered: {
//                    extraStack.push(Qt.resolvedUrl('About.qml'))
//                }
//            }
//        ]
    }

    Flickable {
        id: flickableAdvanced
        anchors.fill: parent
        anchors.topMargin: (advancedSettingsPage.header.flickable ? 0 : advancedSettingsPage.header.height)
        anchors.bottomMargin: units.gu(2)
        contentHeight: flickContent.childrenRect.height

        Column {
            id: flickContent
            width: parent.width

//            Rectangle {
//                id: prefVoiceMessagesSectionHeader
//                height: prefVoiceMessagesSectionHeaderLabel.contentHeight + units.gu(3)
//                width: parent.width
//                Label {
//                    id: prefVoiceMessagesSectionHeaderLabel
//                    anchors {
//                        top: prefVoiceMessagesSectionHeader.top
//                        topMargin: units.gu(3)
//                        left: prefVoiceMessagesSectionHeader.left
//                        leftMargin: units.gu(1)
//                    }
//                    // TODO: string not translated
//                    // TODO: maybe solve issue in a different way?
//                    text: i18n.tr("Voice Message")
//                    font.bold: true
//                }
//                color: theme.palette.normal.background
//            }

            Rectangle {
                id: allAccountsSeparator
                height: profileSpecificSeparatorLabel.contentHeight + units.gu(4)
                width: parent.width
                Label {
                    id: allAccountsSeparatorLabel
                    anchors {
                        top: allAccountsSeparator.top
                        topMargin: units.gu(3)
                        horizontalCenter: allAccountsSeparator.horizontalCenter
                    }
                    text: i18n.tr("All Accounts")
                    //font.bold: true
                    fontSize: "large"
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: voiceMessageQualityItem
                height: voiceMessageQualityLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: voiceMessageQualityLayout
                    title.text: i18n.tr("Voice Message Quality")
                    title.font.bold: true

                    Label {
                        id: voiceMessageQualityLabel
                        width: advancedSettingsPage.width/4
                        text: voiceMessageQualityCurrentSetting
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentVoiceMessageQuality, voiceMessageQualityItem)
                }
            }

            ListItem {
                height: logviewerLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: logviewerLayout
                    title.text: i18n.tr("View Log")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    extraStack.push(Qt.resolvedUrl("LogViewer.qml"))
                }
            }

            Rectangle {
                id: profileSpecificSeparator
                height: profileSpecificSeparatorLabel.contentHeight + units.gu(4)
                width: parent.width
                Label {
                    id: profileSpecificSeparatorLabel
                    anchors {
                        top: profileSpecificSeparator.top
                        topMargin: units.gu(3)
                        horizontalCenter: profileSpecificSeparator.horizontalCenter
                    }
                    text: i18n.tr("Current Account")
                    //font.bold: true
                    fontSize: "large"
                }
                color: theme.palette.normal.background
            }

            Rectangle {
                id: prefAutocryptSectionHeader
                height: prefAutocryptSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefAutocryptSectionHeaderLabel
                    anchors {
                        top: prefAutocryptSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefAutocryptSectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    // TODO: string not translated
                    // TODO: maybe solve issue in a different way?
                    text: i18n.tr("Autocrypt")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: autocryptItem
                height: autocryptLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: autocryptLayout
                    title.text: i18n.tr("Prefer End-To-End Encryption")


                    Switch {
                        id: autocryptSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("e2ee_enabled") === "1")
                        onCheckedChanged: {
                            if (autocryptSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("e2ee_enabled") != "1") {
                                    DeltaHandler.setCurrentConfig("e2ee_enabled", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("e2ee_enabled") != "0") {
                                    DeltaHandler.setCurrentConfig("e2ee_enabled", "0")
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: prefImapFolderSectionHeader
                height: prefImapFolderSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: prefImapFolderSectionHeaderLabel
                    anchors {
                        top: prefImapFolderSectionHeader.top
                        topMargin: units.gu(3)
                        left: prefImapFolderSectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    text: i18n.tr("IMAP Folder Handling")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: sentFolderItem
                height: sentFolderLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: sentFolderLayout
                    title.text: i18n.tr("Watch Sent Folder")


                    Switch {
                        id: sentFolderSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("sentbox_watch") === "1")
                        onCheckedChanged: {
                            if (sentFolderSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("sentbox_watch") != "1") {
                                    DeltaHandler.setCurrentConfig("sentbox_watch", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("sentbox_watch") != "0") {
                                    DeltaHandler.setCurrentConfig("sentbox_watch", "0")
                                }
                            }
                        }
                    }
                }
            }

            ListItem {
                id: copyToSelfItem
                height: copyToSelfLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: copyToSelfLayout
                    title.text: i18n.tr("Send Copy to Self")
                    summary.text: i18n.tr("Required when using this account on multiple devices.")
                    summary.wrapMode: Text.WordWrap


                    Switch {
                        id: copyToSelfSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("bcc_self") === "1")
                        onCheckedChanged: {
                            if (copyToSelfSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("bcc_self") != "1") {
                                    DeltaHandler.setCurrentConfig("bcc_self", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("bcc_self") != "0") {
                                    DeltaHandler.setCurrentConfig("bcc_self", "0")
                                }
                            }
                        }
                    }
                }
            }

            ListItem {
                id: autoFolderMovesItem
                height: autoFolderMovesLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: autoFolderMovesLayout
                    title.text: i18n.tr("Move automatically to DeltaChat Folder")
                    summary.text: i18n.tr("Chat conversations are moved to avoid cluttering the Inbox")
                    summary.wrapMode: Text.WordWrap


                    Switch {
                        id: autoFolderMoveSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("mvbox_move") === "1")
                        onCheckedChanged: {
                            if (autoFolderMoveSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("mvbox_move") != "1") {
                                    DeltaHandler.setCurrentConfig("mvbox_move", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("mvbox_move") != "0") {
                                    DeltaHandler.setCurrentConfig("mvbox_move", "0")
                                }
                            }
                        }
                    }
                }
            }

            ListItem {
                id: onlyDCfolderItem
                height: onlyDCfolderLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: onlyDCfolderLayout
                    title.text: i18n.tr("Only Fetch from DeltaChat Folder")
                    summary.text: i18n.tr("Ignore other folders. Requires your server to move chat messages to the DeltaChat folder.")
                    summary.wrapMode: Text.WordWrap


                    Switch {
                        id: onlyDCfolderSwitch
                        SlotsLayout.position: SlotsLayout.Trailing
                        checked: (DeltaHandler.getCurrentConfig("only_fetch_mvbox") === "1")
                        onCheckedChanged: {
                            if (onlyDCfolderSwitch.checked) {
                                // need to check whether it is really needed to change the setting
                                // because checkedChanged may be emitted when setting the switch via
                                // DeltaHandler.getCurrentConfig()
                                if (DeltaHandler.getCurrentConfig("only_fetch_mvbox") != "1") {
                                    DeltaHandler.setCurrentConfig("only_fetch_mvbox", "1")
                                }
                            } else {
                                if (DeltaHandler.getCurrentConfig("only_fetch_mvbox") != "0") {
                                    DeltaHandler.setCurrentConfig("only_fetch_mvbox", "0")
                                }
                            }
                        }
                    }
                }
            }

            ListItem {
                height: proxyLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: proxyLayout
                    title.text: i18n.tr("Proxy")
                    title.font.bold: true

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    extraStack.push(Qt.resolvedUrl('Proxy.qml'))
                }
            }

            Rectangle {
                id: manageKeysSectionHeader
                height: manageKeysSectionHeaderLabel.contentHeight + units.gu(3)
                width: parent.width
                Label {
                    id: manageKeysSectionHeaderLabel
                    anchors {
                        top: manageKeysSectionHeader.top
                        topMargin: units.gu(3)
                        left: manageKeysSectionHeader.left
                        leftMargin: units.gu(2)
                    }
                    text: i18n.tr("Manage Keys")
                    font.bold: true
                }
                color: theme.palette.normal.background
            }

            ListItem {
                id: keysExportItem
                height: keysExportLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width
                divider.visible: false

                ListItemLayout {
                    id: keysExportLayout
                    title.text: i18n.tr("Export Secret Keys")

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(Qt.resolvedUrl("ProgressKeysExport.qml"))
                }
            }

            ListItem {
                id: keysImportItem
                height: keysImportLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: keysImportLayout
                    title.text: i18n.tr("Import Secret Keys")

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(Qt.resolvedUrl("ProgressKeysImport.qml"))
                }
            }
        }
    }

    Component {
        id: popoverComponentVoiceMessageQuality
        Popover {
            id: popoverVoiceMessageQuality
            Column {
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                }
                ListItem {
                    height: layout11.height
                    // should be automatically themed with something like
                    // theme.palette.normal.overlay, but this
                    // doesn't seem to work for Ambiance (and importing
                    // Lomiri.Components.Themes 1.3 doesn't solve it). 
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout11
                        title.text: i18n.tr("High")
                    }
                    onClicked: {
                        root.voiceMessageQuality = DeltaHandler.HighRecordingQuality
                        updateVoiceMessageQualityCurrentSetting()
                        PopupUtils.close(popoverVoiceMessageQuality)
                    }
                }

                ListItem {
                    height: layout21.height
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout21
                        title.text: i18n.tr("Balanced")
                    }
                    onClicked: {
                        root.voiceMessageQuality = DeltaHandler.BalancedRecordingQuality
                        updateVoiceMessageQualityCurrentSetting()
                        PopupUtils.close(popoverVoiceMessageQuality)
                    }
                }

                ListItem {
                    height: layout31.height
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout31
                        title.text: i18n.tr("Worse quality, small size")
                    }
                    onClicked: {
                        root.voiceMessageQuality = DeltaHandler.LowRecordingQuality
                        updateVoiceMessageQualityCurrentSetting()
                        PopupUtils.close(popoverVoiceMessageQuality)
                    }
                }
            }
        }
    }
}
