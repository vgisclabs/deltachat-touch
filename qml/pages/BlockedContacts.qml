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
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
//import Qt.labs.settings 1.0
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: blockedContactsPage
    anchors.fill: parent
    header: PageHeader {
        id: header
        title: i18n.tr('Blocked Contacts')
    }

    Label {
        id: infoOnZeroBlockedContacts
        width: blockedContactsPage.width - units.gu(6)
        anchors {
            top: header.bottom
            topMargin: units.gu(4)
            horizontalCenter: blockedContactsPage.horizontalCenter
        }

        text: i18n.tr("Blocked contacts will appear here.")
        wrapMode: Text.Wrap
        visible: DeltaHandler.blockedcontactsmodel.blockedContactsCount == 0
    }

    Component {
        id: blockedContactsDelegate

        ListItem {
            id: blockedContactsItem
            height: blockedContactsListItemLayout.height + (divider.visible ? divider.height : 0)
            divider.visible: true

            onClicked: {
                PopupUtils.open(
                    Qt.resolvedUrl("UnblockContactPopup.qml"),
                    null,
                    { indexToUnblock: index }
                )
            }

            ListItemLayout {
                id: blockedContactsListItemLayout
                title.text: model.displayname == '' ? i18n.tr('Unknown') : model.displayname
                subtitle.text: model.address

                UbuntuShape {
                    id: profPicShape
                    height: units.gu(5)
                    width: height
                    SlotsLayout.position: SlotsLayout.Leading
                    source: model.profilePic == "" ? undefined : profPic
                    Image {
                        id: profPic
                        source: StandardPaths.locate(StandardPaths.AppConfigLocation, model.profilePic)
                        visible: false
                    }
                    Label {
                        id: avatarInitialLabel
                        text: model.avatarInitial
                        fontSize: "x-large"
                        color: "white"
                        visible: model.profilePic == ""
                        anchors.centerIn: parent
                    }
                    color: model.avatarColor
                    sourceFillMode: UbuntuShape.PreserveAspectCrop
                    aspect: UbuntuShape.Flat
                } // end of UbuntuShape id: profPicShape
            } // ListItemLayout id: blockedContactsListItemLayout
        } // ListItem blockedContactsItem
    } // Component blockedContactsDelegate

    ListView {
        id: view
        clip: true 
        //height: accountConfigPage.height - header.height
        width: blockedContactsPage.width
        anchors {
            top: header.bottom
            topMargin: units.gu(1)
            bottom: blockedContactsPage.bottom
        }
        model: DeltaHandler.blockedcontactsmodel
        delegate: blockedContactsDelegate
//        spacing: units.gu(1)
    }
} // end Page id: blockedContactsPage
