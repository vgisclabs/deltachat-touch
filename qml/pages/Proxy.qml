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
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

import DeltaHandler 1.0

Page {
    id: proxyPage

    // Adapting the proxy settings for the currently active context (via
    // clicking on the shield icon in the chatlist view or via Advanced
    // Settings) is done directly via [get|set]currentConfig()
    // Proxy settings for a to be created account or for an account
    // that is configured from the account switcher uses the DeltaHandler
    // "tempProxy" getters/setters.
    property bool forCurrentContext: true

    property string connectivityText

    // see comments in Main.qml re QR code + URL handling
    property string oldUrlHandlingPage
    readonly property string thisPagePath: "qml/Proxy"

    header: PageHeader {
        id: header
        title: i18n.tr("Proxy")

        leadingActionBar.actions: [
            Action {
                //iconName: "go-previous"
                iconSource: "qrc:///assets/suru-icons/go-previous.svg"
                text: i18n.tr("Back")
                onTriggered: {
                    extraStack.pop()
                }
            }
        ]
    }

    Connections {
        target: root
        onUnprocessedUrl: {
            processUrl(rawUrl)
        }
    }

    Component.onCompleted: {
        oldUrlHandlingPage = root.urlHandlingPage
        root.urlHandlingPage = thisPagePath

        proxySwitch.checked = forCurrentContext ? DeltaHandler.useProxy : DeltaHandler.isTempProxyEnabled()

        if (forCurrentContext) {
            updateConnectivity()
        }

        // build up proxymodel
        let proxylistString = forCurrentContext ? DeltaHandler.getCurrentConfig("proxy_url") : DeltaHandler.getTempProxyUrls()
        if (proxylistString !== "") {
            let proxyArray = proxylistString.split('\n')

            for (let i = 0; i < proxyArray.length; i++) {
                let currentEntry = proxyArray[i]
                let qrstate = DeltaHandler.evaluateQrCode(currentEntry)

                if (qrstate === DeltaHandler.DT_QR_PROXY) {
                    let proxytype = currentEntry.split(":")[0]
                    proxymodel.append({ address: DeltaHandler.getQrTextOne(), type: proxytype, fullstring: currentEntry })
                } else if (qrstate === DeltaHandler.DT_QR_ERROR) {
                    console.log("Proxy.qml: ERROR building up list of proxies. Evaluation of entry #", i, " with text ", currentEntry, " gave the following error: ", DeltaHandler.getQrTextOne())
                    proxymodel.append({ address: "ERROR", type: "ERROR", fullstring: currentEntry })
                } else {
                    console.log("Proxy.qml: ERROR building up list of proxies. Evaluation of entry #", i, " with text ", currentEntry, " was not evaluated as proxy")
                    proxymodel.append({ address: "ERROR", type: "ERROR", fullstring: currentEntry })
                }
            }
            // append one extra item to take care of the "missing divider", see comment
            // for proxymodel below
            proxymodel.append({ address: "", type: "", fullstring: "" })
        }
    }

    Component.onDestruction: {
        root.urlHandlingPage = oldUrlHandlingPage
    }

    function updateConnectivity() {
        if (forCurrentContext) {
            let conn = DeltaHandler.getConnectivitySimple()
            if (conn >= 1000 && conn < 2000) {
                connectivityText = i18n.tr("Not connected")
            } else if (conn >= 2000 && conn < 3000) {
                connectivityText = i18n.tr("Connecting…")
            } else if (conn >= 3000 && conn < 4000) {
                connectivityText = i18n.tr("Updating…")
            } else if (conn >= 4000) {
                connectivityText = i18n.tr("Connected")
            } else {
                connectivityText = "??"
            }
        }
    }

    // Writes the proxy list to the core config
    function updateCoreProxyList() {
        let newProxyString = ""
        // Beware: proxymodel contains a dummy element at the end
        for (let i = 0; i < proxymodel.count - 1; i++) {
            newProxyString += proxymodel.get(i).fullstring
            if (i < proxymodel.count - 2) {
                newProxyString += "\n"
            }
        }

        // Setting the new proxy string
        forCurrentContext ? DeltaHandler.setCurrentConfig("proxy_url", newProxyString) : DeltaHandler.setTempProxyUrls(newProxyString)

        if (newProxyString === "" && proxySwitch.checked) {
            proxySwitch.checked = false
        }
    }

    // Checks if a proxy url is already in the list. If yes,
    // it moves it to the beginning of the list. If not, it
    // adds it to the beginning of the list.
    function addOrActivateEntry(newProxyUrl) {
        // socks5 url might have been provided without port, check
        // and add default port 1080, if needed. Has to be done
        // before checking if the url is already in the list.
        let splittedProxyUrl = newProxyUrl.split(":")
        let proxytype = splittedProxyUrl[0]
        let hasPort = false

        if (proxytype === "socks5") {
            // format is socks5://[user[:pass]@][host[:port]]
            if (newProxyUrl.includes("@")) {
                // get the part after "@" and check if splitting with
                // ":" results in more than 1 subsection; if yes, it
                // contains the port part
                let afterAt = newProxyUrl.split("@")[1]
                let splittedAfterAt = afterAt.split(":")
                if (splittedAfterAt.length > 1) {
                    hasPort = true
                }
            } else {
                // If there's no "@", splitting with ":" results in 
                // 3 parts if it already contains a port
                if (splittedProxyUrl.length > 2) {
                    hasPort = true
                }
            }

            if (!hasPort) {
                newProxyUrl += ":1080"
            }
        }

        // check if the url is already in the list
        let alreadyInList = false
        // count - 1 due to the dummy element at the end
        for (let i = 0; i < proxymodel.count - 1; i++) {
            if (proxymodel.get(i).fullstring === newProxyUrl) {
                alreadyInList = true
                // Nothing to do if Url is already at the beginning of
                // the list (check if proxy is enabled will be done
                // later)
                if (i !== 0) {
                    // It's not at the beginning, move it there
                    proxymodel.move(i, 0, 1)
                    updateCoreProxyList()
                }
                break
            }
        }

        if (!alreadyInList) {
            proxymodel.insert(0, { address: DeltaHandler.getQrTextOne(), type: proxytype, fullstring: newProxyUrl })
            if (proxymodel.count == 1) {
                // need to add the dummy element
                proxymodel.append({ address: "", type: "", fullstring: "" })
            }
            updateCoreProxyList()
        }

        if (!proxySwitch.checked) {
            // Call to core and restarting IO will be done in onCheckedChanged
            proxySwitch.checked = true
        }
    }

    // Checks if the parameter newProxyUrl is a proxy url, and if yes,
    // adds it to the proxy list. If checkfirst is true, the user is
    // asked for confirmation.
    function checkAndAddProxy(newProxyUrl, checkfirst = false) {
        let qrstate = DeltaHandler.evaluateQrCode(newProxyUrl)

        if (qrstate === DeltaHandler.DT_QR_PROXY) {
            if (checkfirst) {
                let popup3 = PopupUtils.open(
                    Qt.resolvedUrl('ConfirmDialog.qml'),
                    proxyPage,
                    { "dialogText": i18n.tr('Do you want to use proxy %1?').arg(newProxyUrl),
                      "okButtonText": i18n.tr("Use Proxy"),
                      "confirmButtonPositive": true }
                )
                popup3.confirmed.connect(function() {
                    addOrActivateEntry(newProxyUrl)
                })
                popup3.cancelled.connect(function() {
                    // need to uncheck the proxy setting if there's no proxy defined yet
                    if (proxymodel.count === 0) {
                        proxySwitch.checked = false
                    }
                })
            } else {
                addOrActivateEntry(newProxyUrl)
            }
        } else {
            PopupUtils.open(
                Qt.resolvedUrl("ErrorMessage.qml"),
                proxyPage,
                { "text": i18n.tr("Invalid or unsupported proxy")
            })

            // need to uncheck the proxy setting if there's no proxy defined yet
            if (proxymodel.count === 0) {
                proxySwitch.checked = false
            }
        }
    }

    function processUrl(urlstring) {
        if (root.urlHandlingPage !== thisPagePath) {
            return
        } else {
            checkAndAddProxy(urlstring, true)
        }
    }

    Connections {
        enabled: forCurrentContext
        target: DeltaHandler

        onConnectivityChangedForActiveAccount: {
            updateConnectivity()
        }
    }

    Connections {
        enabled: forCurrentContext
        target: root
        onIoChanged: {
            updateConnectivity()
        }
    }

    ListItemActions {
        id: leadingProxyAction
        actions: Action {
            //iconName: "delete"
            iconSource: "qrc:///assets/suru-icons/delete.svg"
            text: i18n.tr("Delete")
            onTriggered: {
                // Don't to anything if it's the dummy element.
                // The index is passed as parameter and can
                // be accessed via 'value'.
                if (value === proxymodel.count - 1) {
                    return
                }

                let popup1 = PopupUtils.open(
                    Qt.resolvedUrl('ConfirmDialog.qml'),
                    proxyPage,
                    { "dialogTitle": i18n.tr("Delete Proxy"),
                      "dialogText": i18n.tr('Are you sure you want to delete %1?').arg(proxymodel.get(value).address),
                      "okButtonText": i18n.tr("Delete Proxy")}
                )
                popup1.confirmed.connect(function() {
                    proxymodel.remove(value)
                    if (proxymodel.count == 1) {
                        proxymodel.clear()
                    }
                    updateCoreProxyList()
                })
            }
        }
    }

    ListItemActions {
        id: trailingProxyAction
        actions: [
            Action {
                //iconName: "share"
                iconSource: "qrc:///assets/suru-icons/share.svg"
                text: i18n.tr("Share")
                onTriggered: {
                    // Don't to anything if it's the dummy element.
                    if (value === proxymodel.count - 1) {
                        return
                    }

                    let proxystring = proxymodel.get(value).fullstring
                    let popup5 = PopupUtils.open(
                        Qt.resolvedUrl('ProxyShareDialog.qml'),
                        proxyPage,
                        { "proxyUrl": proxystring }
                    )
                }
            }
        ]
    }

    ListModel {
        id: proxymodel

        // If there's at least one proxy element in this model, the model also
        // contains a dummy element at the end of the model that only serves to
        // work around a bug in the display of dividers in ListView: Even if
        // divider.visible is explicitly set to true, the last element in a
        // ListView will be shown without divider at the bottom. When
        // re-sorting the elements of the view, the visibility of the divider
        // will not be re-evaluated. Thus, if the previously last element in a
        // ListView is moved to another position, it will still be shown
        // without divider.
        //
        // To counter this, a dummy element is inserted at the end, ensuring
        // that the divider of the last actual element is always shown. Code
        // that works on the elements of this model has to take this into
        // account. When creating the model, the dummy element has to be added.
        // When the last actual element of the model is removed, the dummy
        // element has to be removed as well.
    }

    ListItem {
        id: switchItem
        height: proxyEnabledLayout.height + (divider.visible ? divider.height : 0)
        width: proxyPage.width

        anchors {
            top: header.bottom
            left: parent.left
        }

        ListItemLayout {
            id: proxyEnabledLayout
            title.text: i18n.tr("Use Proxy")
            title.font.pixelSize: scaledFontSizeInPixels

            Switch {
                id: proxySwitch
                SlotsLayout.position: SlotsLayout.Trailing
                onCheckedChanged: {
                    // avoid action if it's not actually causing a change in the saved config
                    let actionNeeded
                    if (forCurrentContext) {
                        actionNeeded = (proxySwitch.checked !== DeltaHandler.useProxy) ? true : false
                    } else {
                        actionNeeded = (proxySwitch.checked !== DeltaHandler.isTempProxyEnabled()) ? true : false
                    }

                    if (actionNeeded) {
                        if (proxySwitch.checked) {
                            forCurrentContext ? DeltaHandler.setCurrentConfig("proxy_enabled", "1") : DeltaHandler.setTempProxyEnabled(true)
                        } else {
                            forCurrentContext ? DeltaHandler.setCurrentConfig("proxy_enabled", "0") : DeltaHandler.setTempProxyEnabled(false)
                        }

                        if (proxySwitch.checked && proxymodel.count === 0) {
                            newProxyButton.clicked()
                        }
                    }
                }
            }
        }
    }

    Button {
        id: newProxyButton
        anchors {
            top: switchItem.bottom
            topMargin: units.gu(2)
            left: parent.left
            leftMargin: units.gu(2)
        }
        text: i18n.tr("Add Proxy")
        font.pixelSize: scaledFontSizeInPixels

        onClicked: {
            let popup2 = PopupUtils.open(Qt.resolvedUrl("ProxyEnterDialog.qml"))
            popup2.proxyEntered.connect(function(newproxy) {
                checkAndAddProxy(newproxy, false)
            })
            popup2.proxyFromClipboard.connect(function(newproxy) {
                checkAndAddProxy(newproxy, true)
            })
            popup2.scanRequested.connect(function() {
                let scannerPage = extraStack.push(Qt.resolvedUrl("QrScanner.qml"))
                scannerPage.cancelled.connect(function() {
                    // need to uncheck the proxy setting if the user cancels
                    // scanning and there's no proxy defined yet
                    if (proxymodel.count === 0) {
                        proxySwitch.checked = false
                    }
                })
            })
            popup2.cancelled.connect(function() {
                if (proxymodel.count === 0) {
                    proxySwitch.checked = false
                }
            })
        }

    }


    Label {
        id: viewLabel
        anchors {
            top: newProxyButton.bottom
            topMargin: units.gu(2)
            horizontalCenter: parent.horizontalCenter
        }

        text: i18n.tr("Saved Proxies")
        font.bold: true
        fontSize: root.scaledFontSize
    }

    ListItem {
        id: dividerItem
        height: divider.height
        width: parent.width
        anchors {
            top: viewLabel.bottom
            topMargin: units.gu(1)
            left: parent.left
        }
    }

    ListView {
        id: proxyview
        width: proxyPage.width
        height: proxyPage.height - header.height - switchItem.height - viewLabel.height - newProxyButton.height - units.gu(5)
        clip: true 
        anchors {
            top: dividerItem.bottom
            left: parent.left
        }
        model: proxymodel
        delegate: ListItem {
            height: index === proxymodel.count - 1 ? divider.height : (delegateLayout.height + (divider.visible ? divider.height : 0))
            width: proxyview.width
            leadingActions: leadingProxyAction
            trailingActions: trailingProxyAction

            onClicked: {
                if (index !== 0 && index !== proxymodel.count - 1) {
                    proxymodel.move(index, 0, 1)
                    updateCoreProxyList()

                    if (!proxySwitch.checked) {
                        proxySwitch.checked = true
                    }
                }
            }

            ListItemLayout {
                id: delegateLayout
                title.text: index === proxymodel.count - 1 ? "" : model.address
                title.font.pixelSize: scaledFontSizeInPixels
                subtitle.text: (index === proxymodel.count - 1) ? "" : ("[" + model.type + "]" + (forCurrentContext && index === 0 && proxySwitch.checked ? (" " + connectivityText) : ""))
                subtitle.font.pixelSize: scaledFontSizeInPixelsSmaller

                Icon {
                    source: "qrc:///assets/suru-icons/tick.svg"
                    color: delegateLayout.title.color
                    width: units.gu(3)
                    //height: width
                    visible: index === 0 && proxySwitch.checked
                }
            }
        }
    }
} // end Page id: proxyPage
