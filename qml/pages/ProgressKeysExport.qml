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

    property string exportdir
    
    ProgressBar {
        id: progBar
        minimumValue: 0
        maximumValue: 1000
        value: 0
        visible: false
    }

    Component.onCompleted: {
        exportdir = DeltaHandler.prepareExportKeys()
        dialog.text = i18n.tr("Export secret keys to \"%1\"?").arg(exportdir)
    }

    function updateProgress(progValue) {
        progBar.value = progValue
        if (progValue == 0) {
            PopupUtils.close(dialog)
        }
        else if (progValue == 1000) {
            dialog.text = i18n.tr("Secret keys written successfully to \"%1\".").arg(exportdir)
            progBar.visible = false
            okButton.visible = true
        }
    }

    Button {
        id: startExportButton
        text: i18n.tr("Yes")
        color: theme.palette.normal.positive
        onClicked: {
            DeltaHandler.emitterthread.imexProgress.connect(updateProgress)
            startExportButton.visible = false
            cancelExportButton.visible = false
            progBar.visible = true
            DeltaHandler.startExportKeys(exportdir)
        }
    }

    Button {
        id: cancelExportButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(dialog)
        }
    }

    Button {
        id: okButton
        text: i18n.tr("OK")
        color: theme.palette.normal.positive
        onClicked: {
            PopupUtils.close(dialog)
        }
        visible: false
    }
}
