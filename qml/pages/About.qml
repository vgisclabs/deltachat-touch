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
import Ubuntu.Components 1.3

import DeltaHandler 1.0

Page {
    id: aboutPage
    header: PageHeader {
        id: aboutHeader
        title: i18n.tr('About')
    }

    property string deltaversion: DeltaHandler.getCurrentConfig("sys.version")

    Label {
        id: versionLabel
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: aboutHeader.bottom
            margins: units.gu(2)
        }
        text: '%1 v%2'.arg(root.appName).arg(root.version)
    }

    Label {
        id: copyleftLabel
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: versionLabel.bottom
            margins: units.gu(2)
        }
        text: '© 2023 Lothar Ketterer'
    }
    
    Label {
        id: licenseLabel
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: copyleftLabel.bottom
            margins: units.gu(2)
        }
        text: i18n.tr('License:') + ' <a href="https://codeberg.org/lk108/DeltaTouch/LICENSE">GPLv3</a>'
        onLinkActivated: Qt.openUrlExternally('https://codeberg.org/lk108/DeltaTouch/LICENSE')
    }

    Label {
        id: sourceLabel
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: licenseLabel.bottom
            topMargin: units.gu(2)
        }
        text: i18n.tr('Source code:')
    }

    Label {
        id: sourceLink
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: sourceLabel.bottom
        }
        text: '<a href="https://codeberg.org/lk108/DeltaTouch">https://codeberg.org/lk108/DeltaTouch</a>'
        onLinkActivated: Qt.openUrlExternally('https://codeberg.org/lk108/DeltaTouch')
    }
    
    Label {
        id: bugsLabel
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: sourceLink.bottom
            topMargin: units.gu(2)
        }
        text: i18n.tr('Report bugs here:')
    }

    Label {
        id: bugsLink
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: bugsLabel.bottom
        }
        text: '<a href="https://codeberg.org/lk108/DeltaTouch/issues">https://codeberg.org/lk108/DeltaTouch/issues</a>'
        onLinkActivated: Qt.openUrlExternally('https://codeberg.org/lk108/DeltaTouch/issues')
    }

    Label {
        id: creditLabel1
        anchors {
            left: parent.left
            leftMargin: units.gu(3)
            right: parent.right
            rightMargin: units.gu(3)
            top: bugsLink.bottom
            topMargin: units.gu(3)
        }
        text: i18n.tr('This app is powered by deltachat-core') + (deltaversion == "" ? "" : " v" + deltaversion) + (' (<a href="https://github.com/deltachat/deltachat-core-rust">source</a>).')
        onLinkActivated: Qt.openUrlExternally('https://github.com/deltachat/deltachat-core-rust')
        wrapMode: Text.Wrap
    }

    Label {
        id: creditLabel2
        anchors {
            left: parent.left
            leftMargin: units.gu(3)
            right: parent.right
            rightMargin: units.gu(3)
            top: creditLabel1.bottom
            topMargin: units.gu(1)
        }
        text: 'Kudos to the creators of this library! Check out their page at <a href="https://delta.chat">delta.chat</a>.'
        onLinkActivated: Qt.openUrlExternally('https://delta.chat')
        wrapMode: Text.Wrap
    }
} // end Page id: aboutPage
