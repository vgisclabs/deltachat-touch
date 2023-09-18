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

    signal success()
    signal failed()

    Component.onCompleted: {
        DeltaHandler.prepareDbConversionToEncrypted()
        DeltaHandler.workflowdbencryption.imexEvent.connect(updateProgress)
        DeltaHandler.workflowdbencryption.statusChanged.connect(updateInfoLabel)
        DeltaHandler.workflowdbencryption.workflowCompleted.connect(conversionFinished)
        DeltaHandler.workflowdbencryption.workflowError.connect(conversionError)
        DeltaHandler.workflowdbencryption.startWorkflow()
    }

    function updateProgress(progValue) {
        progBar.value = progValue
        if (progValue == 0) {
            // TODO string not translated yet
            dialog.text = i18n.tr("Conversion failed, check log for details")
            progBar.visible = false
            okButton.visible = false
            backButton.visible = true
        }
    }

    function updateInfoLabel(exporting, currentAcc, totalAccs) {
        // string not translated yet
        if (exporting) {
            dialog.text = i18n.tr("Extracting data of account %1 of %2").arg(currentAcc).arg(totalAccs)
        } else {
            dialog.text = i18n.tr("Encrypting account %1 of %2").arg(currentAcc).arg(totalAccs)
        }
    }

    function conversionFinished() {
        progBar.visible = false
        dialog.text = i18n.tr("Conversion successful!")
        okButton.visible = true
    }

    function conversionError() {
        // TODO string not translated yet
        dialog.text = i18n.tr("Conversion failed, check log for details")
        progBar.visible = false
        okButton.visible = false
        backButton.visible = true
    }

    ProgressBar {
        id: progBar
        minimumValue: 0
        maximumValue: 1000
        value: 0
    }

    Button {
        id: okButton
        text: 'OK'
        color: theme.palette.normal.positive
        onClicked: {
            PopupUtils.close(dialog)
            success()
        }
        visible: false
    }

    Button {
        id: backButton
        text: i18n.tr("Back")
        color: theme.palette.normal.negative
        onClicked: {
            failed()
            PopupUtils.close(dialog)
        }
        visible: false
    }
}
