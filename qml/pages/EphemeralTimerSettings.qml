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
import Lomiri.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: dialog
    title: i18n.tr("Disappearing Messages")

    property var currentTimer: DeltaHandler.getChatEphemeralTimer(-1)
    property var newTimer: DeltaHandler.getChatEphemeralTimer(-1)

    Component.onCompleted: {
        switch (currentTimer) {
            case 0:
                ephemeralCombo.text = i18n.tr("Off")
                break;

            case 30:
                ephemeralCombo.text = i18n.tr("After 30 seconds")
                break;

            case 60:
                ephemeralCombo.text = i18n.tr("After 1 minute")
                break;

            case 3600:
                ephemeralCombo.text = i18n.tr("After 1 hour")
                break;

            case 86400:
                ephemeralCombo.text = i18n.tr("After 1 day")
                break;

            case 608400:
                ephemeralCombo.text = i18n.tr("After 1 week")
                break;

            case 2419200:
                ephemeralCombo.text = i18n.tr("After 4 weeks")
                break;

            default:
                ephemeralCombo.text = i18n.tr("After %1 seconds").arg(currentTimer)
                break;

        }
    }

    ComboButton {
        id: ephemeralCombo
        text: "Test"
        onClicked: {
            PopupUtils.open(popoverComponentEphemeral, ephemeralCombo)

        }

    }

    Label {
        text: i18n.tr("Applies to all members of this chat if they use Delta Chat; they can still copy, save, and forward messages or use other e-mail clients.")
        wrapMode: Text.WordWrap
    }

    Button {
        text: 'Cancel'
        onClicked: {
            PopupUtils.close(dialog)
        }
    }

    Button {
        id: okButton
        text: 'OK'
        color: theme.palette.normal.focus
        onClicked: {
            if (currentTimer != newTimer) {
                DeltaHandler.setChatEphemeralTimer(-1, newTimer)
            }
            PopupUtils.close(dialog)
        }
    }

    Component {
        id: popoverComponentEphemeral
        Popover {
            id: popoverEphemeral

            Component.onCompleted: {
                ephemeralCombo.expanded = true
            }

            Component.onDestruction: {
                ephemeralCombo.expanded = false
            }

            Column {
                id: containerLayoutEphemeral
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                }
                ListItem {
                    height: layout91.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout91
                        title.text: i18n.tr("Off")
                    }
                    onClicked: {
                        newTimer = 0
                        ephemeralCombo.text = i18n.tr("Off")
                        PopupUtils.close(popoverEphemeral)
                    }
                }

                ListItem {
                    height: layout92.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout92
                        title.text: i18n.tr("After 30 seconds")
                    }
                    onClicked: {
                        newTimer = 30
                        ephemeralCombo.text = i18n.tr("After 30 seconds")
                        PopupUtils.close(popoverEphemeral)
                    }
                }

                ListItem {
                    height: layout93.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout93
                        title.text: i18n.tr("After 1 minute")
                    }
                    onClicked: {
                        newTimer = 60
                        ephemeralCombo.text = i18n.tr("After 1 minute")
                        PopupUtils.close(popoverEphemeral)
                    }
                }

                ListItem {
                    height: layout94.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout94
                        title.text: i18n.tr("After 1 hour")
                    }
                    onClicked: {
                        newTimer = 3600
                        ephemeralCombo.text = i18n.tr("After 1 hour")
                        PopupUtils.close(popoverEphemeral)
                    }
                }

                ListItem {
                    height: layout95.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout95
                        title.text: i18n.tr("After 1 day")
                    }
                    onClicked: {
                        newTimer = 86400
                        ephemeralCombo.text = i18n.tr("After 1 day")
                        PopupUtils.close(popoverEphemeral)
                    }
                }

                ListItem {
                    height: layout96.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout96
                        title.text: i18n.tr("After 1 week")
                    }
                    onClicked: {
                        newTimer = 608400
                        ephemeralCombo.text = i18n.tr("After 1 week")
                        PopupUtils.close(popoverEphemeral)
                    }
                }

                ListItem {
                    height: layout97.height
                    color: root.darkmode ? theme.palette.normal.background : "#e6e6e6" 
                    ListItemLayout {
                        id: layout97
                        title.text: i18n.tr("After 4 weeks")
                    }
                    onClicked: {
                        newTimer = 2419200
                        ephemeralCombo.text = i18n.tr("After 30 seconds")
                        PopupUtils.close(popoverEphemeral)
                    }
                }
            } // end Column id: containerLayoutEphemeral
        } // end Popover id: popoverEphemeral
    } // end Component id: popoverComponentEphemeral
}
