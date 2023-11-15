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

    Row {
        spacing: units.gu(1)

        Label {
            // String not translated yet!
            text: i18n.tr("Show experimental settings")
            wrapMode: Text.Wrap
        }

        Switch {
            id: experimentalSettingsSwitch
            checked: experimentalEnabled
            enabled: !experimentalEnabled || !DeltaHandler.databaseIsEncryptedSetting()
        }
    }

    Button {
        id: okButton
        text: i18n.tr("OK")
        color: theme.palette.normal.positive
        onClicked: {
            console.log("setting root.showAccountsExperimentalSettings to ", experimentalSettingsSwitch.checked)
            root.showAccountsExperimentalSettings = experimentalSettingsSwitch.checked
            PopupUtils.close(dialog)
        }
    }
}
