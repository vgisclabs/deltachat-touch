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

    signal listChatmailServer()
    signal classicMailLogin()
    signal scanInvitationCode()
    signal cancelled()


    title: i18n.tr("Use Other Server")

    Button {
        text: i18n.tr("List Chatmail Servers")
        iconSource: "../assets/external-link-white.svg"
        onClicked: listChatmailServer()
    }

    Button {
        text: i18n.tr("Classic E-Mail Login")
        onClicked: classicMailLogin()
    }

    Button {
        text: i18n.tr("Scan Invitation Code")
        onClicked: scanInvitationCode()
    }

    Button {
        text: i18n.tr("Cancel")
        onClicked: cancelled()
    }
}
