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

#include "fileImportSignalHelper.h"

#include <QDebug>

FileImportSignalHelper::FileImportSignalHelper()
    : QObject(nullptr), counter {0}
{
}

void FileImportSignalHelper::increaseCounter()
{
    ++counter;
}

void FileImportSignalHelper::processFileImportSignal(QString filePath)
{
    if (counter == 1) {
        emit fileImported(filePath);
    } else {
        // FileImportDialog.qml increases the counter in Component.onCompleted.
        // If the counter is higher than 1, then there are most likely unwanted
        // connections. Do not emit the signal in this case.
        qWarning() << "FileImportSignalHelper::processFileImportSignal(): Counter does not equal 1 => signal connection is not as expected, not emitting fileImported signal.";
    }
}


void FileImportSignalHelper::processMultiFileImportSignal(QStringList files)
{
    if (counter == 1) {
        emit multiFileImported(files);
    } else {
        // see comment in FileImportSignalHelper::processFileImportSignal()
        qWarning() << "FileImportSignalHelper::processMultiFileImportSignal(): Counter does not equal 1 => signal connection is not as expected, not emitting fileImported signal.";
    }
}
