/*
 * Copyright (C) 2024  Lothar Ketterer
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

#ifndef FILEIMPORTSIGNALHELPER_H
#define FILEIMPORTSIGNALHELPER_H

#include <QObject>
#include <QString>

/*
 * (UT only) Helper class to act as intermediate to the fileSelected signal as
 * emitted by qml/pages/+ubuntu-touch/FileImportDialog.qml. Reason is that
 * connecting a function in QML to this signal directly proved to be
 * unreliable (for background, see comments regarding the "incubator method"
 * in qml/pages/CreateOrEditGroup.qml).
 *
 * Intended usage is as follows:
 * - A page that wants to use the UT version of FileImportDialog.qml should
 *   call DeltaHandler.createNewFileImportSignalHelper()
 * - If only one file should be selectable, then the page should connect
 *   its single file handling function to fileImported:
 *   DeltaHandler.fileImportSignalHelper.fileImported.connect(<file processing function>)
 *   The fileImported signal will pass a string with the path of the imported file.
 * - If the import of multiple files should be possible, then the file handling function should
 *   be connected to the multiFileImported signal:
 *   DeltaHandler.fileImportSignalHelper.multiFileImported.connect(<file processing function>)
 *   The multiFileImported signal will pass a QStringList (an array of strings on QML side)
 *   where each string is the path of one file selected by the user.
 * - The page should then add the FileImportDialog.qml page to extraStack. By default, it's in
 *   single mode. For multi mode, '"multiMode": true' has to be passed when pushing the page
 *   to extraStack.
 * - Deletion of the FileImportSignalHelper object is done during destruction of
 *   FileImportDialog.qml, so no need to take care of that.
 *
 * Done automatically:
 * - FileImportDialog.qml increases the counter of the FileImportSignalHelper object.
 * - FileImportDialog.qml connects with the slot processFileImportSignal (for single
 *   files, used by most pages) and processMultiFileImportSignal (for multiple files).
 * - FileImportDialog.qml calls DeltaHandler.deleteFileImportSignalHelper() 
 *   during onDestruction.
 *
 */
class FileImportSignalHelper : public QObject {
    Q_OBJECT

public:
    FileImportSignalHelper();

    Q_INVOKABLE void increaseCounter();
    //Q_INVOKABLE int getCounter();

signals:
    void fileImported(QString filePath);
    void multiFileImported(QStringList filePath);

public slots:
    void processFileImportSignal(QString filePath);
    void processMultiFileImportSignal(QStringList files);

private:
    int counter;
};

#endif // FILEIMPORTSIGNALHELPER_H
