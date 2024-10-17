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
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: dialog

    property string sourceUrl: ""

    Component.onCompleted: {
    }

    Button {
        id: sourceLinkButton
        text: i18n.tr("Source Code")

        onClicked: {
            let popup1 = PopupUtils.open(
                Qt.resolvedUrl('ConfirmOpenExternalUrl.qml'),
                dialog,
                { "externalLink": sourceUrl,
                  "openButtonPositive": true }
            )
            popup1.done.connect(function() { PopupUtils.close(dialog) })
        }

        enabled: sourceUrl !== ""
    }

    Button {
        text: 'OK'
        color: theme.palette.normal.focus
        onClicked: {
            PopupUtils.close(dialog)
        }
    }
}
