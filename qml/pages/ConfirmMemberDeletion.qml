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
    id: confirmMemberDel

    property int memberVectorIndex
    property string memberName

    Component.onCompleted: {
        memberName = DeltaHandler.groupmembermodel.getNameOfIndex(memberVectorIndex)
    }

    title: i18n.tr("Delete")

    Label {
        id: confirmLabel1
        text: i18n.tr("Remove %1 from group?").arg(memberName)
        wrapMode: Text.Wrap
    }

    Button {
        id: okButton
        text: i18n.tr("Delete")
        color: theme.palette.normal.negative
        onClicked: {
            DeltaHandler.groupmembermodel.deleteMember(memberVectorIndex)
            PopupUtils.close(confirmMemberDel)
        }
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(confirmMemberDel)
        }
    }
}
