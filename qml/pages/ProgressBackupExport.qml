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

    ProgressBar {
        id: progBar
        minimumValue: 0
        maximumValue: 1000
        value: 0
    }

    Component.onCompleted: {
        DeltaHandler.imexEventReceived.connect(updateProgress)
        DeltaHandler.exportBackup()
    }

    function updateProgress(progValue) {
        progBar.value = progValue
        if (progValue == 0) {
            dialog.text = i18n.tr('Failed')
            progBar.visible = false
            backButton.visible = true
        }
        else if (progValue == 1000) {
            dialog.text = i18n.tr("A backup helps you to set up a new installation on this or on another device.\n\nThe backup will contain all messages, contacts and chats and your end-to-end Autocrypt setup. Keep the backup file in a safe place or delete it as soon as possible.")
            progBar.visible = false
            okButton.visible = true
        }
    }

    Button {
        id: okButton
        text: 'OK'
        color: theme.palette.normal.positive
        onClicked: {
            PopupUtils.close(dialog)
        }
        visible: false
    }

    // TODO: is this needed? maybe a
    // cancel button that actually cancels the
    // imex process would be helpful?
    Button {
        id: backButton
        text: 'Back'
        color: theme.palette.normal.negative
        onClicked: {
            PopupUtils.close(dialog)
        }
        visible: false
    }
}
