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
import Lomiri.Components.Popups 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: addAccountPage
    anchors.fill: parent


    header: PageHeader {
        id: header

        title: i18n.tr("Add Account")

//        trailingActionBar.actions: [
//            Action {
//                iconName: 'settings'
//                text: i18n.tr('Settings')
//                onTriggered: layout.addPageToCurrentColumn(layout.primaryPage, Qt.resolvedUrl('SettingsPage.qml'))
//            },
//
//            Action {
//                iconName: 'info'
//                text: i18n.tr('About DeltaTouch')
//                onTriggered: extraStack.push(Qt.resolvedUrl('About.qml'))
//            }
//        ]

    } //PageHeader id:header
        
    function startBackupImport(backupFile) {
        if (DeltaHandler.isBackupFile(backupFile)) {
            // Actual import will be started in the popup.
            PopupUtils.open(progressBackupImport, addAccountPage, { "backupSource": backupFile })
        } else {
            PopupUtils.open(errorMessage)
        }

    }
    
    Loader {
        id: backupImportLoader
    }

    Connections {
        target: backupImportLoader.item
        onFileSelected: {
            addAccountPage.startBackupImport(urlOfFile)
            backupImportLoader.source = ""
        }
        onCancelled: {
            backupImportLoader.source = ""
        }
    }

    ListModel {
        id: addAccountModel
    
        dynamicRoles: true
        Component.onCompleted: {
            addAccountModel.append({ "name": i18n.tr("Log into your E-Mail Account"), "linkToPage": "AddOrConfigureEmailAccount.qml" } )
            addAccountModel.append({ "name": i18n.tr("Add as Second Device"), "linkToPage": "AddAccountViaQr.qml" } )
            addAccountModel.append({ "name": i18n.tr("Restore from Backup"), "linkToPage": "restoreFromBackup--noLink" } )
            addAccountModel.append({ "name": i18n.tr("Scan Invitation Code"), "linkToPage": "AddAccountViaQr.qml" } )
        }
    }
    
    ListView {
        id: addAccountView
        height: addAccountPage.height - header.height - units.gu(1)
        width: addAccountPage.width
        anchors {
            left: addAccountPage.left
            right: addAccountPage.right
            top: header.bottom
            topMargin: units.gu(1)
            bottom: addAccountPage.bottom
        }
        model: addAccountModel
        delegate: accountDelegate
    }
    
    Component {
        id: accountDelegate

        ListItem {
            id: item
            height: listLayout.height + (divider.visible ? divider.height : 0)

            ListItemLayout {
                id: listLayout
                title.text: name

                Icon {
                    name: "go-next"
                    SlotsLayout.position: SlotsLayout.Trailing;
                    width: units.gu(2)
                }
            }

            onClicked: {
                if (linkToPage == "restoreFromBackup--noLink") {
                    if (root.onUbuntuTouch) {
                        // Ubuntu Touch
                        DeltaHandler.newFileImportSignalHelper()
                        DeltaHandler.fileImportSignalHelper.fileImported.connect(addAccountPage.startBackupImport)
                        extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.FileType })
                        // TODO: regarding the below, maybe after the switch "let xy = extraStack.push(...); xy.bla.connect(...)" works?
                        //
                        // See comments in CreateOrEditGroup.qml
                        //let incubator = layout.addPageToCurrentColumn(addAccountPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.FileType })

                        //if (incubator.status != Component.Ready) {
                        //    // have to wait for the object to be ready to connect to the signal,
                        //    // see documentation on AdaptivePageLayout and
                        //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                        //    incubator.onStatusChanged = function(status) {
                        //        if (status == Component.Ready) {
                        //            incubator.object.fileSelected.connect(addAccountPage.startBackupImport)
                        //        }
                        //    }
                        //} else {
                        //    // object was directly ready
                        //    incubator.object.fileSelected.connect(addAccountPage.startBackupImport)
                        //}
                    } else {
                        // non-Ubuntu Touch
                        backupImportLoader.source = "FileImportDialog.qml"
                        backupImportLoader.item.setFileType(DeltaHandler.FileType)
                        backupImportLoader.item.open()
                    }
                } else {
                    extraStack.push(Qt.resolvedUrl(linkToPage))
                }
            }
        }
    }

    Component {
        id: progressBackupImport
        ProgressBackupImport {
            title: i18n.tr('Restore from Backup')
        }
    }

    Component {
        id: errorMessage
        ErrorMessage {
            title: i18n.tr('Error')
            // TODO: string not translated yet
            text: i18n.tr('The selected file is not a valid backup file.')
        }
    }
} // end of Page id: addAccountPage
