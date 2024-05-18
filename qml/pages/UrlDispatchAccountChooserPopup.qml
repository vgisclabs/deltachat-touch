/*
 * Copyright (C) 2024  Lothar Ketterer
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
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

import DeltaHandler 1.0

Dialog {
    id: dialog

    signal selected()
    signal cancelled()

    property string dialogText

    // TODO: string not translated yet
    title: i18n.tr("Select Account")

    text: dialogText

    ListView {
        id: dialogListView
        clip: true
        width: dialog.width
        height: childrenRect.height > units.gu(20) ? units.gu(20) : childrenRect.height
        model: DeltaHandler.accountsmodel
        delegate: dialogDelegate
    }

    Component {
        id: dialogDelegate

        ListItem {
            id: accountsItem
            height: delegListItemLayout.height + (divider.visible ? divider.height : 0)
            divider.visible: true

            property bool isConfigured: model.isConfigured

            onClicked: {
                if (isConfigured) {
                    dialog.selected()
                    PopupUtils.close(dialog)
                    let accID = DeltaHandler.accountsmodel.getIdOfAccount(index)
                    DeltaHandler.selectAccount(accID, true)
                }
                else {
                    // cannot choose unconfigured account
                    console.log("UrlDispatchAccountChooserPopup.qml: Trying to select unconfigured account, refusing")
                }
            }

            ListItemLayout {
                id: delegListItemLayout
                title.text: model.username == '' ? '[' + i18n.tr('no username set') + ']' : model.username
                subtitle.text: model.address

                LomiriShape {
                    id: profPicShape
                    height: units.gu(5)
                    width: height
                    SlotsLayout.position: SlotsLayout.Leading
                    color: model.color

                    source: (model.profilePic !== "" || !(isConfigured)) ? profPic : undefined
                    
                    Image {
                        id: profPic
                        anchors.fill: parent
                        source: model.profilePic == "" ? Qt.resolvedUrl('../../assets/image-icon3.svg') : StandardPaths.locate(StandardPaths.AppConfigLocation, model.profilePic)
                        visible: false
                    }

                    Label {
                        id: profInitialLabel
                        visible: !(model.profilePic !== "" || !(isConfigured))
                        text: model.username === "" ? "#" : model.username.charAt(0).toUpperCase()
                        font.pixelSize: parent.height * 0.6
                        color: "white"
                        anchors.centerIn: parent
                    }

                    sourceFillMode: LomiriShape.PreserveAspectCrop
                    aspect: LomiriShape.Flat
                } // end of LomiriShape id:profilePicShape
            } // ListItemLayout id: delegListItemLayout
        } // ListItem accountsItem
    } // end Compoment id: dialogDelegate

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            PopupUtils.close(dialog)
            cancelled()
        }
    }
}
