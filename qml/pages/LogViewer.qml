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

    header: PageHeader {
        id: header
        title: i18n.tr("Log")

        trailingActionBar.actions: [
            Action {
                iconName: "reload"
                text: i18n.tr("Help")
                onTriggered: update()
            },
            
            Action {
                iconName: "save-as"
                text: i18n.tr("Save Log")
                onTriggered: {
                    let textToSave = logText.text
                    let saveFile = DeltaHandler.saveLog(textToSave, currentDateString)
                    let fullpath = StandardPaths.locate(StandardPaths.CacheLocation, saveFile)
                    layout.addPageToCurrentColumn(logViewerPage, Qt.resolvedUrl("PickerLogToExport.qml"), {"url": fullpath})
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
