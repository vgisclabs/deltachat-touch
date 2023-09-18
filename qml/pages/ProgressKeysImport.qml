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
import Lomiri.Components.Popups 1.3 as UITK
import Qt.labs.platform 1.1

import DeltaHandler 1.0

UITK.Dialog {
    id: dialog

    property string importdir
    ProgressBar {
        id: progBar
        minimumValue: 0
        maximumValue: 1000
        value: 0
        visible: false
    }

    Component.onCompleted: {
        importdir = StandardPaths.locate(StandardPaths.CacheLocation, "keys_to_import", StandardPaths.LocateDirectory)
        importdir = importdir.slice(7, importdir.length)
        dialog.text = i18n.tr("To import secret keys, please place them into the directory \"%1\". Make sure that no other files are present in this directory. The directory is only available if the app is running, and will be deleted upon closure of the app.").arg(dialog.importdir) + "\n\n" + i18n.tr("Import secret keys from \"%1\"?\n\n• Existing secret keys will not be deleted\n\n• The last imported key will be used as the new default key unless it has the word \"legacy\" in its filename.").arg(dialog.importdir)
    }

    function updateProgress(progValue) {
        progBar.value = progValue
        if (progValue == 0) {
            PopupUtils.close(dialog)
        }
        else if (progValue == 1000) {
            // TODO string not translated yet
            dialog.text = i18n.tr("Secret keys imported from \"%1\".").arg(dialog.importdir)
            progBar.visible = false
            okButton.visible = true
        }
    }

    Button {
        id: startImportButton
        text: i18n.tr("Import Secret Keys")
        color: theme.palette.normal.positive
        onClicked: {
            DeltaHandler.emitterthread.imexProgress.connect(updateProgress)
            startImportButton.visible = false
            cancelImportButton.visible = false
            dialog.text = ""
            progBar.visible = true
            DeltaHandler.importKeys()
        }
    }

    Button {
        id: cancelImportButton
        text: "Cancel"
        onClicked: {
            PopupUtils.close(dialog)
        }
    }

    Button {
        // This button will be shown if the import was successful
        id: okButton
        text: 'OK'
        color: theme.palette.normal.positive
        onClicked: {
            PopupUtils.close(dialog)
        }
        visible: false
    }
}
