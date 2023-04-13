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
import Ubuntu.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: dialog

    property string showMailsSetting

    property var updateTest

    title: i18n.tr("Show Classic E-Mails")

    ListItem {
        height: itemLayout0.height + (divider.visible ? divider.height : 0)
        width: dialog.width
        divider.visible: false

        ListItemLayout {
            id: itemLayout0
            title.text: i18n.tr("No, chats only")

            Icon {
                name: "tick"
                SlotsLayout.position: SlotsLayout.Trailing;
                width: units.gu(2)
                opacity: showMailsSetting == "0" ? 1 : 0
            }
        }

        onClicked: {
            showMailsSetting = "0"
        }
    }

    ListItem {
        height: itemLayout1.height + (divider.visible ? divider.height : 0)
        width: dialog.width
        divider.visible: false

        ListItemLayout {
            id: itemLayout1
            title.text: i18n.tr("For accepted contacts")

            Icon {
                name: "tick"
                SlotsLayout.position: SlotsLayout.Trailing;
                width: units.gu(2)
                opacity: showMailsSetting == "1" ? 1 : 0
            }
        }

        onClicked: {
            showMailsSetting = "1"
        }
    }

    ListItem {
        height: itemLayout2.height + (divider.visible ? divider.height : 0)
        width: dialog.width
        divider.visible: false

        ListItemLayout {
            id: itemLayout2
            title.text: i18n.tr("All")

            Icon {
                name: "tick"
                SlotsLayout.position: SlotsLayout.Trailing;
                width: units.gu(2)
                opacity: showMailsSetting == "2" ? 1 : 0
            }
        }

        onClicked: {
            showMailsSetting = "2"
        }
    }

    Button {
        text: 'OK'
        color: theme.palette.normal.positive
        onClicked: {
            DeltaHandler.setCurrentConfig("show_emails", showMailsSetting)
            PopupUtils.close(dialog)
            updateTest()
        }
    }

    Button {
        text: 'Cancel'
        onClicked: {
            PopupUtils.close(dialog)
        }
    }
}
