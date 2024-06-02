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
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
import QtWebEngine 1.8
import Qt.labs.platform 1.1

import DeltaHandler 1.0
import DTWebEngineProfile 1.0

Page {
    id: htmlViewPage

    anchors.fill: parent

    property string htmlPath
    property string headerTitle
    property bool remoteContentIsBlocked: false
    property bool overrideAndBlockAlwaysLoadRemote: true
    property bool loadRemoteButtonPressed: false
    property bool menuOpened: false

    header: PageHeader {
        id: header
        title: headerTitle

        leadingActionBar.actions: [
            Action {
                //iconName: "close"
                iconSource: "qrc:///assets/suru-icons/close.svg"
                text: i18n.tr("Close")
                onTriggered: {
                    extraStack.pop()
                }
                // only allow leaving account configuration
                // if there's a configured account
                visible: DeltaHandler.hasConfiguredAccount
            }
        ]
    }

    Component.onCompleted: {
        if (root.alwaysLoadRemoteContent && !overrideAndBlockAlwaysLoadRemote) {
            webengineprofile.setRemoteContentAllowed(true)
            webview.reload()
        }
    }

    Rectangle {
        id: loadRemoteRect

        width: htmlViewPage.width
        height: (row1Loader.active ? row1Loader.height : 0) + (row2Loader.active ? row2Loader.height : 0)

        anchors {
            top: header.bottom
            left: parent.left
        }

        color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

        Loader {
            id: row1Loader
            active: htmlViewPage.remoteContentIsBlocked && !htmlViewPage.loadRemoteButtonPressed && (!root.alwaysLoadRemoteContent || htmlViewPage.overrideAndBlockAlwaysLoadRemote)

            anchors {
                left: parent.left
                leftMargin: units.gu(2)
                top: parent.top
            }

            sourceComponent: Rectangle {
                id: row1Rect
                width: loadRemoteRect.width - units.gu(4)
                height: loadRemoteContentButton.height + units.gu(2)

                anchors {
                    left: parent.left
                    top: parent.top
                }

                color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                Button {
                    id: loadRemoteContentButton

                    anchors {
                        top: parent.top
                        topMargin: units.gu(1)
                        left: parent.left
                    }

                    text: i18n.tr("Load Remote Images")
                    color: theme.palette.normal.negative

                    onTriggered: {
                        webengineprofile.setRemoteContentAllowed(true)
                        webview.reload()
                        htmlViewPage.loadRemoteButtonPressed = true
                    }
                }

                Rectangle {
                    id: menuIconCage
                    height: loadRemoteContentButton.height
                    width: height

                    visible: !htmlViewPage.overrideAndBlockAlwaysLoadRemote

                    anchors {
                        verticalCenter: parent.verticalCenter
                        right: parent.right
                    }

                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                    Icon {
                        width: parent.width - units.gu(1)

                        anchors {
                            verticalCenter: parent.verticalCenter
                            horizontalCenter: parent.horizontalCenter
                        }

                        //name: "navigation-menu"
                        source: "qrc:///assets/suru-icons/navigation-menu.svg"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            htmlViewPage.menuOpened = !htmlViewPage.menuOpened
                        }
                    }
                }
            }
        }

        Loader {
            id: row2Loader
            active: (root.alwaysLoadRemoteContent && !htmlViewPage.overrideAndBlockAlwaysLoadRemote) || htmlViewPage.menuOpened

            anchors {
                left: parent.left
                leftMargin: units.gu(2)
                bottom: parent.bottom
            }

            sourceComponent: Rectangle {
                id: row2Rect
                width: loadRemoteRect.width - units.gu(4)
                height: (alwaysLoadRemoteContentLabel.height > alwaysLoadRemoteContentSwitch.height ? alwaysLoadRemoteContentLabel.height : alwaysLoadRemoteContentSwitch.height) + units.gu(2)

                anchors {
                    left: parent.left
                    bottom: parent.bottom
                }

                color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

                Label {
                    id: alwaysLoadRemoteContentLabel

                    width: parent.width - alwaysLoadRemoteContentSwitch.width - units.gu(2)

                    anchors {
                        verticalCenter: alwaysLoadRemoteContentSwitch.verticalCenter
                        left: parent.left
                    }

                    text: i18n.tr("Always Load Remote Images")
                    elide: Text.ElideRight
                }

                Switch {
                    id: alwaysLoadRemoteContentSwitch
                    enabled: !htmlViewPage.overrideAndBlockAlwaysLoadRemote

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: units.gu(1)
                        right: parent.right
                    }

                    Component.onCompleted: {
                        checked = root.alwaysLoadRemoteContent
                    }
            
                    onCheckedChanged: {
                        // prevent action upon intially setting the switch
                        // in Component.onCompleted
                        if (checked != root.alwaysLoadRemoteContent) {
                            if (checked) {
                                let popup1 = PopupUtils.open(Qt.resolvedUrl("ConfirmAlwaysLoadRemoteContent.qml"))
                                popup1.confirmed.connect(function() {
                                    root.alwaysLoadRemoteContent = true
                                    if (!loadRemoteButtonPressed) {
                                        webengineprofile.setRemoteContentAllowed(true)
                                        webview.reload()
                                        htmlViewPage.loadRemoteButtonPressed = true
                                    }
                                })
                                popup1.cancelled.connect(function() {
                                    checked = false
                                })
                            } else {
                                root.alwaysLoadRemoteContent = false
                            }
                        }

                    }
                }
            }
        }
    }

    // Ideas and actual code in this webview taken from
    // DekkoWebView.qml, Copyright (C) 2014-2016 Dan Chapman
    // <dpniel@ubuntu.com>, licensed under GPLv3
    // https://gitlab.com/dekkan/dekko/-/blob/master/plugins/ubuntu-plugin/plugins/core/mail/webview/DekkoWebView.qml?ref_type=heads
    // modified by (C) 2023 Lothar Ketterer
    WebEngineView {
        id: webview
        anchors {
            top: loadRemoteRect.bottom
            topMargin: units.gu(1)
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        // For some reason, UT needs the zoom set to 3 to
        // reach around normal (= medium) font size.
        // TODO simplify the additional zoom according to
        // the scale level
        zoomFactor: (root.onUbuntuTouch ? 3.0 : 1.0) + (((root.scaleLevel - 2) < 0 ? 0 : (root.scaleLevel - 2)) / (root.onUbuntuTouch ? 1 : 2))
        url: htmlPath

        // Comments in the next lines as per original DekkoWebView.qml:
        // LOCK IT DOWN!!
        // incognito: true can't set his as it disables userscripts.
        settings {
            // We should NEVER allow javascript to run in
            // a message body. See https://miki.it/blog/2013/9/24/mailboxapp-javascript-execution/ for
            // how mailbox (by dropbox) got it wrong :-)
            // http://doc.qt.io/qt-5/qml-qtwebengine-webenginesettings.html
            javascriptEnabled: false
            javascriptCanAccessClipboard: false
            localContentCanAccessFileUrls: false
            autoLoadImages: true
            localStorageEnabled: false
            hyperlinkAuditingEnabled: false
            defaultTextEncoding: "UTF-8"
        }

        profile: DTWebEngineProfile {
            id: webengineprofile

            persistentCookiesPolicy: WebEngineProfile.NoPersistentCookies

            onRemoteContentBlocked: {
                remoteContentIsBlocked = true
            }
        }

        onNewViewRequested: {
            navigationRequested
        }

        onNavigationRequested: {
            if ((request.url.toString()).startsWith(StandardPaths.writableLocation(StandardPaths.CacheLocation)) || (request.url.toString()).startsWith(StandardPaths.writableLocation(StandardPaths.AppConfigLocation))) {
                request.action = WebEngineNavigationRequest.AcceptRequest // 0
            } else {
                PopupUtils.open(Qt.resolvedUrl('ConfirmOpenExternalUrl.qml'), htmlViewPage, {externalLink: request.url})
                request.action = WebEngineNavigationRequest.IgnoreRequest // 255
            }
        }

        // For an unknown reason, some links do not trigger
        // navigationRequested (same in Dekko). As a workaround, these
        // links are available via a long press, which triggers
        // contextMenuRequested. Only requests that contain an url are
        // handled via this slot.
        onContextMenuRequested: { 
            // Dekko doesn't check for linkUrl, but for linkText. But
            // isn't it better to check whether the url is non-empty
            // directly?
            if (request.linkUrl.toString() !== "") {
                request.accepted = true
                PopupUtils.open(Qt.resolvedUrl('ConfirmOpenExternalUrl.qml'), htmlViewPage, {externalLink: request.linkUrl})
            } // TODO: Maybe add a context menu component that copies text
              // to the clipboard if it's not an url and
              // request.selectedText is non-empty
        }
    }
} // end Page id: htmlViewPage
