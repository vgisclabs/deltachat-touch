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
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: dialog

    property bool experimentalEnabled
    property bool showContactRequests

    // in case the page opening the popup doesn't want the popup
    // to ask for the showContactRequests setting
    property bool showExperimentalSettingOnly: false

    Rectangle {
        width: dialog.contentWidth
        height: experimentalSettingsLabel.contentHeight + units.gu(1)

        color: theme.palette.normal.background

        Label {
            id: experimentalSettingsLabel
            width: parent.width - experimentalSettingsSwitch.width - units.gu(1)
            anchors.left: parent.left
            // String not translated yet!
            text: i18n.tr("Experimental Features")
            wrapMode: Text.Wrap
        }

        Switch {
            id: experimentalSettingsSwitch
            anchors.right: parent.right
            checked: experimentalEnabled
            enabled: !experimentalEnabled || !DeltaHandler.databaseIsEncryptedSetting()
        }
    }

    Rectangle {
        width: dialog.width
        height: contactReqLabel.contentHeight + units.gu(1)

        color: theme.palette.normal.background

        Label {
            id: contactReqLabel
            width: parent.width - contactRequestsSwitch.width - units.gu(1)
            anchors.left: parent.left
            // String not translated yet!
            text: i18n.tr("Include contact requests in counters and notifications")
            wrapMode: Text.Wrap
        }

        Switch {
            id: contactRequestsSwitch
            anchors.right: parent.right
            checked: showContactRequests
        }

        visible: !showExperimentalSettingOnly
    }

    Button {
        id: okButton
        text: i18n.tr("OK")
        color: theme.palette.normal.positive
        onClicked: {
            root.showAccountsExperimentalSettings = experimentalSettingsSwitch.checked
            
            if (!showExperimentalSettingOnly) {
                root.notifyContactRequests = contactRequestsSwitch.checked
                DeltaHandler.notificationHelper.setNotifyContactRequests(contactRequestsSwitch.checked)
                root.refreshOtherAccsIndicator()
            }
            
            PopupUtils.close(dialog)
        }
    }
}
