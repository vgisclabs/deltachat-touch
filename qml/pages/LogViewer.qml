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
import QtWebEngine 1.8
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: logViewerPage

    header: PageHeader {
        id: header
        title: i18n.tr("Log")
    }

    WebEngineView {
        id: webview
        anchors {
            top: header.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        zoomFactor: 3.0
        url: StandardPaths.locate(StandardPaths.CacheLocation, "/logfile.txt")
    }
} // end Page id: logViewerPage
