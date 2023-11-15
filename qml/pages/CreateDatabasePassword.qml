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

// Will be used when a passphrase to be used to encrypt
// the database is set for the first time. It's asked
// twice, both entries have to match. Cancelling is possible,
// in this case the database will not be encrpyted.

Dialog {
    id: dialog

    signal cancelled()
    signal success()

    property string passphrase
    property bool firstEntry: true

    Component.onCompleted: {
        passwordField.focus = true
    }

    // TODO: String not translated yet!
    title: i18n.tr("Enter Database Password")

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
                    passphrase = passwordField.text
                    passwordField.text = ""
                    passwordField.focus = true
                    // TODO: string not translated yet
                    dialog.title = i18n.tr("Re-Enter Password")
                    firstEntry = false
                } else {
                    if (passwordField.text == passphrase) {
                        DeltaHandler.setDatabasePassphrase(passwordField.text, true)
                        success()
                        PopupUtils.close(dialog)
                    } else {
                        firstEntry = true
                        passwordField.text = ""

                        pwEntryRow.visible = false
                        okButton.visible = false
                        cancelButton.visible = false

                        errorLabel.visible = true
                        confirmErrorButton.visible = true
                    }
                }
            } else {
                passwordField.focus = true
            }
        }
    }

    Button {
        id: cancelButton
        text: i18n.tr("Cancel")
        onClicked: {
            cancelled()
            PopupUtils.close(dialog)
        }
    }

    Label {
        id: errorLabel
        // TODO: string not translated yet
        text: i18n.tr("Passwords do not match, try again")
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
            pwEntryRow.visible = true
            okButton.visible = true
            cancelButton.visible = true
            passwordField.focus = true

            errorLabel.visible = false
            confirmErrorButton.visible = false
        }
    }
}
