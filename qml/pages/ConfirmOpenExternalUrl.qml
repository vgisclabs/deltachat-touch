/*
 * Copyright (C) 2023, 2024 Lothar Ketterer
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

    property string externalLink

    title: i18n.tr("Do you want to open this link?")
    text: externalLink

    Button {
        id: okButton
        text: i18n.tr("Open")
        color: theme.palette.normal.negative
        onClicked: {
            Qt.openUrlExternally(externalLink)
            PopupUtils.close(dialog)
        }
    }

    Button {
        id: copyButton
        text: i18n.tr("Copy Link")
        onClicked: {
            let tempcontent = Clipboard.newData()
            tempcontent = externalLink
            Clipboard.push(tempcontent)
            PopupUtils.close(dialog)
        }
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: PopupUtils.close(dialog)
    }
}
