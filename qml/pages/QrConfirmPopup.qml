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

    property string textOne
    property string titleString
    property bool showClipboardButton: false
    property bool showClickUrlButton: false
    property string clipboardContent

    signal confirmed()

    title: titleString

    Label {
        text: textOne
        wrapMode: Text.Wrap
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(dialog)
        }
    }

    Button {
        id: clipboardButton
        onClicked: {
            Clipboard.push(clipboardContent)
            confirmed()
        }
        text: i18n.tr("Copy to Clipboard")
        color: showClickUrlButton ? cancelButton.color : theme.palette.normal.positive
        visible: showClipboardButton
    }

    Button {
        id: clickUrlButton
        onClicked: {
            confirmed()
            Qt.openUrlExternally(clipboardContent)
        }
        // TODO: string not translated yet!
        text: i18n.tr("Open Url in Browser")
        color: theme.palette.normal.positive
        visible: showClickUrlButton
    }

    Button {
        color: theme.palette.normal.positive
        text: i18n.tr("OK")
        onClicked: {
            confirmed()
        }
        visible: !(showClipboardButton || showClickUrlButton)
    }
}
