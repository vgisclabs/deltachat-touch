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
import Ubuntu.Components 1.3
import QtWebEngine 1.8
import QtWebChannel 1.0
import Qt.labs.platform 1.1
import Ubuntu.Components.Popups 1.3

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
        webxdcengineprofile.finishedConfiguringInstance.connect(function() {webview.url = "webxdcfilerequest://localhost/12369813asd18935zas123123a"})
        webxdcengineprofile.urlReceived.connect(receiveUrlFromWebxdc)

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

    function receiveUrlFromWebxdc(urlFromApp) {
        // handling of arguments/urls is based on the code for
        // QR scanning, thus the names with "qr"
        
        // Determine the type of the url. In this case,
        // we already know it's either mailto or openpgp4fpr,
        // but evaluateQrCode() still has to be called to set
        // some things on C++ side. Also, it will check for
        // erors in the url.
        let qrtype = DeltaHandler.evaluateQrCode(urlFromApp)

        switch (qrtype) {
            case DeltaHandler.DT_QR_ASK_VERIFYCONTACT: // fallthrough
            case DeltaHandler.DT_QR_ADDR:
                console.log("webxdcPage.receiveUrlFromWebxdc(): qr state is DT_QR_ASK_VERIFYCONTACT or DT_QR_ADDR")

                let popup = PopupUtils.open(
                    Qt.resolvedUrl('ConfirmDialog.qml'),
                    webxdcPage,
                    { "dialogText": i18n.tr("Chat with %1?").arg(DeltaHandler.getQrContactEmail()),
                      "confirmButtonPositive": true })       
                popup.confirmed.connect(function() {
                    extraStack.clear()
                    DeltaHandler.continueQrCodeAction(true)
                })
                break;
                
            case DeltaHandler.DT_QR_ASK_VERIFYGROUP:
                console.log("webxdcPage.receiveUrlFromWebxdc(): qr state is DT_QR_ASK_VERIFYGROUP")
                let popup9 = PopupUtils.open(
                    Qt.resolvedUrl("ConfirmDialog.qml"),
                    webxdcPage,
                    { dialogText: i18n.tr("Do you want to join the group \"%1\"?").arg(DeltaHandler.getQrTextOne()),
                      "confirmButtonPositive": true  })
                popup9.confirmed.connect(function() {
                    extraStack.clear()
                    DeltaHandler.continueQrCodeAction(true)
                })
                break;

            case DeltaHandler.DT_QR_ERROR:
                console.log("webxdcPage.receiveUrlFromWebxdc(): qr state is DT_QR_ERROR")
                let popup15 = PopupUtils.open(
                    Qt.resolvedUrl("ErrorMessage.qml"),
                    webxdcPage,
                    { text: i18n.tr("Error: %1").arg(DeltaHandler.getQrTextOne()),
                      title: i18n.tr("Error") })
                break;

            case DeltaHandler.DT_UNKNOWN: // fallthrough
            default:
                // If this appears in the log, the url/argument may not be something
                // unknown to the core, but it's just none of the cases that
                // we handle here (although at the moment, only mailto: and openpgp4fpr:
                // should come through from a Webxdc app, so this code should never be
                // reached as errors should be handled via DT_QR_ERROR above)
                console.log("webxdcPage.receiveUrlFromWebxdc(): Don't know how to handle argument \"", urlFromApp, "\", passed from Webxdc app, not doing anything")
                let popup14 = PopupUtils.open(
                    Qt.resolvedUrl("ErrorMessage.qml"),
                    webxdcPage,
                    { text: i18n.tr("Unknown"),
                      title: i18n.tr("Error") })
                break;
        }
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
        zoomFactor: root.onUbuntuTouch && !root.isDesktopMode ? 3.0 : 1.0

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
