/*
 * Copyright (C) 2023, 2024 Lothar Ketterer
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
//import QtQuick.Controls 2.2
import Lomiri.Components.Popups 1.3
//import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: addEmailPage
    anchors.fill: parent

    signal leavingAddEmailPage()
    signal addressFieldHasChanged(string emailAddress)

    // Creating a new account if false
    property bool changingExistingAccount;

    property bool proxyEnabled: false
    property bool hasProxyUrls: false

    property bool advancedOptionsVisible: false;
    property bool advancedOptionsOpened: false;

    property int showClassicMailsCurrentSetting: DeltaHandler.getTempContextConfig("show_emails") == "" ? 2 : parseInt(DeltaHandler.getTempContextConfig("show_emails"))
    property string showClassicMailsCurrentSettingString: ""


    // Related to provider hint
    property string providerUrl
    property bool providerWorking

    function restartHintTimer() {
        hintTimer.restart()
    }

    function updateShowClassicMailsCurrentSetting()
    {
        switch (showClassicMailsCurrentSetting) {
            case 0:
                showClassicMailsCurrentSettingString = i18n.tr("No, chats only")
                break
            case 1:
                showClassicMailsCurrentSettingString = i18n.tr("For accepted contacts")
                break
            case 2:
                showClassicMailsCurrentSettingString = i18n.tr("All")
                break
            default:
                showClassicMailsCurrentSettingString = "All"
                break
        }
    }

    Connections {
        onLeavingAddEmailPage: DeltaHandler.unrefTempContext()
    }

    Connections {
        id: deltaHandlerConnections
        // to avoid onTempProxySettingsChanged being triggered
        // during onCompleted
        enabled: false

        target: DeltaHandler

        // "address" is a parameter of the three signals below
        // and contains the original string that was passed to
        // getProviderHintSignal(). The code to check for
        // provider hints etc. is run in a separate thread and
        // might take quite a while. In the meantime, the user
        // might have changed the entry for the email address,
        // so the hint/url/status might not apply to the current
        // situation anymore => check address against the displayText
        onProviderHint: {
            if (emailField.displayText == address) {
                providerHintLabel.text = provHint
            }
        }

        onProviderInfoUrl: {
            if (emailField.displayText == address) {
                providerUrl = provUrl
            }
        }

        onProviderStatus: {
            if (emailField.displayText == address) {
                providerWorking = working
            }
        }

        onTempProxySettingsChanged: {
            hasProxyUrls = DeltaHandler.getTempProxyUrls() === "" ? false : true
            proxyEnabled = DeltaHandler.isTempProxyEnabled()
        }

    }

    Component.onCompleted: {
        // The email address field should only be editable if a new account is created.
        // See the "Don’t change mail accounts. Really." part here:
        // https://binblog.de/2024/06/15/deltachat-first-dos-first-donts/
        // TODO: Once AEAP is fully working, this will most likely have to be changed.
        //
        // In case of a typo in the email address that is only noticed after leaving
        // this page, the account has to be removed and a new one has to be created.

        if (changingExistingAccount) {
            // Need to get the proxy settings from tempContext in the C++ side
            // if we're working on an existing account
            let tempurls = DeltaHandler.getTempContextConfig("proxy_url")
            hasProxyUrls = tempurls === "" ? false : true
            proxyEnabled = (DeltaHandler.getTempContextConfig("proxy_enabled") === "1" ? true : false)
            // need to transfer the proxy settings to the temp vars used by Proxy.qml
            DeltaHandler.setTempProxyEnabled(proxyEnabled);
            DeltaHandler.setTempProxyUrls(tempurls);

        } else {
            // Creating a new account, so we're coming from OnboardingChatmail.qml, where
            // a temp proxy could already have been set
            hasProxyUrls = DeltaHandler.getTempProxyUrls() === "" ? false : true
            proxyEnabled = DeltaHandler.isTempProxyEnabled()
        }

        if (hasProxyUrls) {
            advancedOptionsVisible = true
            advancedOptionsOpened = true
        }

        updateShowClassicMailsCurrentSetting()
        addEmailPage.addressFieldHasChanged.connect(DeltaHandler.getProviderHintSignal)

        deltaHandlerConnections.enabled = true
    }

    Component.onDestruction: {
        leavingAddEmailPage()
        if (changingExistingAccount) {
            // Temp proxy vars need to be cleared if we're not in the 
            // new account creation setup, otherwise they should be kept
            DeltaHandler.clearTempProxySettings()
        }
    }

    header: PageHeader {
        id: header

        // TODO this header is too wide
        //title: i18n.tr('Log in with an existing e-mail account')
        title: i18n.tr('Log In')

        // Switch off the back icon to avoid unclear situation. User
        // has to explicitly choose cancel or ok.
        leadingActionBar.actions: [
            Action {
                //iconName: 'close'
                iconSource: "qrc:///assets/suru-icons/close.svg"
                text: i18n.tr('Cancel')
                onTriggered: {
                    // deleteTemporaryAccount() will check whether a
                    // new temporary account was created, and if yes, delete
                    // it as the user is leaving the page without
                    // trying to configure it
                    DeltaHandler.deleteTemporaryAccount()
                    extraStack.pop()
                }
            }
        ]

        //trailingActionBar.numberOfSlots: 2
        trailingActionBar.actions: [
            Action {
                //iconName: 'ok'
                iconSource: "qrc:///assets/suru-icons/ok.svg"
                text: i18n.tr('OK')
                onTriggered: {
                    // unsetting the focus of each field as per past experience,
                    // incomplete text may be retrieved otherwise. Not sure
                    // whether this is the correct procedure though.
                    emailField.focus = false
                    DeltaHandler.setTempContextConfig("addr", emailField.text)

                    passwordField.focus = false
                    DeltaHandler.setTempContextConfig("mail_pw", passwordField.text)

                    DeltaHandler.setTempContextConfig("show_emails", showClassicMailsCurrentSetting.toString(10))

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

                        let certCheckString = "unknown";
                        if (certCheckSelector.selectedIndex == 0) {
                            certCheckString = "DT_CERTCK_AUTO"
                        } else if (certCheckSelector.selectedIndex == 1) {
                            certCheckString = "DT_CERTCK_STRICT"
                        } else if (certCheckSelector.selectedIndex == 2) {
                            certCheckString = "DT_CERTCK_ACCEPT_INVALID"
                        }
                        DeltaHandler.setTempContextConfig("imap_certificate_checks", certCheckString)
                        DeltaHandler.setTempContextConfig("smtp_certificate_checks", certCheckString)

                        DeltaHandler.setTempContextConfig("proxy_url", DeltaHandler.getTempProxyUrls())
                        DeltaHandler.setTempContextConfig("proxy_enabled", proxyEnabled ? "1" : "0")
                    }
                    
                    // now DeltaHandler.configureTempContext() needs to be called,
                    // will be done in the popup
                    let popup1 = PopupUtils.open(configProgress)
                    popup1.success.connect(function() { extraStack.clear() })
                }
            }
        ]
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
                
                readOnly: changingExistingAccount

                onDisplayTextChanged: {
                    // When an email address has been entered, it should be
                    // checked whether DC has a hint for the user regarding
                    // this specific provider. DC Desktop initiates the check
                    // when the address field loses focus. For DeltaTouch, this
                    // means that users don't see the hint when they first
                    // enter the password, then the email address, and then
                    // click on ok as this will open a popup which covers the
                    // page showing the hint. So we could check each time the
                    // display text changes. However, this could mean that a
                    // hint for a different provider will be shown in case the
                    // domain of this provider corresponds to an incomplete
                    // domain of the actual provider (example: hey.co is a
                    // Google-owned domain, hey.com owned by some other
                    // company). Solution: Check onDisplayTextChanged only if
                    // the password field contains text, otherwise check upon
                    // focus loss.
                    if (passwordField.text != "") {
                        // Reset the hint label text so providerHintRect is
                        // invisible in case it had been visible before. Will
                        // be set again for the new displayText if there's a
                        // provider hint by the call to restartHintTimer()
                        providerHintLabel.text = ""
                        restartHintTimer()
                    }
                }

                onFocusChanged: {
                    // see above
                    if (!focus && passwordField.text == "") {
                        // see above
                        providerHintLabel.text = ""
                        restartHintTimer()
                    }

                    if (root.oskViaDbus) {
                        if (focus) {
                            DeltaHandler.openOskViaDbus()
                        } else {
                            DeltaHandler.closeOskViaDbus()
                        }
                    }
                }
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

                onFocusChanged: {
                    if (root.oskViaDbus) {
                        if (focus) {
                            DeltaHandler.openOskViaDbus()
                        } else {
                            DeltaHandler.closeOskViaDbus()
                        }
                    }
                }
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

            LomiriShape {
                id: providerHintRect
                width: parent.width < units.gu(45) ? parent.width - units.gu(7) : units.gu(38)
                height: providerHintLabel.contentHeight + (providerUrlLabel.visible ? providerUrlLabel.contentHeight + units.gu(1) : 0) + units.gu(1)

                anchors {
                    left: parent.left
                    leftMargin: units.gu(1.5)
                    top: passwordField.bottom
                    topMargin: units.gu(1)
                }
                visible: providerHintLabel.text != ""
                backgroundColor: providerWorking ? "#fdf7b2" : "#f9d7d7"

                Label {
                    id: providerHintLabel
                    width: providerHintRect.width - units.gu(1)
                    wrapMode: Text.WordWrap
                    anchors {
                        top: providerHintRect.top
                        topMargin: units.gu(0.5)
                        left: providerHintRect.left
                        leftMargin: units.gu(0.5)
                    }
                    color: providerWorking ? "black" : "#c70404"
                }

                Label {
                    id: providerUrlLabel
                    width: providerHintRect.width - units.gu(1)
                    anchors {
                        top: providerHintLabel.bottom
                        topMargin: units.gu(1)
                        left: providerHintRect.left
                        leftMargin: units.gu(0.5)
                    }
                    text: i18n.tr("More Info")
                    color: providerWorking ? "#0000FF" : "#c70404"
                    font.underline: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Qt.openUrlExternally(providerUrl)
                        }
                    }
                }
            }

            Label {
                id: noServersLabel
                width: parent.width < units.gu(45) ? parent.width - units.gu(8) : units.gu(37)
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    top: providerHintRect.visible ? providerHintRect.bottom : passwordField.bottom
                    topMargin: units.gu(1)
                }
                wrapMode: Text.WordWrap
                text: i18n.tr("Delta Chat does not collect user data, everything stays on your device.")
            }

            Label {
                id: advancedInfoLabel
                width: parent.width < units.gu(45) ? parent.width - units.gu(8) : units.gu(37)
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    top: noServersLabel.bottom
                    topMargin: units.gu(1)
                }
                wrapMode: Text.WordWrap
                text: i18n.tr("For known e-mail providers additional settings are set up automatically. Sometimes IMAP needs to be enabled in the web settings. Consult your e-mail provider or friends for help.")
            }

            ListItem {
                id: dividerItem
                height: divider.height
                anchors {
                    left: parent.left
                    top: advancedInfoLabel.bottom
                    topMargin: units.gu(2)
                }
            }

            ListItem {
                id: showClassicMailsItem
                height: showClassicMailsLayout.height + (divider.visible ? divider.height : 0)
                width: addEmailPage.width
                anchors {
                    left: parent.left
                    top: dividerItem.bottom
                }

                ListItemLayout {
                    id: showClassicMailsLayout
                    title.text: i18n.tr("Show Classic E-Mails")

                    Label {
                        id: showClassicMailsLabel
                        width: addEmailPage.width/4
                        text: showClassicMailsCurrentSettingString
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }
                onClicked: {
                    PopupUtils.open(popoverComponentClassicMail, showClassicMailsItem)
                }
            }

            Button {
                id: advancedOptionsButton
                width: parent.width < units.gu(45) ? parent.width - units.gu(8) : units.gu(37)
                anchors {
                    left: parent.left
                    leftMargin: units.gu(4)
                    top: showClassicMailsItem.bottom
                    topMargin: units.gu(3)
                }
                //iconName: advancedOptionsVisible ? "go-down" : "go-next"
                iconSource: advancedOptionsVisible ? "qrc:///assets/suru-icons/go-down.svg" : "qrc:///assets/suru-icons/go-next.svg"
                iconPosition: "left"
                text: i18n.tr("Advanced")
                onClicked: {
                    advancedOptionsVisible = !advancedOptionsVisible
                    advancedOptionsOpened = true
                }
            }

            ListItem {
                id: dividerItem2
                height: divider.height
                visible: advancedOptionsVisible
                anchors {
                    left: parent.left
                    top: advancedOptionsButton.bottom
                    topMargin: units.gu(1)
                }
            }

            ListItem {
                id: proxyItem
                height: proxyItemLayout.height + (divider.visible ? divider.height : 0)
                width: addEmailPage.width
                visible: advancedOptionsVisible
                anchors {
                    left: parent.left
                    top: dividerItem2.bottom
                    topMargin: units.gu(1)
                }

                ListItemLayout {
                    id: proxyItemLayout
                    title.text: i18n.tr("Proxy")
                    title.font.bold: true

                    Label {
                        id: proxyEnabledLabel
                        width: addEmailPage.width/4
                        text: proxyEnabled ? i18n.tr("On") : i18n.tr("Off")

                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }

                    Icon {
                        //name: "go-next"
                        source: "qrc:///assets/suru-icons/go-next.svg"
                        SlotsLayout.position: SlotsLayout.Trailing;
                        width: units.gu(2)
                    }
                }

                onClicked: {
                    extraStack.push(Qt.resolvedUrl('Proxy.qml'), { "forCurrentContext": false })
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
                    top: proxyItem.bottom
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

                    onFocusChanged: {
                        if (root.oskViaDbus) {
                            if (focus) {
                                DeltaHandler.openOskViaDbus()
                            } else {
                                DeltaHandler.closeOskViaDbus()
                            }
                        }
                    }
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

                    onFocusChanged: {
                        if (root.oskViaDbus) {
                            if (focus) {
                                DeltaHandler.openOskViaDbus()
                            } else {
                                DeltaHandler.closeOskViaDbus()
                            }
                        }
                    }
                }

                Label {
                    id: imapPortLabel
                    text: i18n.tr("IMAP Port")
                }

                TextField {
                    id: imapPortField
                    width: emailField.width
                    text: DeltaHandler.getTempContextConfig("mail_port")
                    placeholderText: i18n.tr("Default (%1)").arg((imapSecSelector.selectedIndex == 0 || imapSecSelector.selectedIndex == 1 ? "993" : "143"))
                    validator: IntValidator {bottom: 0; top: 65535}

                    onFocusChanged: {
                        if (root.oskViaDbus) {
                            if (focus) {
                                DeltaHandler.openOskViaDbus()
                            } else {
                                DeltaHandler.closeOskViaDbus()
                            }
                        }
                    }
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

                    onFocusChanged: {
                        if (root.oskViaDbus) {
                            if (focus) {
                                DeltaHandler.openOskViaDbus()
                            } else {
                                DeltaHandler.closeOskViaDbus()
                            }
                        }
                    }
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

                    onFocusChanged: {
                        if (root.oskViaDbus) {
                            if (focus) {
                                DeltaHandler.openOskViaDbus()
                            } else {
                                DeltaHandler.closeOskViaDbus()
                            }
                        }
                    }
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

                    onFocusChanged: {
                        if (root.oskViaDbus) {
                            if (focus) {
                                DeltaHandler.openOskViaDbus()
                            } else {
                                DeltaHandler.closeOskViaDbus()
                            }
                        }
                    }
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

                    onFocusChanged: {
                        if (root.oskViaDbus) {
                            if (focus) {
                                DeltaHandler.openOskViaDbus()
                            } else {
                                DeltaHandler.closeOskViaDbus()
                            }
                        }
                    }
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
                        let certCheckString = DeltaHandler.getTempContextConfig("imap_certificate_checks")
                        if (certCheckString === "DT_CERTCK_AUTO") {
                            certCheckSelector.selectedIndex = 0
                        } else if (certCheckString === "DT_CERTCK_STRICT") {
                            certCheckSelector.selectedIndex = 1
                        } else if (certCheckString === "DT_CERTCK_ACCEPT_INVALID") {
                            certCheckSelector.selectedIndex = 2
                        } else {
                            console.log("AddOrConfigureEmailAccount.qml: WARNING: getTempContextConfig did return an unknown value \"", certCheckString, "\" for key imap_certificate_checks")
                        }
                    }
                }
            } // end Column id: advancedOptionsColumn
        } // end Item id: contentFlick
    } // end Flickable id:flickable

    Component {
        id: configProgress

        ProgressConfigAccount { // see file ProgressConfigAccount.qml
            title: i18n.tr('Configuring...')
        }
    }

    Component {
        id: popoverComponentClassicMail
        Popover {
            id: popoverClassicMail
            Column {
                id: containerLayout
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                }
                ListItem {
                    height: layout1.height
                    // should be automatically be themed with something like
                    // theme.palette.normal.overlay, but this
                    // doesn't seem to work for Ambiance (and importing
                    // Lomiri.Components.Themes 1.3 doesn't solve it). 
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout1
                        title.text: i18n.tr("No, chats only")
                    }
                    onClicked: {
                        showClassicMailsCurrentSetting = 0
                        PopupUtils.close(popoverClassicMail)
                        updateShowClassicMailsCurrentSetting()
                    }
                }

                ListItem {
                    height: layout2.height
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout2
                        title.text: i18n.tr("For accepted contacts")
                    }
                    onClicked: {
                        showClassicMailsCurrentSetting = 1
                        PopupUtils.close(popoverClassicMail)
                        updateShowClassicMailsCurrentSetting()
                    }
                }

                ListItem {
                    height: layout3.height
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout3
                        title.text: i18n.tr("All")
                    }
                    onClicked: {
                        showClassicMailsCurrentSetting = 2
                        PopupUtils.close(popoverClassicMail)
                        updateShowClassicMailsCurrentSetting()
                    }
                }
            }
        }
    }

    Timer {
        // Debounce, i.e. don't ask for a provider hint if
        // the user is still typing
        id: hintTimer
        interval: 500
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            addEmailPage.addressFieldHasChanged(emailField.displayText)
        }
    }
} // end of Page id: addEmailPage
