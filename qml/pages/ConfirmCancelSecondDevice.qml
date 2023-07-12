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

Dialog {
    id: dialog

    signal confirmed()

    title: i18n.tr("Abort setting up second device?")

    Button {
        text: i18n.tr("Yes")
        color: theme.palette.normal.negative
        onClicked: {
            PopupUtils.close(dialog)
            confirmed()
        }
    }

    Button {
        text: i18n.tr("No")
        onClicked: {
            PopupUtils.close(dialog)
        }
    }
}
