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
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1
import QtMultimedia 5.12

import DeltaHandler 1.0
import "/emojis.js" as DtEmojis

Popover {
    id: popoverReactions
    width: chatViewPage.width * 0.9

    // will become true if the user has changed anything
    property bool needToSend: false

    property var reactions
    property var emoRecentArray: root.emojiRecentArray
    property var emoFaceArray: DtEmojis.emojiFaces
    property var emoHandArray: DtEmojis.emojiHands
    property var emoHeartArray: DtEmojis.emojiHearts
    property var emoAnimalArray: DtEmojis.emojiAnimals
    property var emoThingsArray: DtEmojis.emojiThings

    property var emoAllArrays: [emoRecentArray, emoFaceArray, emoHandArray, emoHeartArray, emoAnimalArray, emoThingsArray]

    signal sendReactions(var reactionArray)

    ListModel {
        id: emojiSelectorModel
    }

    ListModel {
        id: chosenReactionsModel
    }

    ListModel {
        id: tabsModel

        ListElement {
            sectionHeader: "⏱"
        }

        ListElement {
            sectionHeader: "☺"
        }

        ListElement {
            sectionHeader: "👍"
        }

        ListElement {
            sectionHeader: "❤"
        }

        ListElement {
            sectionHeader: "🐶"
        }

        ListElement {
            sectionHeader: "🏆"
        }
    }

    function setEmojiSelectorModel(tempIndex) {
        emojiSelectorModel.clear()
        
        for (let i = 0; i < emoAllArrays[tempIndex].length; i++) {
            emojiSelectorModel.append( { emoji: emoAllArrays[tempIndex][i] })
        }
    }

    Component.onCompleted: {
        for (let i = 0; i < emoRecentArray.length; i++) {
            emojiSelectorModel.append( { emoji: emoRecentArray[i] })
        }

        if (reactions.hasOwnProperty("reactions")) {
            let temparray = reactions.reactions
            for (let i = 0; i < temparray.length; i++) {
                let obj = temparray[i]
                if (obj.isFromSelf) {
                    chosenReactionsModel.append( { chosenEmo: obj.emoji })
                }
            }
        }

    }

    UbuntuShape {
        id: popoverBackgroundRect
        width: parent.width
        height: chosenRow.height + separatorItem.height +  tabView.height + chooseReactionsView.height + buttonRect.height + units.gu(5)
        backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6"

        Row {
            id: chosenRow

            anchors {
                top: parent.top
                topMargin: units.gu(1)
                left: parent.left
                leftMargin: units.gu(1)
            }

            Label {
                id: chosenDescLabel
                anchors.verticalCenter: parent.verticalCenter

                text: i18n.tr("Chosen Emojis: ")
                fontSize: "large"
            }

            ListView {
                id: chosenReactionsView
                height: FontUtils.sizeToPixels("x-large") + units.gu(2)
                width: popoverReactions.width - chosenDescLabel.width - units.gu(2)

                model: chosenReactionsModel
                orientation: ListView.Horizontal

                delegate: UbuntuShape {
                    id: chosenReactionsDelegate
                    height: chosenReactionsLabel.contentHeight + units.gu(1)
                    width: chosenReactionsLabel.contentWidth + units.gu(1)
                    backgroundColor: root.darkmode ? "#505050" : "white"
                    backgroundMode: UbuntuShape.SolidColor
                    aspect: UbuntuShape.DropShadow
                    radius: "large"

                    Label {
                        id: chosenReactionsLabel
                        text: model.chosenEmo
                        fontSize: "x-large"
                        color: root.darkmode ? "white" : "black"
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: { 
                            popoverReactions.needToSend = true
                            chosenReactionsModel.remove(index)
                        }
                    }
                }
            } // ListView id: chosenReactionsView
        }

        ListItem {
            id: separatorItem
            height: divider.height

            anchors.top: chosenRow.bottom

            divider.visible: true
        }

        ListView {
            id: tabView
            height: FontUtils.sizeToPixels("x-large") + units.gu(2)
            width: parent.width - units.gu(4)

            anchors {
                top: separatorItem.bottom
                topMargin: units.gu(1)
                left: parent.left
                leftMargin: units.gu(2)

            }

            property var activeTabIndex: 0

            model: tabsModel
            orientation: ListView.Horizontal
            spacing: units.gu(2)

            delegate: UbuntuShape {
                id: tabsDelegate
                height: tabLabel.contentHeight + units.gu(1)
                width: tabLabel.contentWidth + units.gu(3)
                backgroundColor: index == tabView.activeTabIndex ? (root.darkmode ? theme.palette.normal.overlay : "#e6e6e6") : (root.darkmode ? "black" : "white")
                backgroundMode: UbuntuShape.SolidColor
                aspect: UbuntuShape.Flat
                radius: "large"

                Rectangle {
                    width: parent.width * 0.2
                    height: width
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                    }
                    color: parent.backgroundColor
                }

                Rectangle {
                    width: parent.width * 0.2
                    height: width
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                    }
                    color: parent.backgroundColor
                }

                Label {
                    id: tabLabel
                    text: model.sectionHeader
                    fontSize: "x-large"
                    color: root.darkmode ? "white" : "black"
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: { 
                        tabView.activeTabIndex = index
                        setEmojiSelectorModel(index)
                    }
                }
            }
        } // ListView id: tabView

        GridView {
            id: chooseReactionsView
            height: chatViewPage.height * 0.75 - chosenReactionsView.height - units.gu(1)
            width: parent.width
            clip: true

            anchors {
                top: tabView.bottom
                topMargin: units.gu(1)
            }

            cellWidth: FontUtils.sizeToPixels("x-large") + units.gu(2)
            cellHeight: FontUtils.sizeToPixels("x-large") + units.gu(2)

            model: emojiSelectorModel
            delegate: UbuntuShape {
                width: chooseReactionsLabel1.contentWidth + units.gu(1)
                height: chooseReactionsLabel1.contentHeight + units.gu(1)

                backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                aspect: UbuntuShape.Flat

                Label {
                    id: chooseReactionsLabel1
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }
                    // thumbs up, U+1F44D
                    text: model.emoji
                    fontSize: "x-large"
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (chosenReactionsModel.count === 0) {
                            popoverReactions.needToSend = true
                            chosenReactionsModel.append( { chosenEmo: model.emoji })
                        } else {
                            // This is an implementation which only allows one reaction
                            // per user. To allow multiple reactions, remove this and
                            // use the previous implementation below.
                            if (chosenReactionsModel.get(0).chosenEmo !== model.emoji) {
                                popoverReactions.needToSend = true
                                chosenReactionsModel.remove(0)
                                chosenReactionsModel.append( { chosenEmo: model.emoji })
                            }

                            // This is the previous implementation which allows for multiple
                            // reactions.
                            //let found = false
                            //for (let i = 0; i < chosenReactionsModel.count; i++) {
                            //    if (chosenReactionsModel.get(i).chosenEmo === model.emoji) {
                            //        found = true
                            //    }
                            //}
                            //if (found === false) {
                            //    popoverReactions.needToSend = true
                            //    chosenReactionsModel.append( { chosenEmo: model.emoji })
                            //}
                        }
                    }
                }
            }
        } // end GridView id: chooseReactionsView

        Rectangle {
            id: buttonRect

            height: cancelReactionSelectButton.height
            width: popoverBackgroundRect.width

            anchors {
                top: chooseReactionsView.bottom
                topMargin: units.gu(1)
                left: popoverBackgroundRect.left
            }

            color: parent.color

            Button {
                id: cancelReactionSelectButton

                anchors {
                    top: parent.top
                    left: parent.left
                    leftMargin: units.gu(2)
                }

                text: i18n.tr("Cancel")
                onTriggered: PopupUtils.close(popoverReactions)
            }

            Button {
                id: confirmReactionSelectButton

                anchors {
                    top: parent.top
                    right: parent.right
                    rightMargin: units.gu(2)
                }
                text: i18n.tr("OK")
                color: theme.palette.normal.positive
                onTriggered: {
                    // only send reaction if anything has changed
                    if (needToSend) {
                        let tempChosenEmos = []
                        for (let i = 0; i < chosenReactionsModel.count; i++) {
                            let currEmo = chosenReactionsModel.get(i).chosenEmo
                            tempChosenEmos.push(currEmo)

                            // put the current chosenEmo at the start of emoRecentArray
                            // and cut the last emoji, if the array is now > 42 elements
                            //
                            // Nothing needed if the emoji is already at position 0
                            if (emoRecentArray[0] === currEmo) {
                                continue
                            }

                            // remove it in case it is already present at some
                            // other position than 0
                            for (let j = 1; j < emoRecentArray.length; j++) {
                                if (currEmo == emoRecentArray[j]) {
                                    emoRecentArray.splice(j, 1)
                                    break
                                }
                            }

                            // insert it at the beginning
                            emoRecentArray.splice(0, 0, currEmo)
                            
                            // cut everything beyound pos 41
                            if (emoRecentArray.length > 42) {
                                emoRecentArray.splice(42, emoRecentArray.length - 42)
                            }

                            root.emojiRecentArray = emoRecentArray
                        }

                        sendReactions(tempChosenEmos)
                    }

                    PopupUtils.close(popoverReactions)
                }
            }

            Item {
                // spacer
                height: units.gu(1)
                width: units.gu(2)
            }
        }
    }
} // end Popover id: popoverReactions
