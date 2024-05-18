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
import QtQml 2.12
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
//import QtWebEngine 1.8
import Qt.labs.platform 1.1

import DeltaHandler 1.0

// Idea + code taken in modified form from
// https://github.com/NeoTheThird/Logviewer/tree/master
// Copyright (C) 2017 - 2020 Jan Sprinz
// Copyright (C) 2014 - 2016 Victor Tuson Palau and Niklas Wenzel
// licensed under GPLv3

Page {
    id: logViewerPage

    property var locale: Qt.locale()
    property string currentDateString

    property var fullpath

    function showExportSuccess(exportedPath) {
        // Only for non-Ubuntu Touch platforms
        if (exportedPath === "") {
            // error, file was not exported
            PopupUtils.open(Qt.resolvedUrl("ErrorMessage.qml"),
            logViewerPage,
            // TODO: string not translated yet
            {"text": i18n.tr("File could not be saved") , "title": i18n.tr("Error") })
        } else {
            PopupUtils.open(Qt.resolvedUrl("InfoPopup.qml"),
            logViewerPage,
            // TODO: string not translated yet
            {"text": i18n.tr("Saved file ") + exportedPath })
        }
    }

    header: PageHeader {
        id: header
        title: i18n.tr("Log")

        Loader {
            // Only for non-Ubuntu Touch platforms
            id: fileExpLoader
        }

        Connections {
            // Only for non-Ubuntu Touch platforms
            target: fileExpLoader.item
            onFolderSelected: {
                let exportedPath = DeltaHandler.chatmodel.exportFileToFolder(fullpath, urlOfFolder)
                showExportSuccess(exportedPath)
                fileExpLoader.source = ""
            }
            onCancelled: {
                fileExpLoader.source = ""
            }
        }

        trailingActionBar.actions: [
            Action {
                iconSource: "../assets/media-skip-downwards.svg"
                text: i18n.tr("Scroll to the Bottom")
                onTriggered: scrollView.flickableItem.contentY = scrollView.flickableItem.contentHeight - scrollView.height
            },
            
            Action {
                //iconName: "reload"
                iconSource: "qrc:///assets/suru-icons/reload.svg"
                text: i18n.tr("Help")
                onTriggered: update()
            },
            
            Action {
                //iconName: "save-as"
                iconSource: "qrc:///assets/suru-icons/save-as.svg"
                text: i18n.tr("Save Log")
                onTriggered: {
                    let textToSave = logText.text
                    let saveFile = DeltaHandler.saveLog(textToSave, currentDateString)
                    fullpath = StandardPaths.locate(StandardPaths.CacheLocation, saveFile)

                    // different code depending on platform
                    if (root.onUbuntuTouch) {
                        extraStack.push(Qt.resolvedUrl("FileExportDialog.qml"), {"url": fullpath, "conType": DeltaHandler.FileType})
                    } else {
                        // non-Ubuntu Touch
                        fileExpLoader.source = "FileExportDialog.qml"

                        // TODO: String not translated yet
                        fileExpLoader.item.title = "Choose folder to save log"
                        fileExpLoader.item.setFileType(DeltaHandler.FileType)
                        fileExpLoader.item.open()
                    }
                }
            }
        ]
    }

    function update() {
        var xhr = new XMLHttpRequest;
        xhr.open("GET", StandardPaths.locate(StandardPaths.CacheLocation, "/logfile.txt"));
        xhr.onreadystatechange = function() {
            if (xhr.readyState == XMLHttpRequest.DONE && xhr.responseText) {
                var formatedText = xhr.responseText.replace(/\n/g, "\n\n")
                // to be able to save the file with the current date/time in its name
                logViewerPage.currentDateString = new Date().toLocaleString(locale, "yyyy_MM_dd-hh_mm_ss")
                logText.text = formatedText;
            }
        };
        xhr.send();
        scrollView.flickableItem.contentY = scrollView.flickableItem.contentHeight - scrollView.height
    }

    ScrollView {
        id: scrollView
        anchors {
            top: header.bottom
            topMargin: units.gu(1)
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        TextEdit {
            id: logText
            wrapMode: TextEdit.Wrap
            width: scrollView.width
            readOnly: true
            //font.pointSize: fontSize
            //font.family: "Ubuntu Mono"
            textFormat: TextEdit.PlainText
            textMargin: units.gu(2)
            color: theme.palette.normal.fieldText
            selectedTextColor: theme.palette.selected.selectionText
            selectionColor: theme.palette.selected.selection

            Component.onCompleted: logViewerPage.update();
        }
    }
} // end Page id: logViewerPage
