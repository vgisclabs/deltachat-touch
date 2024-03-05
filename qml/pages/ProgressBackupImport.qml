/*
 * Copyright (C) 2023, 2024  Lothar Ketterer
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
    }

    property string backupSource

    Component.onCompleted: {
        DeltaHandler.imexEventReceived.connect(updateProgress)
        DeltaHandler.importBackupFromFile(backupSource)
    }

    function updateProgress(progValue) {
        progBar.value = progValue
        if (progValue == 0) {
            // TODO string not translated yet
            dialog.text = i18n.tr('Failed')
            progBar.visible = false
            backButton.visible = true
        }
        else if (progValue == 1000) {
            // TODO string not translated yet
            dialog.text = "Success!\nAfter clicking Ok, it may take a while, please be patient."
            progBar.visible = false
            okButton.visible = true
        }
    }

    Button {
        id: okButton
        text: 'OK'
        color: theme.palette.normal.positive
        onClicked: {
            dialog.text = "Updating…"
            PopupUtils.close(dialog)
            layout.removePages(layout.primaryPage)
        }
        visible: false
    }

    Button {
        id: backButton
        text: i18n.tr("Back")
        color: theme.palette.normal.negative
        onClicked: {
            PopupUtils.close(dialog)
        }
        visible: false
    }
}
