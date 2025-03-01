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
 */

import QtQuick 2.12
import Lomiri.Components 1.3

import "../jsonrpc.mjs" as JSONRPC

Page {
    id: aboutPage
    header: PageHeader {
        id: aboutHeader
        title: i18n.tr('About DeltaTouch')

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

    property string deltaversion 

    Component.onCompleted: {
        JSONRPC.client.getSystemInfo().then((dc_info) => (deltaversion = dc_info.deltachat_core_version))
    }

    Flickable {
        id: flick
        height: aboutPage.height - aboutHeader.height 
        width: aboutPage.width
        anchors {
            top: aboutHeader.bottom
            bottom: aboutPage.bottom
            bottomMargin: units.gu(2)
            left: aboutPage.left
        }
        contentHeight: flickContent.childrenRect.height

        Item {
            id: flickContent
            width: parent.width

            Label {
                id: versionLabel
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    margins: units.gu(1)
                }
                text: '%1 v%2'.arg(root.appName).arg(root.version) //+ " (focal)"
            }

            Label {
                id: copyleftLabel
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: versionLabel.bottom
                    margins: units.gu(1)
                }
                text: '© 2023, 2024 Lothar Ketterer'
            }
            
            Label {
                id: licenseLabel
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: copyleftLabel.bottom
                    margins: units.gu(1)
                }
                text: i18n.tr('License:') + ' <a href="https://codeberg.org/lk108/deltatouch/src/branch/main/LICENSE">GPLv3</a>'
                linkColor: root.dtLinkColor
                onLinkActivated: Qt.openUrlExternally(link)
            }

            Label {
                id: sourceLabel
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: licenseLabel.bottom
                    topMargin: units.gu(1)
                }
                text: i18n.tr('Source code:')
            }

            Label {
                id: sourceLink
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: sourceLabel.bottom
                }
                text: '<a href="https://codeberg.org/lk108/deltatouch">https://codeberg.org/lk108/deltatouch</a>'
                linkColor: root.dtLinkColor
                onLinkActivated: Qt.openUrlExternally(link)
            }
            
            Label {
                id: bugsLabel
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: sourceLink.bottom
                    topMargin: units.gu(1)
                }
                text: i18n.tr('Report bugs here:')
            }

            Label {
                id: bugsLink
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: bugsLabel.bottom
                }
                text: '<a href="https://codeberg.org/lk108/deltatouch/issues">https://codeberg.org/lk108/deltatouch/issues</a>'
                linkColor: root.dtLinkColor
                onLinkActivated: Qt.openUrlExternally(link)
            }

            
            Label {
                id: supportLabel1
                width: aboutPage.width - units.gu(4)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: bugsLink.bottom
                    topMargin: units.gu(1)
                }
                text: i18n.tr("Support via classic email or DeltaChat compatible app (without reply guarantee and without any warranty):")
                wrapMode: Text.WordWrap
            }

            Label {
                id: supportLabel2
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: supportLabel1.bottom
                }
                text: i18n.tr("deltatouch" + "@" + "mailbox" + "." + "org")
                wrapMode: Text.WordWrap
            }

            Label {
                id: creditLabel1
                width: aboutPage.width - units.gu(4)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: supportLabel2.bottom
                    topMargin: units.gu(1)
                }
                text: i18n.tr('This app is powered by deltachat-core-rust ') + (deltaversion == "" ? "" : deltaversion) + (' (<a href="https://github.com/deltachat/deltachat-core-rust">source</a>).')
                linkColor: root.dtLinkColor
                onLinkActivated: Qt.openUrlExternally(link)
                wrapMode: Text.Wrap
            }

            Label {
                id: creditLabel2
                width: aboutPage.width - units.gu(4)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: creditLabel1.bottom
                    topMargin: units.gu(1)
                }
                text: 'Kudos to the creators of this library! Check out their page at <a href="https://delta.chat">delta.chat</a>.'
                linkColor: root.dtLinkColor
                onLinkActivated: Qt.openUrlExternally(link)
                wrapMode: Text.Wrap
            }

            Label {
                id: thanksLabel1
                width: aboutPage.width - units.gu(4)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: creditLabel2.bottom
                    topMargin: units.gu(1)
                }
                text: 'Thanks to all supporters and contributors: Simon (treefit), link2xt, adbenitez, Marko, Hocuri, holger, Ubuntu Touch AppDev community (Maciek, Lionel, dobey, Jonatan)'
                wrapMode: Text.Wrap
            }

            Label {
                id: thanksLabel2
                width: aboutPage.width - units.gu(4)
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: thanksLabel1.bottom
                    topMargin: units.gu(1)
                }
                text: 'Webxdc support in DeltaTouch is generously funded by the <a href="https://nlnet.nl/project/DeltaTouch/">NLnet foundation</a>.'
                wrapMode: Text.Wrap
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }
    }
} // end Page id: aboutPage
