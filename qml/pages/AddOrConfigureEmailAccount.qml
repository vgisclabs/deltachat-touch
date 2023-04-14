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
//import QtQuick.Controls 2.2
import Ubuntu.Components.Popups 1.3
//import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: addEmailPage
    anchors.fill: parent

    signal leavingAddEmailPage()

    property bool advancedOptionsVisible: false;
    property bool advancedOptionsOpened: false;

    Connections {
        onLeavingAddEmailPage: DeltaHandler.unrefTempContext()
    }

    Component.onDestruction: {
        leavingAddEmailPage()
    }

    header: PageHeader {
        id: header

        // TODO this header is too wide
        //title: i18n.tr('Log in with an existing e-mail account')
        title: i18n.tr('Log In')

        // Switch off the back icon to avoid unclear situation. User
        // has to explicitly choose cancel or ok.
        leadingActionBar.actions: undefined

//        trailingActionBar.actions: [
//            Action {
//                iconName: 'settings'
//                text: i18n.tr('Settings')
//                onTriggered: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('SettingsPage.qml'))
//            },
//
//            Action {
//                iconName: 'info'
//                text: i18n.tr('About')
//                onTriggered: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('About.qml'))
//            }
//        ]
    } //PageHeader id:header
        
    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.topMargin: (addEmailPage.header.flickable ? 0 : addEmailPage.header.height)
        anchors.bottomMargin: units.gu(2)
        contentHeight: flickContent.childrenRect.height

        Item {
            id: flickContent
            width: parent.width

            Label {
                id: subheaderLabel
                width: parent.width < units.gu(45) ? parent.width - units.gu(8) : units.gu(37)
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    top: parent.top
                    topMargin: units.gu(1)
                }
                text: i18n.tr("Log in with an existing e-mail account")
                font.bold: true
                wrapMode: Text.Wrap
            }

            Label {
                id: emailLabel
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    top: subheaderLabel.bottom
                    topMargin: units.gu(2)
                }
                text: i18n.tr('E-Mail Address')
            }

            TextField {
                id: emailField
                width: parent.width < units.gu(40) ? parent.width - units.gu(8) : units.gu(32)
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    top: emailLabel.bottom
                    topMargin: units.gu(1)
                }
                text: DeltaHandler.getTempContextConfig("addr")
                // TODO: add RegExpValidator?
            }

            Label {
                id: passwordLabel
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    top: emailField.bottom
                    topMargin: units.gu(1)
                }
                text: i18n.tr('Password')
            }

            TextField {
                id: passwordField
                width: emailField.width
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    top: passwordLabel.bottom
                    topMargin: units.gu(1)
                }
                text: DeltaHandler.getTempContextConfig("mail_pw")
                echoMode: TextInput.Password
            }

            Rectangle {
                id: showPwRect
                height: units.gu(3)
                width: height
                color: theme.palette.normal.background
                anchors {
                    left: passwordField.right
                    leftMargin: units.gu(2)
                    verticalCenter: passwordField.verticalCenter
                }

                Icon {
                    anchors.fill: parent
                    id: showPwIcon
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

            Label {
                id: advancedInfoLabel
                width: parent.width < units.gu(45) ? parent.width - units.gu(8) : units.gu(37)
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    top: passwordField.bottom
                    topMargin: units.gu(1)
                }
                wrapMode: Text.Wrap
                text: i18n.tr("For known e-mail providers additional settings are set up automatically. Sometimes IMAP needs to be enabled in the web settings. Consult your e-mail provider or friends for help.")
            }

            Button {
                id: advancedOptionsButton
                width: parent.width < units.gu(45) ? parent.width - units.gu(8) : units.gu(37)
                anchors {
                    left: parent.left
                    leftMargin: units.gu(4)
                    top: advancedInfoLabel.bottom
                    topMargin: units.gu(3)
                }
                iconName: advancedOptionsVisible ? "go-down" : "go-next"
                iconPosition: "left"
                text: i18n.tr("Advanced")
                onClicked: {
                    advancedOptionsVisible = !advancedOptionsVisible
                    advancedOptionsOpened = true
                }
            }

            Column {
                id: advancedOptionsColumn
                height: advancedOptionsVisible ? childrenRect.height : 0
                spacing: units.gu(1)
                visible: advancedOptionsVisible
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    top: advancedOptionsButton.bottom
                    topMargin: units.gu(3)
                }

                Label {
                    id: inboxLabel
                    text: i18n.tr("Inbox")
                    font.bold: true
                }

                Label {
                    id: imapLoginNameLabel
                    text: i18n.tr("IMAP Login Name")
                }

                TextField {
                    id: imapLoginNameField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("mail_user")
                    placeholderText: i18n.tr("Default (same as above)")
                }

                Label {
                    id: imapServerLabel
                    text: i18n.tr("IMAP Server")
                }

                TextField {
                    id: imapServerField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("mail_server")
                    placeholderText: i18n.tr("Automatic")
                }

                Label {
                    id: imapPortLabel
                    text: i18n.tr("IMAP Port")
                }

                TextField {
                    id: imapPortField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("mail_port")
                    placeholderText: i18n.tr("Standard (%1)").arg((imapSecSelector.selectedIndex == 0 || imapSecSelector.selectedIndex == 1 ? "993" : "143"))
                    validator: IntValidator {bottom: 0; top: 65535}
                }

                OptionSelector {
                    id: imapSecSelector
                    text: i18n.tr("IMAP Security") 
                    containerHeight: itemHeight * 4
                    model: [i18n.tr("Automatic"),
                            "SSL/TLS",
                            "STARTTLS",
                            i18n.tr("Off")]

                    onSelectedIndexChanged: {
                        //DeltaHandler.setTempContextConfig("mail_security", imapSecSelector.selectedIndex.toString(10))
                    }
   
                    Component.onCompleted: {
                        imapSecSelector.selectedIndex = (DeltaHandler.getTempContextConfig("mail_security") == "" ? 0 : parseInt(DeltaHandler.getTempContextConfig("mail_security"), 10))
                    }
                }

                Label {
                    // to make some space above the Outbox section
                    id: emptySpaceLabel1
                    text: " "
                }

                Label {
                    id: outboxLabel
                    text: i18n.tr("Outbox")
                    font.bold: true
                }

                Label {
                    id: smtpLoginLabel
                    text: i18n.tr("SMTP Login Name") 
                }

                TextField {
                    id: smtpLoginField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("send_user")
                    placeholderText: i18n.tr("Default (same as above)")
                }

                Label {
                    id: smtpPasswordLabel
                    text: i18n.tr("SMTP Password")
                }

                TextField {
                    id: smtpPasswordField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("send_pw")
                    placeholderText: i18n.tr("Default (same as above)")
                }

                Label {
                    id: smtpServerLabel
                    text: i18n.tr("SMTP Server")
                }

                TextField {
                    id: smtpServerField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("send_server")
                    placeholderText: i18n.tr("Automatic")
                }

                Label {
                    id: smtpPortLabel
                    text: i18n.tr("SMTP Port")
                }

                TextField {
                    id: smtpPortField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("send_port")
                    placeholderText: i18n.tr("Standard (%1)").arg(smtpSecSelector.selectedIndex == 0 || smtpSecSelector.selectedIndex == 1 ? "465" : (smtpSecSelector.selectedIndex == 2 ? "587" : "25"))
                    validator: IntValidator {bottom: 0; top: 65535}
                }

                OptionSelector {
                    id: smtpSecSelector
                    text: i18n.tr("SMTP Security") 
                    containerHeight: itemHeight * 4
                    model: [i18n.tr("Automatic"),
                            "SSL/TLS",
                            "STARTTLS",
                            i18n.tr('Off')]

                    onSelectedIndexChanged: {
                    }
   
                    Component.onCompleted: {
                        smtpSecSelector.selectedIndex = (DeltaHandler.getTempContextConfig("send_security") == "" ? 0 : parseInt(DeltaHandler.getTempContextConfig("send_security"), 10))
                    }
                }

                OptionSelector {
                    id: certCheckSelector
                    text: i18n.tr("Certificate Checks") 
                    containerHeight: itemHeight * 3
                    model: [i18n.tr("Automatic"),
                            i18n.tr("Strict"),
                            i18n.tr("Accept invalid certificates")]

                    onSelectedIndexChanged: {
                    }
   
                    Component.onCompleted: {
                        certCheckSelector.selectedIndex = (DeltaHandler.getTempContextConfig("smtp_certificate_checks") == "" ? 0 : (parseInt(DeltaHandler.getTempContextConfig("smtp_certificate_checks"), 10) == 3 ? 2 : parseInt(DeltaHandler.getTempContextConfig("smtp_certificate_checks"), 10)))
                    }
                }

                Label {
                    // to make some space above the SOCKS5 section
                    id: emptySpaceLabel2
                    text: " "
                }

                Label {
                    id: socksSectionLabel
                    text: "SOCKS5" // i18n.tr not needed here
                    font.bold: true
                }

                Rectangle {
                    id: socksSwitchRect
                    width: parent.width < units.gu(45) ? parent.width - units.gu(8) : units.gu(37)
                    height: socksSwitch.height
                    visible: advancedOptionsVisible

                    Label {
                        id: socksSwitchLabel
                        anchors {
                            top: socksSwitchRect.top
                            left: socksSwitchRect.left
                        }
                        text: i18n.tr("Use SOCKS5")
                    }

                    Switch {
                        id: socksSwitch
                        anchors {
                            top: socksSwitchRect.top
                            right: socksSwitchRect.right
                        }
                        checked: DeltaHandler.getTempContextConfig("socks5_enabled") == '1'
                        onCheckedChanged: {
                            // TODO
                        }
                    }
                }

                Label {
                    id: socksWarningLabel
                    width: addEmailPage.width < units.gu(45) ? addEmailPage.width - units.gu(8) : units.gu(37)
                    text: i18n.tr("SOCKS5 support is currently experimental. Please use at your own risk. If you type in an address in the e-mail field, there will be DNS lookup that won\'t get tunneled through SOCKS5.")
                    wrapMode: Text.Wrap
                }
                Label {
                    id: socksHostLabel
                    text: i18n.tr("SOCKS5 Host")
                }

                TextField {
                    id: socksHostField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("socks5_host")
                    placeholderText: i18n.tr("Standard (%1)").arg("localhost")
                    enabled: socksSwitch.checked
                }

                Label {
                    id: socksPortLabel
                    text: i18n.tr("SOCKS5 Port")
                }

                TextField {
                    id: socksPortField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("socks5_port")
                    placeholderText: i18n.tr("Standard (%1)").arg("9150")
                    validator: IntValidator {bottom: 0; top: 65535}
                    enabled: socksSwitch.checked
                }

                Label {
                    id: socksUsernameLabel
                    text: i18n.tr("SOCKS5 User")
                }

                TextField {
                    id: socksUsernameField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("socks5_user")
                    enabled: socksSwitch.checked
                }

                Label {
                    id: socksPasswordLabel
                    text: i18n.tr("SOCKS5 Password")
                }

                Rectangle {
                    id: socksPasswordFieldRect
                    width: addEmailPage.width < units.gu(45) ? addEmailPage.width - units.gu(8) : units.gu(37)
                    height: socksPasswordField.height
                    color: theme.palette.normal.background

                    TextField {
                        id: socksPasswordField
                        width: emailField.width
                        anchors {
                            left: socksPasswordFieldRect.left
                            top: socksPasswordFieldRect.top
                        }
                        text: DeltaHandler.getTempContextConfig("socks5_password")
                        echoMode: TextInput.Password
                        enabled: socksSwitch.checked
                    }

                    Rectangle {
                        id: showSocksPwRect
                        height: units.gu(3)
                        width: height
                        color: theme.palette.normal.background
                        anchors {
                            right: socksPasswordFieldRect.right
                            verticalCenter: socksPasswordFieldRect.verticalCenter
                        }

                        Icon {
                            anchors.fill: parent
                            id: showSocksPwIcon
                            name: 'view-on'
                        }

                        MouseArea {
                            id: showSocksPwMouse
                            anchors.fill: parent
                            onClicked: {
                                if (socksPasswordField.echoMode == TextInput.Password) {
                                    socksPasswordField.echoMode = TextInput.Normal
                                    showSocksPwIcon.name = 'view-off'

                                }
                                else {
                                    socksPasswordField.echoMode = TextInput.Password
                                    showSocksPwIcon.name = 'view-on'
                                }
                            }
                        } // end MouseArea id: showSocksPwMouse
                    } // end Rectangle id: showSocksPwRect
                } // end Rectangle id: socksPasswordFieldRect

            } // end Column id: advancedOptionsColumn

            Rectangle {
                id: okCancelRect
                height: cancelButton.height
                width: cancelButton.width + okButton.width + units.gu(3)
                color: theme.palette.normal.background
                anchors {
                    left: parent.left
                    leftMargin: units.gu(4)
                    top: advancedOptionsColumn.bottom
                    topMargin: units.gu(3)
                }

                Button {
                    id: cancelButton
                    width: (implicitWidth > okButton.implicitWidth ? implicitWidth : okButton.implicitWidth) + units.gu(2)
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: i18n.tr('Cancel')
                    onClicked: layout.removePages(addEmailPage)
                }

                Button {
                    id: okButton
                    width: (implicitWidth > okButton.implicitWidth ? implicitWidth : okButton.implicitWidth) + units.gu(2)
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: i18n.tr('Ok')
                    onClicked: {
                        DeltaHandler.prepareTempContextConfig()

                        // unsetting the focus of each field as per past experience,
                        // incomplete text may be retrieved otherwise. Not sure
                        // whether this is the correct procedure though.
                        emailField.focus = false
                        DeltaHandler.setTempContextConfig("addr", emailField.text)

                        passwordField.focus = false
                        DeltaHandler.setTempContextConfig("mail_pw", passwordField.text)

                        if (advancedOptionsOpened) {
                            imapLoginNameField.focus = false
                            DeltaHandler.setTempContextConfig("mail_user", imapLoginNameField.text)

                            imapServerField.focus = false
                            DeltaHandler.setTempContextConfig("mail_server", imapServerField.text)

                            imapPortField.focus = false
                            DeltaHandler.setTempContextConfig("mail_port", imapPortField.text)

                            DeltaHandler.setTempContextConfig("mail_security", imapSecSelector.selectedIndex.toString(10))

                            smtpLoginField.focus = false
                            DeltaHandler.setTempContextConfig("send_user", smtpLoginField.text)

                            smtpPasswordField.focus = false
                            DeltaHandler.setTempContextConfig("send_pw", smtpPasswordField.text)

                            smtpServerField.focus = false
                            DeltaHandler.setTempContextConfig("send_server", smtpServerField.text)

                            smtpPortField.focus = false
                            DeltaHandler.setTempContextConfig("send_port", smtpPortField.text)
                            
                            DeltaHandler.setTempContextConfig("send_security", smtpSecSelector.selectedIndex.toString(10))
                            DeltaHandler.setTempContextConfig("imap_certificate_checks", (certCheckSelector.selectedIndex == 2 ? "3" : certCheckSelector.selectedIndex.toString(10)))
                            DeltaHandler.setTempContextConfig("smtp_certificate_checks", (certCheckSelector.selectedIndex == 2 ? "3" : certCheckSelector.selectedIndex.toString(10)))

                            DeltaHandler.setTempContextConfig("socks5_enabled", socksSwitch.checked ? "1" : "0")

                            socksHostField.focus = false
                            DeltaHandler.setTempContextConfig("socks5_host", socksHostField.text)

                            socksPortField.focus = false
                            DeltaHandler.setTempContextConfig("socks5_port", socksPortField.text)

                            socksUsernameField.focus = false
                            DeltaHandler.setTempContextConfig("socks5_user", socksUsernameField.text)

                            socksPasswordField.focus = false
                            DeltaHandler.setTempContextConfig("socks5_password", socksPasswordField.text)
                        }
                        
                        // now DeltaHandler.configureTempContext() needs to be called,
                        // will be done in the popup
                        PopupUtils.open(configProgress)
                        //layout.removePages(chatlistPage)
                    }
                }
            } // end Rectangle id: okCancelRect
        } // end Item id: contentFlick
    } // end Flickable id:flickable

    Component {
        id: configProgress

        ProgressConfigAccount { // see file ProgressConfigAccount.qml
            title: i18n.tr('Configuring...')
        }
    }
    
} // end of Page id: addEmailPage
