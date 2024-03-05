/*
 * Copyright (C) 2024  Lothar Ketterer
 *
 * Originally from the app Webber by <Tim Süberkrüb <dev@timsueberkrueb.io>>,
 * this file has been modified to be part of the app "DeltaTouch".
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
import QtQuick 2.0
import QtQuick.Layouts 1.0
import Lomiri.Components 1.3
import QtQuick.Dialogs 1.3

import DeltaHandler 1.0

// File is not available on Ubuntu Touch (except via
// "clickable desktop") due to QQmlFileSelector, which
// will choose the file with the same name in the subdir
// +ubuntu--touch

FileDialog {
    id: fileExportDialog
    // Title to be set by the caller
    // // TODO: string not translated yet
    // title: i18n.tr("Choose folder to save the file in")

    function setFileType(ftype) {
        switch (ftype) {
            case DeltaHandler.AudioType:
                folder = shortcuts.music
                break
            case DeltaHandler.ImageType:
                folder = shortcuts.pictures
                break
            case DeltaHandler.FileType: // fallthrough
            default:
                folder = shortcuts.home
                break
        }
    }

    selectMultiple: false
    selectExisting: true
    selectFolder: true
    folder: shortcuts.home

    signal folderSelected(string urlOfFolder)
    signal cancelled()

    onAccepted: {
        folderSelected(folder)
        Qt.quit()
    }
    onRejected: {
        cancelled()
        Qt.quit()
    }
}
