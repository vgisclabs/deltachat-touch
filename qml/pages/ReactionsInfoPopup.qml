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
import Ubuntu.Components 1.3
import Qt.labs.platform 1.1
import Ubuntu.Components.Popups 1.3

import DeltaHandler 1.0

import "/jsonrpc.mjs" as JSONRPC

Dialog {
    id: dialog

    title: i18n.tr("Reactions")

    // contains the reactions JSON object, looking for example like this:
    // {"reactions":[{"count":2,"emoji":"👍","isFromSelf":true}],"reactionsByContact":{"1":["👍"],"19":["👍"]}}
    property var reactions

    function getInitial(name) {
        if (name == "") {
            return "#";
        } else {
            return name.charAt(0).toUpperCase();
        }
    }

    function setAvatar(path) {
       if (path != null) {
           let lengthToSubtract = ("" + StandardPaths.writableLocation(StandardPaths.AppConfigLocation)).length - 6
           let temp = path.substring(lengthToSubtract)
           return StandardPaths.locate(StandardPaths.AppConfigLocation, temp)
       } else {
           return ""
       }
    }

    function getEmojiString(emojiArray) {
        let tempstring = ""
        for (let i = 0; i < emojiArray.length; i++) {
            tempstring += emojiArray[i]
        }
        return tempstring
    }

    function addModelEntry(emojiArray, contact) {
        let contactName = contact.displayName
        let contactAddress = contact.address
        let contactAvatar = Qt.resolvedUrl(setAvatar(contact.profileImage))
        let contactInitial = getInitial(contactName)
        let contactColor = contact.color
        reactionsInfoModel.append( {
            displayname: contactName,
            address: contactAddress,
            avatarPath: contactAvatar,
            avatarInitial: contactInitial,
            contactColor: contactColor,
            emoji: getEmojiString(emojiArray)
        })
    }

    Component.onCompleted: {
        if (reactions.hasOwnProperty("reactionsByContact")) {
            let reactByCont = reactions.reactionsByContact
            
            // "key" is the contactID
            for (var key in reactByCont) {
                let emojiarr = reactByCont[key]
                // with this, although the above console.log will give separate 
                // keys per loop iteration, the call to addModelEntry will always
                // be with the same contact TODO: Why?
                //JSONRPC.client.getSelectedAccountId().then(accountId => // TODO get the selected account Id from somewhere else and cache it in a var
                //    JSONRPC.client.getContact(accountId, Number(key)).then(contact => (addModelEntry(emojiarr, contact))
                //    )
                //)
                let requestString = DeltaHandler.constructJsonrpcRequestString("get_contact", "" + DeltaHandler.getCurrentAccountId() + ", " + key)
                let jsonresponse = JSON.parse(DeltaHandler.sendJsonrpcBlockingCall(requestString))
                addModelEntry(emojiarr, jsonresponse.result)
            }
        }
    }

    ListModel {
        id: reactionsInfoModel
    }

    
    Component {
        id: reactionsDelegate

        ListItem {
            // shall specify the height when Using ListItemLayout inside ListItem
            height: layout.height + (divider.visible ? divider.height : 0)
            divider.visible: false

            ListItemLayout {
                id: layout
                title.text: model.displayname
                //title.font.bold: true
                title.font.pixelSize: root.scaledFontSizeInPixels
                subtitle.text: model.address
                subtitle.font.pixelSize: scaledFontSizeInPixelsSmaller
                subtitle.wrapMode: Text.Wrap

                // need to explicitly set the height because otherwise,
                // the height will increase when switching
                // scaledFontSize from "medium" to "small" (why??)
                height: avatarShape.height + units.gu(1) + units.gu(scaleLevel * 0.25)

                Label {
                    SlotsLayout.position: SlotsLayout.Trailing
                    text: model.emoji
                    fontSize: "x-large"
                }

                UbuntuShape {
                    id: avatarShape
                    SlotsLayout.position: SlotsLayout.Leading
                    height: units.gu(4) + units.gu(scaleLevel)
                    width: height
                    
                    source: model.avatarPath !== "" ? avatarImage : undefined 
                    Image {
                        id: avatarImage
                        visible: false
                        source: model.avatarPath
                    }

                    Label {
                        id: avatarInitialLabel
                        visible: model.avatarPath === ""
                        text: model.avatarInitial
                        fontSize: "x-large"
                        color: "white"
                        anchors.centerIn: parent
                    }

                    backgroundColor: model.contactColor

                    sourceFillMode: UbuntuShape.PreserveAspectCrop
                }
            } // end ListItemLayout id: layout
        } // end ListItem
    } // end Compoment id: reactionsDelegate

    ListView {
        id: reactionsView
        width: dialog.width
        height: childrenRect.height

        model: reactionsInfoModel

        delegate: reactionsDelegate
    } // ListView id: reactionsView

    Button {
        text: i18n.tr("OK")
        onClicked: PopupUtils.close(dialog)
        color: theme.palette.normal.positive
    }
}
