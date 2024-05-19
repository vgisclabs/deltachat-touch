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
 * - The page should then connect its file handling function to fileImported:
 *   DeltaHandler.fileImportSignalHelper.fileImported.connect(<file processing function>)
 * - The page then adds the FileImportDialog.qml page
 * - Deletion of the FileImportSignalHelper object is done during destruction of
 *   FileImportDialog.qml.
 *
 * Done automatically:
 * - FileImportDialog.qml increases the counter of the FileImportSignalHelper object.
 * - FileImportDialog.qml connects with the slot processFileImportSignal.
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

public slots:
    void processFileImportSignal(QString filePath);

private:
    int counter;
};

#endif // FILEIMPORTSIGNALHELPER_H
