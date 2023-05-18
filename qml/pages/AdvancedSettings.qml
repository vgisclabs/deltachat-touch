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

        //trailingActionBar.numberOfSlots: 2
//        trailingActionBar.actions: [
//            Action {
//                iconName: 'help'
//                text: i18n.tr('Help')
//                onTriggered: {
//                    layout.addPageToCurrentColumn(advancedSettingsPage, Qt.resolvedUrl('Help.qml'))
//                }
//            },
//            Action {
//                iconName: 'info'
//                text: i18n.tr('About DeltaTouch')
//                onTriggered: {
//                            layout.addPageToCurrentColumn(advancedSettingsPage, Qt.resolvedUrl('About.qml'))
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

            ListItem {
                id: voiceMessageQualityItem
                height: voiceMessageQualityLayout.height + (divider.visible ? divider.height : 0)
                width: advancedSettingsPage.width

                ListItemLayout {
                    id: voiceMessageQualityLayout
                    title.text: i18n.tr("Voice Message Quality")

                    Label {
                        id: voiceMessageQualityLabel
                        width: advancedSettingsPage.width/4
                        text: voiceMessageQualityCurrentSetting
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
                    PopupUtils.open(popoverComponentVoiceMessageQuality, voiceMessageQualityItem)
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
                    // should be automatically be themed with something like
                    // theme.palette.normal.overlay, but this
                    // doesn't seem to work for Ambiance (and importing
                    // Ubuntu.Components.Themes 1.3 doesn't solve it). 
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
