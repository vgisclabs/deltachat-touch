/*
 * Copyright (C) 2024 Lothar Ketterer
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
import QtQuick.Layouts 1.3
import Ubuntu.Components.Popups 1.3
import Qt.labs.settings 1.0
import QtQml.Models 2.12
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: chatmailPage

    property string provider: "nine.testrun.org"
    property string initialUrl: "dcaccount:https://nine.testrun.org/new"

    // true if the QR or URL is dclogin:, false
    // if not (valid QR/URL is then only dcaccount:)
    property bool isDcLogin: false

    property string oldUrlHandlingPage
    readonly property string thisPagePath: "qml/OnboardingChatmail"

    signal setTempContextNull()

    Component.onCompleted: {
        DeltaHandler.finishedSetConfigFromQr.connect(continueQrAccountCreation)

        root.unprocessedUrl.connect(processUrl)

        oldUrlHandlingPage = root.urlHandlingPage
        root.urlHandlingPage = thisPagePath

        // Initialise with the default chatmail server
        //DeltaHandler.evaluateQrCode("dcaccount:https://nine.testrun.org/new")
        processUrl(initialUrl)
    }

    Component.onDestruction: {
        root.urlHandlingPage = oldUrlHandlingPage
    }

    Loader {
        id: picImportLoader
    }

    Connections {
        target: picImportLoader.item
        onFileSelected: {
            chatmailPage.setProfilePic(urlOfFile)
            picImportLoader.source = ""
        }
        onCancelled: {
            picImportLoader.source = ""
        }
    }

    Connections {
        target: chatmailPage
        onSetTempContextNull: DeltaHandler.unrefTempContext()
    }

    function setProfilePic(imagePath) {
        let tempPath = DeltaHandler.copyToCache(imagePath);

        if (tempPath.startsWith("qrc:")) {
            tempPath = tempPath.slice(4, tempPath.length)
        } 

        if (!tempPath.startsWith("file://")) {
            tempPath = "file://" + tempPath
        }

        profilePicImage.source = tempPath
    }

    function openFileDialog() {
        // only for non-UT
        picImportLoader.source = "FileImportDialog.qml"
        picImportLoader.item.setFileType(DeltaHandler.ImageType)
        picImportLoader.item.open()
    }

    function processUrl(urlstring) {
        if (root.urlHandlingPage !== thisPagePath) {
            return
        }

        let qrstate = DeltaHandler.evaluateQrCode(urlstring)
        if (qrstate === DeltaHandler.DT_QR_ACCOUNT) {
            isDcLogin = false
            provider = DeltaHandler.getQrTextOne()

        } else if (qrstate === DeltaHandler.DT_QR_LOGIN) {
            isDcLogin = true
            provider = DeltaHandler.getQrTextOne()

        } else if (qrstate === DeltaHandler.DT_QR_ERROR) {
             let popup1 = PopupUtils.open(
                 Qt.resolvedUrl("ErrorMessage.qml"),
                 chatmailPage,
                 { text: i18n.tr("Error: %1").arg(DeltaHandler.getQrTextOne())
             })
         } else if (qrstate === DeltaHandler.DT_QR_BACKUP || qrstate === DeltaHandler.DT_QR_BACKUP2) {
             let popup11 = PopupUtils.open(
                 Qt.resolvedUrl("ConfirmDialog.qml"),
                 chatmailPage,
                 { dialogText: i18n.tr("Copy the account from the other device to this device?"),
                 dialogTitle: i18n.tr("Add as Second Device"),
                 okButtonText: i18n.tr("Add Second Device"),
                 confirmButtonPositive: true
             })
             popup11.confirmed.connect(function() {
                let popup9 = PopupUtils.open(Qt.resolvedUrl("ProgressQrBackupImport.qml"))
                popup9.success.connect(function() { clearStackTimer.start() })
             })
        } else {
             let popup2 = PopupUtils.open(
                 Qt.resolvedUrl("ErrorMessage.qml"),
                 chatmailPage,
                 { text: i18n.tr("The scanned QR code cannot be used to set up a new profile.")
             })
        }
    }

    function continueQrAccountCreation(wasSuccessful) {
        // finishedSetConfigFromQr signal)
        if (root.urlHandlingPage === thisPagePath) {
            if (wasSuccessful) {
                // set the avatar if the user has set an image
                if (profilePicImage.status !== Image.Null && profilePicImage.status !== Image.Error) {
                    DeltaHandler.setTempContextConfig("selfavatar", profilePicImage.source)
                }

                // set the displayname
                DeltaHandler.setTempContextConfig("displayname", usernameField.text)

                let popup3 = PopupUtils.open(
                        Qt.resolvedUrl("ProgressConfigAccount.qml"),
                        chatlistPage,
                        { "title": i18n.tr('Configuring...')
                })

                popup3.success.connect(function() { clearStackTimer.start() })
                popup3.failed.connect(function() { popStackTimer.start() })

            } else {
                 let popup4 = PopupUtils.open(
                     Qt.resolvedUrl("ErrorMessage.qml"),
                     chatmailPage,
                     { text: i18n.tr("Error")
                 })
                setTempContextNull()
            }
        }
    }

    header: PageHeader {
        id: header
        title: i18n.tr("Your Profile")

        leadingActionBar.actions: [
            Action {
                //iconName: 'close'
                iconSource: "qrc:///assets/suru-icons/go-previous.svg"
                text: i18n.tr('Back')
                onTriggered: {
                    onClicked: popStackTimer.start()
                }
            }
        ]

//        //trailingActionBar.numberOfSlots: 2
//        trailingActionBar.actions: [
//            Action {
//                //iconName: 'ok'
//                iconSource: "qrc:///assets/suru-icons/ok.svg"
//                text: i18n.tr('OK')
//                onTriggered: {
//                }
//            }
//        ]
    }

    Flickable {
        id: flickable

        anchors {
            top: header.bottom
            topMargin: units.gu(2)
            bottom: parent.bottom
            bottomMargin: units.gu(2)
            left: parent.left
            right: parent.right
        }

        contentHeight: flickColumn.height

        Column {
            id: flickColumn
            width: parent.width > units.gu(54) ? units.gu(50) : (parent.width - units.gu(4))
            spacing: units.gu(1.5)
            anchors.horizontalCenter: parent.horizontalCenter

            UbuntuShape {
                id: profilePic
                width: units.gu(15)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                color: "grey"
                sourceFillMode: UbuntuShape.PreserveAspectCrop
                source: profilePicImage.status !== Image.Null && profilePicImage.status !== Image.Error ? profilePicImage : undefined

                Image {
                    id: profilePicImage
                    visible: false
                }

                Rectangle {
                    // ugly hack to be able to position
                    // editImageShape with an offset of 
                    // just units.gu(1)
                    id: positionHelperEditImage
                    height: units.gu(2)
                    width: height
                    anchors {
                        verticalCenter: profilePic.top
                        horizontalCenter: profilePic.right
                    }
                    color: theme.palette.normal.background
                }

                UbuntuShape {
                    id: editImageShape
                    height: units.gu(4)
                    width: height
                    anchors {
                        top: positionHelperEditImage.top
                        right: positionHelperEditImage.right
                    }
                    //color: theme.palette.normal.background
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                    Icon {
                        anchors.fill: parent
                        //name: "edit"
                        source: "qrc:///assets/suru-icons/edit.svg"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            PopupUtils.open(componentProfilePicActions, editImageShape)
                        }
                    }
                }
            }


            Column {
                width: parent.width
                spacing: units.gu(0.3)

                Label {
                    id: usernameLabel
                    text: i18n.tr("Your Name")
                }

                TextField {
                    id: usernameField
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    // When clicking into the TextField, the keyboard appears and
                    // obstructs the TextField. The Flickable can be shifted so the
                    // bottom is visible by
                    // flickable.contentY = flickable.contentHeight - flickable.height
                    // However, when instructing this directly in onActiveFocusChanged,
                    // it doesn't work because flickable.height is still the old height
                    // without the change caused by the keyboard. Waiting for 200 ms
                    // via flickTimer and then changing the flickable Y position works.
                    // Only do this on mobile where an OSK is visible (i.e., on UT, only
                    // if the sidebar is not visible. On non-UT, if oskViaDbus is true).
                    // TODO: Is there a signal when the keyboard appears? This would be
                    // much cleaner than using a timer.
                    //
                    // works with activeFocus or with focus
                    //onActiveFocusChanged: {
                    onFocusChanged: {
                        if (focus) {
                            pleaseEnterNameLabel.visible = false

                            if (root.onUbuntuTouch && !root.showAccSwitchSidebar) {
                                flickTimer.start()
                            }
                        }

                        if (root.oskViaDbus) {
                            if (focus) {
                                DeltaHandler.openOskViaDbus()
                                flickTimer.start()
                            } else {
                                DeltaHandler.closeOskViaDbus()
                            }
                        }
                    }
                }
            }

            Label {
                id: pleaseEnterNameLabel
                width: parent.width
                text: i18n.tr("Please enter a name.")
                wrapMode: Text.WordWrap
                color: theme.palette.normal.negative
                visible: false
            }

            Label {
                id: explainLabel
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("Set a name that your contacts will recognize. You can also set a profile image.")
                wrapMode: Text.WordWrap
            }

            Label {
                id: privacyLinkLabel
                width: parent.width
                text: {
                    if (isDcLogin) {
                        return i18n.tr("Log into \"%1\"?").arg(provider)
                    } else {
                        if (provider === "nine.testrun.org") {
                            return "<a href=\"https://" + provider + "/privacy.html\">" + i18n.tr("Privacy Policy for %1").arg(provider) + "</a>"
                        } else {
                            return "<a href=\"https://" + provider + "/privacy.html\">" + i18n.tr("About profiles on %1").arg(provider) + "</a>"
                        }
                    }
                }
                wrapMode: Text.WordWrap
                linkColor: root.darkmode ? "#9999ff" : "#0000ff"
                onLinkActivated: Qt.openUrlExternally(link)
            }

            Button {
                id: continueButton
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                text: isDcLogin ? i18n.tr("Log In") : i18n.tr("Agree & Create Profile")
                color: theme.palette.normal.positive
                onClicked: {
                    usernameField.focus = false
                    if (usernameField.text === "") {
                        pleaseEnterNameLabel.visible = true
                    } else {
                        DeltaHandler.continueQrCodeAction()
                        // next actions will be done once the signal
                        // finishedSetConfigFromQr is received
                    }
                }
            }

            Button {
                id: otherServerButton
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("Use Other Server")
                onClicked: {
                    let popup5 = PopupUtils.open(Qt.resolvedUrl("UseOtherServerPopup.qml"), chatmailPage)
                    popup5.listChatmailServer.connect(function() {
                        PopupUtils.close(popup5)
                        Qt.openUrlExternally("https://delta.chat/de/chatmail")
                    })
                    popup5.classicMailLogin.connect(function() {
                        PopupUtils.close(popup5)
                        extraStack.push(Qt.resolvedUrl("AddOrConfigureEmailAccount.qml"))
                    })
                    popup5.scanInvitationCode.connect(function() {
                        PopupUtils.close(popup5)
                        extraStack.push(Qt.resolvedUrl("QrScanner.qml"))
                    })
                    popup5.cancelled.connect(function() {
                        PopupUtils.close(popup5)
                    })
                } 
            }

        } // Column id: flickColumn

        Timer {
            id: flickTimer
            interval: 200
            repeat: false
            triggeredOnStart: false
            onTriggered: {
                // Calculate Y value of the TextField that the user is about
                // to enter something. Y value means the number of pixels
                // from the top of the Flickable content to the bottom of the TextField.
                let fieldBottomY = profilePic.height + usernameLabel.height + usernameField.height + units.gu(1)

                // Check if the TextField is shown on the screen. This is the
                // case if the height of the flickable is not less than
                // the Y value of the TextField minus flickable.contentY (contentY
                // is the offset to which the flickable has been flicked up, i.e.,
                // the number of pixels at the top of the flickable that are not
                // visible at the moment).
                if (flickable.height < fieldBottomY - flickable.contentY) {
                    // this will flick up so the TextField is right at the bottom
                    flickable.contentY = fieldBottomY - flickable.height
                }
            }
        }
    } // Flickable

    Timer {
        id: clearStackTimer
        interval: 300
        repeat: false
        triggeredOnStart: false
        onTriggered: extraStack.clear()
    }

    Timer {
        id: popStackTimer
        interval: 300
        repeat: false
        triggeredOnStart: false
        onTriggered: extraStack.pop()
    }

    Component {
        id: componentProfilePicActions
        Popover {
            id: popoverProfilePicActions
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
                    // Ubuntu.Components.Themes 1.3 doesn't solve it). 
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout1
                        title.text: i18n.tr("Select Profile Image")
                    }
                    
                    onClicked: {
                        PopupUtils.close(popoverProfilePicActions)

                        if (root.onUbuntuTouch) {
                            DeltaHandler.newFileImportSignalHelper()
                            DeltaHandler.fileImportSignalHelper.fileImported.connect(chatmailPage.setProfilePic)
                            extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })
                            // See comments in CreateOrEditGroup.qml
                            //let incubator = layout.addPageToCurrentColumn(chatmailPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })

                            //if (incubator.status != Component.Ready) {
                            //    // have to wait for the object to be ready to connect to the signal,
                            //    // see documentation on AdaptivePageLayout and
                            //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                            //    incubator.onStatusChanged = function(status) {
                            //        if (status == Component.Ready) {
                            //            incubator.object.fileSelected.connect(chatmailPage.setProfilePic)
                            //        }
                            //    }
                            //} else {
                            //    // object was directly ready
                            //    incubator.object.fileSelected.connect(chatmailPage.setProfilePic)
                            //}
                        } else {
                            chatmailPage.openFileDialog()
                        }
                    }
                } // ListItem

                ListItem {
                    height: layout2.height
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    enabled: profilePicImage.source != ""
                    ListItemLayout {
                        id: layout2
                        title.text: i18n.tr("Delete Profile Image")
                    }
                    onClicked: {
                        PopupUtils.close(popoverProfilePicActions)
                        profilePicImage.source = ""
                    }
                }
            }
        } // Popover id: containerLayout
    } // Component id: popoverChatPicActions
} // Page id: chatmailPage
