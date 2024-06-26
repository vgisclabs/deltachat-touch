/*
 * Copyright (C) 2023, 2024  Lothar Ketterer
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
 *
 *
 * For the communication between JS, QML and C++ via WebChannel,
 * code from the blog article
 * https://decovar.dev/blog/2018/07/14/html-from-qml-over-webchannel-websockets/#webengineview---direct-webchannel
 * licensed under GPLv3 was used
 */

import QtQuick 2.12
import Lomiri.Components 1.3
import QtWebEngine 1.8
import QtWebChannel 1.0
import Qt.labs.platform 1.1

import DeltaHandler 1.0
import WebxdcEngineProfile 1.0

Page {
    id: webxdcPage

    property string headerTitle
    property string username
    property string useraddress

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
    }

    Component.onCompleted: {
        webview.javaScriptConsoleMessage.connect(printJsConsoleMsg)
        DeltaHandler.chatmodel.newWebxdcInstanceData.connect(webxdcengineprofile.configureNewInstance)
        DeltaHandler.chatmodel.updateCurrentWebxdc.connect(webxdcUpdate)
        
        // WebxdcSchemeHandler will return qrc:///assets/webxdc/wrapper.html for this url
        webxdcengineprofile.finishedConfiguringInstance.connect(function() {webview.url = "webxdcfilerequest:12369813asd18935zas123123a"})

        DeltaHandler.chatmodel.sendWebxdcInstanceData()
    }

    Component.onDestruction: {
        // it's needed for some reason to disconnect these signal/slots,
        // otherwise at least the webxdcUpdate connection will remain
        // (and a new one will be added each time the page is opened)
        DeltaHandler.chatmodel.newWebxdcInstanceData.disconnect(webxdcengineprofile.configureNewInstance)
        DeltaHandler.chatmodel.updateCurrentWebxdc.disconnect(webxdcUpdate)
    }

    function printJsConsoleMsg(level, message, lineNo, sourceId) {
        console.log("Output from WebEngineView JS document ", sourceId, ": ", message)
    }

    function webxdcUpdate() {
        webview.runJavaScript("window.__webxdcUpdate()")
    }

    QtObject {
        id: internalJsApi

        WebChannel.id: "intJsApi"

        property string selfAddr: webxdcPage.useraddress
        property string selfName: webxdcPage.username

        function sendStatusUpdate(update, descr) {
            DeltaHandler.chatmodel.sendWebxdcUpdate(update, descr)
        }

        function getStatusUpdates(last_serial) {
            return DeltaHandler.chatmodel.getWebxdcUpdate(last_serial)
        }

        function sendToChat(data) {
            // TODO
            console.log("cppside.sendToChat() called, but not implemented yet");
            return "cppside: sendToChat() not implemented yet";
        }
    }

    WebChannel {
        id: channel
        registeredObjects: [internalJsApi]
    }

    WebEngineView {
        id: webview
        anchors {
            top: header.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        zoomFactor: root.onUbuntuTouch ? 3.0 : 1.0

        userScripts: [
            WebEngineScript {
                injectionPoint: WebEngineScript.DocumentCreation
                sourceUrl: "qrc:///qtwebchannel/qwebchannel.js"
                worldId: WebEngineScript.MainWorld
            },

            WebEngineScript {
                injectionPoint: WebEngineScript.DocumentReady
                worldId: WebEngineScript.MainWorld
                sourceUrl: "qrc:///assets/webxdc/cppside.js"
                name: "cppside.js"
            }
        ]

        webChannel: channel

        settings {
            allowGeolocationOnInsecureOrigins: false
            autoLoadImages: true
            defaultTextEncoding: "UTF-8"
            dnsPrefetchEnabled: false
            hyperlinkAuditingEnabled: false
            javascriptCanAccessClipboard: false
            javascriptEnabled: true
            localContentCanAccessFileUrls: false
            localContentCanAccessRemoteUrls: false
            localStorageEnabled: true
            unknownUrlSchemePolicy: WebEngineSettings.DisallowUnknownUrlSchemes
        }

        profile: WebxdcEngineProfile {
            id: webxdcengineprofile

            offTheRecord: false
        }
    }
} // end Page id: webxdcPage
