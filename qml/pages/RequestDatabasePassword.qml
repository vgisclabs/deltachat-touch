/*
 * Copyright (C) 2022  Lothar Ketterer
 *
 * This file is part of the app "rounds".
 *
 * rounds is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * rounds is distributed in the hope that it will be useful,
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

    Component.onCompleted: {
        passwordField.focus = true
    }

    // TODO: String not translated yet!
    title: i18n.tr("Enter Database Passphrase")

    Connections {
        target: DeltaHandler
        onDatabaseDecryptionFailure: {
            dialog.title = i18n.tr("Error")
            pwEntryRow.visible = false
            okButton.visible = false
            // TODO: String not translated yet!
            errorLabel.text = i18n.tr("Passphrase incorrect")
            errorLabel.visible = true
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
            dialog.title = i18n.tr("Re-Enter Password")
            passphrase = passwordField.text
            passwordField.text = ""

            pwEntryRow.visible = true
            okButton.visible = true

            errorLabel.visible = false
            confirmErrorButton.visible = false

            passwordField.focus = true
        }
    }

    Row {
        id: pwEntryRow
        spacing: units.gu(1)

        TextField {
            id: passwordField
            echoMode: TextInput.Password

            onAccepted: {
                okButton.clicked()
            }
        }

        Rectangle {
            id: showPwRect
            height: passwordField.height
            width: units.gu(3)
            color: theme.palette.normal.background

            Icon {
                id: showPwIcon
                height: units.gu(3)
                width: height
                anchors {
                    verticalCenter: showPwRect.verticalCenter
                    left: showPwRect.left
                }
                name: 'view-on'
            }

            MouseArea {
                id: showPwMouse
                anchors.fill: parent
                onClicked: {
                    if (passwordField.echoMode == TextInput.Password) {
                        passwordField.echoMode = TextInput.Normal
                        showPwIcon.name = 'view-off'

                    }
                    else {
                        passwordField.echoMode = TextInput.Password
                        showPwIcon.name = 'view-on'
                    }
                }
            }
        }
    }

    Button {
        id: okButton
        text: i18n.tr("OK")
        color: theme.palette.normal.positive
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
                        dialog.title = "Error"
                        firstEntry = true
                        passwordField.text = ""

                        pwEntryRow.visible = false
                        okButton.visible = false

                        // string not translated yet
                        errorLabel.text = i18n.tr("Passwords do not match, try again")
                        errorLabel.visible = true
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

    Label {
        id: errorLabel
        wrapMode: Text.WordWrap
        visible: false
    }

    Button {
        id: confirmErrorButton
        color: theme.palette.normal.negative
        text: i18n.tr("OK")
        visible: false
        onClicked: {
            dialog.title = i18n.tr("Enter Database Password")
            passwordField.text = ""
            pwEntryRow.visible = true
            okButton.visible = true
            errorLabel.visible = false
            confirmErrorButton.visible = false
            passwordField.focus = true
        }
    }
}
