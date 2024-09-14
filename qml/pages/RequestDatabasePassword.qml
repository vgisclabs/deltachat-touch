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

import DeltaHandler 1.0

// This component asks for the passphrase with
// which the database is encrypted. Usually,
// DeltaHandler checks the passphrase for correctness
// by trying to open the closed database(s). One special
// case where this is not possible is described below.

Dialog {
    id: dialog

    signal success()

    // if the passphrase is entered twice and compared
    // whether the two entries are the same, the first entry
    // is stored here
    property string passphrase
    property bool firstEntry: true
    property bool extendedInfoVisible: false

    Component.onCompleted: {
        passwordField.focus = true
        if (root.oskViaDbus) {
            DeltaHandler.openOskViaDbus()
        }
    }

    Connections {
        target: DeltaHandler
        onDatabaseDecryptionFailure: {
            titleLabel.text = i18n.tr("Error")
            pwEntryRow.visible = false
            okButton.visible = false
            // TODO: String not translated yet!
            textLabel.text = i18n.tr("Passphrase incorrect")
            confirmErrorButton.visible = true
        }

        onDatabaseDecryptionSuccess: {
            PopupUtils.close(dialog)
            success()
        }

        onNoEncryptedDatabase: {
            // If the workflow to encrypt the database was interrupted
            // before the first account was encrypted, the passphrase
            // entered by the user cannot be checked for correctness, so
            // it should be entered twice to avoid resuming the
            // encryption workflow with a passphrase that contains a
            // typo.
            firstEntry = false
            titleLabel.text = i18n.tr("Re-Enter Password")
            passphrase = passwordField.text
            passwordField.text = ""

            pwEntryRow.visible = true
            okButton.visible = true

            textLabel.text = i18n.tr("Only message texts and server credentials are encrypted. Attachments (images, files etc.) remain unencrypted.")
            confirmErrorButton.visible = false

            passwordField.focus = true
        }
    }

    // use Labels instead of dialog.title and dialog.text to be able to scale font size
    Label {
        id: titleLabel
        text: i18n.tr("Enter Database Passphrase")
        horizontalAlignment: Text.AlignLeft
        wrapMode: Text.WordWrap
        fontSize: root.scaledFontSizeLarger
    }

    Label {
        id: textLabel
        text: i18n.tr("Only message texts and server credentials are encrypted. Attachments (images, files etc.) remain unencrypted.")
        horizontalAlignment: Text.AlignLeft
        wrapMode: Text.WordWrap
        fontSize: root.scaleLevel > 3 ? root.scaledFontSizeSmaller : root.scaledFontSize
        visible: extendedInfoVisible
    }

    Row {
        id: pwEntryRow
        spacing: units.gu(1)

        TextField {
            id: passwordField
            echoMode: TextInput.Password
            font.pixelSize: scaledFontSizeInPixels

            onAccepted: {
                okButton.clicked()
            }

            onFocusChanged: {
                if (root.oskViaDbus) {
                    if (passwordField.focus) {
                        DeltaHandler.openOskViaDbus()
                    } else {
                        DeltaHandler.closeOskViaDbus()
                    }
                }
            }
        }

        Rectangle {
            id: showPwRect
            height: passwordField.height
            width: units.gu(5)
            color: theme.palette.normal.background

            Icon {
                id: showPwIcon
                height: units.gu(3.5)
                width: height
                anchors {
                    verticalCenter: showPwRect.verticalCenter
                    horizontalCenter: showPwRect.horizontalCenter
                }
                //name: 'view-on'
                source: "qrc:///assets/suru-icons/view-on.svg"
            }

            MouseArea {
                id: showPwMouse
                anchors.fill: parent
                onClicked: {
                    if (passwordField.echoMode == TextInput.Password) {
                        passwordField.echoMode = TextInput.Normal
                        //showPwIcon.name = 'view-off'
                        showPwIcon.source = "qrc:///assets/suru-icons/view-off.svg"

                    }
                    else {
                        passwordField.echoMode = TextInput.Password
                        //showPwIcon.name = 'view-on'
                        showPwIcon.source = "qrc:///assets/suru-icons/view-on.svg"
                    }
                }
            }
        }
    }

    Button {
        id: okButton
        text: i18n.tr("OK")
        color: theme.palette.normal.positive
        font.pixelSize: scaledFontSizeInPixels
        onClicked: {
            passwordField.focus = false

            // Require at least one password character
            if (passwordField.text != "") {
                if (firstEntry) {
                    DeltaHandler.setDatabasePassphrase(passwordField.text, false)
                    // the entered text will be stored into the passphrase string
                    // by the slot handling the noEncryptedDatabase signal, if needed
                } else {
                    // firstEntry is false, this means that the user has entered the
                    // passphrase once, it was sent to DeltaHandler, but DeltaHandler
                    // couldn't check it for correctness, so the signal
                    // noEncryptedDatabase was sent, and the
                    // user has re-entered the passphrase.
                    // Check whether it matches with the one stored in 
                    // the passphrase string
                    if (passwordField.text == passphrase) {
                        // a match, set the passphrase in DeltaHandler and exit the popup
                        DeltaHandler.setDatabasePassphrase(passwordField.text, true)
                        PopupUtils.close(dialog)
                        success()
                    } else {
                        titleLabel.text = "Error"
                        firstEntry = true
                        passwordField.text = ""

                        pwEntryRow.visible = false
                        okButton.visible = false

                        // string not translated yet
                        textLabel.text = i18n.tr("Passwords do not match, try again")
                        textLabel.visible = true
                        confirmErrorButton.visible = true
                    }
                }
            } else {
                // field does not contain any input, put
                // it back into focus
                passwordField.focus = true
            }
        }
    }

    Button {
        id: confirmErrorButton
        color: theme.palette.normal.negative
        text: i18n.tr("OK")
        font.pixelSize: scaledFontSizeInPixels
        visible: false
        onClicked: {
            titleLabel.text = i18n.tr("Enter Database Password")
            passwordField.text = ""
            pwEntryRow.visible = true
            okButton.visible = true
            textLabel.text = i18n.tr("Only message texts and server credentials are encrypted. Attachments (images, files etc.) remain unencrypted.")
            textLabel.visible = extendedInfoVisible
            confirmErrorButton.visible = false
            passwordField.focus = true
        }
    }

    Button {
        id: forgotPwButton
        text: i18n.tr("Forgot Password")
        font.pixelSize: scaledFontSizeInPixels
        visible: extendedInfoVisible
        onClicked: {
            let popup1 = PopupUtils.open(
                Qt.resolvedUrl('ConfirmOpenExternalUrl.qml'),
                dialog,
                { "externalLink": "https://codeberg.org/lk108/deltatouch/wiki/Database-Encryption#i-lost-my-password"
            })
        }
    }

    Button {
        id: infoButton
        text: i18n.tr("More Info")
        font.pixelSize: scaledFontSizeInPixels
        visible: extendedInfoVisible
        onClicked: {
            let popup1 = PopupUtils.open(
                Qt.resolvedUrl('ConfirmOpenExternalUrl.qml'),
                dialog,
                { "externalLink": "https://codeberg.org/lk108/deltatouch/wiki/Database-Encryption"
            })
        }
    }

    // Taken from from Messaging-App Copyright 2012-2016 Canonical Ltd.,
    // licensed under GPLv3
    // https://gitlab.com/ubports/development/core/messaging-app/-/blob/62f448f8a5bec59d8e5c3f7bf386d6d61f9a1615/src/qml/Messages.qml
    // modified by (C) 2023 Lothar Ketterer
    PinchHandler {
        id: pinchHandlerMain
        target: null
        enabled: !root.chatOpenAlreadyClicked

        minimumPointCount: 2

        property real previousScale: 1.0
        property real zoomThreshold: 0.5

        onScaleChanged: {
            var nextLevel = root.scaleLevel
            if (activeScale > previousScale + zoomThreshold && nextLevel < root.maximumScale) { // zoom in
                nextLevel++
            // nextLevel > 1 (instead of > 0) so the main scaleLevel cannot go below "small"
            } else if (activeScale < previousScale - zoomThreshold && nextLevel > 1) { // zoom out
                nextLevel--
            }

            if (nextLevel !== root.scaleLevel) {

                root.scaleLevel = nextLevel

//                 // get the index of the current drag item if any and make ListView follow it
//                var positionInRoot = mapToItem(messageList.contentItem, centroid.position.x, centroid.position.y)
//                const currentIndex = messageList.indexAt(positionInRoot.x,positionInRoot.y)
//
//                messageList.positionViewAtIndex(currentIndex, ListView.Visible)
//
                previousScale = activeScale
            }
        }

        onActiveChanged: {
            if (active) {
                previousScale = 1.0
            }
            view.currentIndex = -1
        }
    }
}
