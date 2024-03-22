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
    id: confirmDialog

    signal confirmed()
    signal cancelled()

    property string dialogTitle
    property string dialogText
    property string okButtonText: i18n.tr("OK")
    property string cancelButtonText: i18n.tr("Cancel")

    title: dialogTitle

    text: dialogText

    Button {
        id: okButton
        text: okButtonText
        color: theme.palette.normal.negative
        onClicked: {
            PopupUtils.close(confirmDialog)
            confirmed()
        }
    }

    Button {
        id: cancelButton
        text: cancelButtonText
        onClicked: {
            PopupUtils.close(confirmDialog)
            cancelled()
        }
    }
}
