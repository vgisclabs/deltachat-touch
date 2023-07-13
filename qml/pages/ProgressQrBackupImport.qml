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

    signal failed()
    signal cancelled()

    // TODO: set title according to the step, possible values are:
    // Preparing account…
    // Waiting for receiver…
    // Receiver connected…
    // Transferring…
    // Currently, however, the documentation does not detail when
    // to switch strings, so it's set to this one
    title: i18n.tr("Transferring…")

    ProgressBar {
        id: progBar
        minimumValue: 0
        maximumValue: 1000
        value: 0
    }

    Component.onCompleted: {
        DeltaHandler.emitterthread.imexProgress.connect(updateProgress)
            DeltaHandler.startQrBackupImport()
    }

    function updateProgress(progValue) {
        progBar.value = progValue
        if (progValue == 0) {
            // TODO: better string available?
            dialog.title = i18n.tr("Error")
            progBar.visible = false
            backButton.visible = true
            cancelButton.visible = false
        }
        else if (progValue == 1000) {
            // TODO string not translated yet
            dialog.title = i18n.tr("Done")
            progBar.visible = false
            okButton.visible = true
            cancelButton.visible = false
        } else {
            cancelButton.visible = true
        }
    }

    Button {
        id: cancelButton
        text: "Cancel"
        color: theme.palette.normal.negative
        onClicked: {
            DeltaHandler.cancelQrImport()
            PopupUtils.close(dialog)
            cancelled()
        }
        visible: false
    }

    Button {
        id: okButton
        text: 'OK'
        color: theme.palette.normal.positive
        onClicked: {
            PopupUtils.close(dialog)
            layout.removePages(layout.primaryPage)
        }
        visible: false
    }

    Button {
        // Must only be visible in case the import failed because
        // we are emitting the failed signal when the button is clicked
        id: backButton
        text: i18n.tr("Back")
        color: theme.palette.normal.negative
        onClicked: {
            PopupUtils.close(dialog)
            failed()
        }
        visible: false
    }
}
