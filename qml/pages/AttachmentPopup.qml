/*
 * Copyright (C) 2024 Lothar Ketterer
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
import Lomiri.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: dialog

    signal addVoiceMessage()
    signal addFile()
    signal addAudio()
    signal addImage()
    signal addContact()
    signal cancel()

    title: i18n.tr("Add Attachment")

    Button {
        text: i18n.tr("Voice Message")
        iconSource: "qrc:///assets/audio-input-microphone-symbolic-white.svg"
        onClicked: {
            PopupUtils.close(dialog)
            addVoiceMessage()
        }
    }

    Button {
        text: i18n.tr("File")
        iconSource: "qrc:///assets/attachment-white.svg"
        onClicked: {
            PopupUtils.close(dialog)
            addFile()
        }
    }

    Button {
        text: i18n.tr("Audio")
        iconSource: "qrc:///assets/stock_music-white.svg"
        onClicked: {
            PopupUtils.close(dialog)
            addAudio()
        }
    }

    Button {
        text: i18n.tr("Image")
        iconSource: "qrc:///assets/stock_image-white.svg"
        onClicked: {
            PopupUtils.close(dialog)
            addImage()
        }
    }

    Button {
        text: i18n.tr("Cancel")
        color: theme.palette.normal.focus
        onClicked: {
            PopupUtils.close(dialog)
            cancel()
        }
    }
}
