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
import Lomiri.Components.Popups 1.3
import QtQuick.Layouts 1.3
import QtWebEngine 1.8
import Qt.labs.platform 1.1

import DeltaHandler 1.0
import HtmlMsgEngineProfile 1.0

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
            }
        ]
        
        trailingActionBar.actions: [
            Action {
                //iconName: "zoom-in"
                iconSource: "qrc:///assets/suru-icons/zoom-in.svg"
                text: i18n.tr("Close")
                onTriggered: {
                    if (webview.zoomFactor > 4.4) {
                        webview.zoomFactor = 5.0
                    } else {
                        webview.zoomFactor += 0.5 
                    }
                }
            },
            Action {
                //iconName: "zoom-out"
                iconSource: "qrc:///assets/suru-icons/zoom-out.svg"
                text: i18n.tr("Close")
                onTriggered: {
                    if (webview.zoomFactor > 0.8) {
                        webview.zoomFactor -= 0.5 
                    }
                }
            }
        ]
    }

    Component.onCompleted: {
        if (root.alwaysLoadRemoteContent && !overrideAndBlockAlwaysLoadRemote) {
            webengineprofile.setRemoteContentAllowed(true)
            webview.reload()
        }
        webengineprofile.configureSchemehandler(DeltaHandler.getJsonrpcInstance(), DeltaHandler.getCurrentAccountId(), DeltaHandler.getJsonrpcRequestId())
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
                                let popup1 = PopupUtils.open(
                                    Qt.resolvedUrl('ConfirmDialog.qml'),
                                    htmlViewPage,
                                    { "dialogTitle": i18n.tr("Always Load Remote Images"),
                                      "dialogText": i18n.tr('Remote images can track you.\n\nThis setting also may load fonts and other content. If disabled, embedded or cached images may appear.\n\nLoad remote images?'),
                                      "okButtonText": i18n.tr("Load Remote Images") })

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

        profile: HtmlMsgEngineProfile {
            id: webengineprofile

            persistentCookiesPolicy: WebEngineProfile.NoPersistentCookies

            onRemoteContentBlocked: {
                remoteContentIsBlocked = true
            }
        }

        onNewViewRequested: {
            if (request.userInitiated) {
                PopupUtils.open(Qt.resolvedUrl('ConfirmOpenExternalUrl.qml'), htmlViewPage, {externalLink: request.requestedUrl})
            } else {
                console.log("MessageHtmlView.qml: Blocked non-userInitiated signal newViewRequest for ", request.requestedUrl)
            }
        }

        onNavigationRequested: {
            if ((request.url.toString()).startsWith(StandardPaths.writableLocation(StandardPaths.CacheLocation)) || (request.url.toString()).startsWith(StandardPaths.writableLocation(StandardPaths.AppConfigLocation))) {
                request.action = WebEngineNavigationRequest.AcceptRequest // 0
            } else {
                PopupUtils.open(Qt.resolvedUrl('ConfirmOpenExternalUrl.qml'), htmlViewPage, {externalLink: request.url})
                request.action = WebEngineNavigationRequest.IgnoreRequest // 255
            }
        }

        onContextMenuRequested: { 
            request.accepted = true

            if (request.selectedText !== "") {
                if (!contextMenuShape.visible) {
                    contextMenuShape.visible = true
                    contextMenuShape.x = webview.x + units.gu(10)
                    contextMenuShape.y = webview.y + units.gu(10)
                }
            } else if (request.linkUrl.toString() !== "") {
                contextMenuShape.visible = false
                PopupUtils.open(Qt.resolvedUrl('ConfirmOpenExternalUrl.qml'), htmlViewPage, {externalLink: request.linkUrl})
            }
        }
    }

    LomiriShape {
        // Allows to copy the currently selected text to the clipboard.
        //
        // Ideas for this shape taken from Morph Browser
        // https://gitlab.com/ubports/development/core/morph-browser
        // licensed under GPLv3 
        id: contextMenuShape

        backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6"
        width: actionShapeRow.width + units.gu(1)
        height: childrenRect.height

        visible: false

        MouseArea {
            // to catch clicks on edges of the shape and the spacing of the Row which would
            // otherwise go through to the underlying page as the space is not covered
            // by the MouseAreas of the Row children
            anchors.fill: parent
        }

        Row {
            id: actionShapeRow
            spacing: units.gu(3)

            anchors {
                top: parent.top
                left: parent.left
            }

            LomiriShape {
                width: gripIcon.width
                height: copyShape.height // height should be as for the other shapes
                backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6"
                aspect: LomiriShape.Flat
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: gripIcon
                    source: "qrc:///assets/suru-icons/grip-large.svg"
                    height: parent.height
                    width: units.gu(3)
                    fillMode: Image.PreserveAspectCrop

                    anchors {
                        top: parent.top
                        left: parent.left
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    drag.target: contextMenuShape
                    drag.axis: Drag.XAndYAxis
                }
            }

            LomiriShape {
                id: copyShape
                width: (copyIcon.width > copyLabel.contentWidth ? copyIcon.width : copyLabel.contentWidth)
                height: copyIcon.height + copyLabel.contentHeight + units.gu(1.5)
                backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6"
                aspect: LomiriShape.Flat

                Icon {
                    id: copyIcon
                    source: "qrc:///assets/suru-icons/edit-copy.svg"
                    height: units.gu(3)

                    anchors {
                        top: parent.top
                        topMargin: units.gu(0.5)
                        horizontalCenter: parent.horizontalCenter
                    }
                }

                Label {
                    id: copyLabel
                    anchors {
                        top: copyIcon.bottom
                        topMargin: units.gu(0.5)
                        horizontalCenter: parent.horizontalCenter
                    }
                    text: i18n.tr("Copy")
                    fontSize: "x-small"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        webview.triggerWebAction(WebEngineView.Copy)
                        contextMenuShape.visible = false
                    }
                }
            }
            
            LomiriShape {
                width: (closeIcon.width > closeLabel.contentWidth ? closeIcon.width : closeLabel.contentWidth)
                height: closeIcon.height + closeLabel.contentHeight + units.gu(1.5)
                backgroundColor: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6"
                aspect: LomiriShape.Flat

                Icon {
                    id: closeIcon
                    source: "qrc:///assets/suru-icons/close.svg"
                    height: units.gu(3)

                    anchors {
                        top: parent.top
                        topMargin: units.gu(0.5)
                        horizontalCenter: parent.horizontalCenter
                    }
                }

                Label {
                    id: closeLabel
                    anchors {
                        top: closeIcon.bottom
                        topMargin: units.gu(0.5)
                        horizontalCenter: parent.horizontalCenter
                    }
                    text: i18n.tr("Close")
                    fontSize: "x-small"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        contextMenuShape.visible = false
                    }
                }
            }
        }
    }
} // end Page id: htmlViewPage
