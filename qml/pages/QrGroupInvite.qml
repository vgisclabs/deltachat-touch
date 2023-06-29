/*
 * Copyright (C) 2022  Lothar Ketterer
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
import QtQuick.Layouts 1.3
//import Lomiri.Components.Popups 1.3
//import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
//import QtMultimedia 5.12
//import QtQml.Models 2.12

import DeltaHandler 1.0

Page {
    id: qrInvitePage

    Component.onDestruction: {
        
    }

    Component.onCompleted: {
    }

    header: PageHeader {
        id: qrHeader
        title: i18n.tr("QR Invite Code")

        //trailingActionBar.numberOfSlots: 2
       // trailingActionBar.actions: [
       //   //  Action {
       //   //      iconName: 'help'
       //   //      text: i18n.tr('Help')
       //   //      onTriggered: {
       //   //          layout.addPageToCurrentColumn(qrInvitePage, Qt.resolvedUrl('Help.qml'))
       //   //      }
       //   //  },
       //     Action {
       //         iconName: 'info'
       //         text: i18n.tr('About DeltaTouch')
       //         onTriggered: {
       //                     layout.addPageToCurrentColumn(qrInvitePage, Qt.resolvedUrl('About.qml'))
       //         }
       //     }
       // ]
    }

    Image {
        id: qrImage
        width: (parent.width < parent.height - qrHeader.height ? parent.width : parent.height - qrHeader.height) - units.gu(2)
        height: width
        anchors {
            top: header.bottom
            topMargin: units.gu(1)
            left: parent.left
            leftMargin: units.gu(1)
        }
        source: StandardPaths.locate(StandardPaths.CacheLocation, DeltaHandler.getTempGroupQrSvg())
        fillMode: Image.PreserveAspectFit
    }
}
