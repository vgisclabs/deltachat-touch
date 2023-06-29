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

    ProgressBar {
        id: progBar
        minimumValue: 0
        maximumValue: 1000
        value: 0
        visible: false
    }

    text: i18n.tr("A backup helps you to set up a new installation on this or on another device.\n\nThe backup will contain all messages, contacts and chats and your end-to-end Autocrypt setup. Keep the backup file in a safe place or delete it as soon as possible.")

    function updateProgress(progValue) {
        progBar.value = progValue
        if (progValue == 0) {
            PopupUtils.close(dialog)
        }
        else if (progValue == 1000) {
            PopupUtils.close(dialog)
        }
    }

    Button {
        id: okButton
        text: i18n.tr("Start Backup")
        color: theme.palette.normal.positive
        onClicked: {
            dialog.text = ""
            progBar.visible = true
            DeltaHandler.imexEventReceived.connect(updateProgress)
            DeltaHandler.exportBackup()
            okButton.visible = false
            backButton.visible = false
        }
    }

    Button {
        id: backButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(dialog)
        }
    }
}
