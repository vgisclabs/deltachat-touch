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

import QtQuick 2.7
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: dialog

    property bool experimentalEnabled
    property bool showContactRequests

    Rectangle {
        width: dialog.width
        height: experimentalSettingsLabel.contentHeight + units.gu(1)

        color: theme.palette.normal.background

        Label {
            id: experimentalSettingsLabel
            width: dialog.width - experimentalSettingsSwitch.width - units.gu(1)
            // String not translated yet!
            text: i18n.tr("Show experimental settings")
            wrapMode: Text.WordWrap
        }

        Switch {
            id: experimentalSettingsSwitch
            anchors.right: parent.right
            checked: experimentalEnabled
            enabled: !experimentalEnabled || !DeltaHandler.databaseIsEncryptedSetting()
        }
    }

    Item {
        // spacer item
        width: units.gu(1)
        height: units.gu(1)
    }

    Rectangle {
        width: dialog.width
        height: contactReqLabel.contentHeight + units.gu(1)

        color: theme.palette.normal.background

        Label {
            id: contactReqLabel
            width: dialog.width - contactRequestsSwitch.width - units.gu(1)
            // String not translated yet!
            text: i18n.tr("Show contact requests")
            wrapMode: Text.WordWrap
        }

        Switch {
            id: contactRequestsSwitch
            anchors.right: parent.right
            checked: showContactRequests
        }
    }

    Button {
        id: okButton
        text: i18n.tr("OK")
        color: theme.palette.normal.positive
        onClicked: {
            root.showAccountsExperimentalSettings = experimentalSettingsSwitch.checked
            root.accountConfigPageShowContactRequests = contactRequestsSwitch.checked
            PopupUtils.close(dialog)
        }
    }
}
