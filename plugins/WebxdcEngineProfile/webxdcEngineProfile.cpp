/*
 * Copyright (C) 2024 Lothar Ketterer
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

#include "webxdcEngineProfile.h"

#include <QDebug>
#include <QStandardPaths>
#include <QFile>
#include <QDir>

WebxdcEngineProfile::WebxdcEngineProfile(QObject *parent) : QQuickWebEngineProfile(parent)
{

    this->setUrlRequestInterceptor(&this->m_urlRequestInterceptor);
    this->installUrlSchemeHandler("webxdcfilerequest", &this->m_webxdcSchemehandler);
}


WebxdcEngineProfile::~WebxdcEngineProfile()
{
}


void WebxdcEngineProfile::configureNewInstance(QString id, dc_msg_t* msg)
{
    this->setPersistentStoragePath(QStandardPaths::locate(QStandardPaths::AppDataLocation, "QtWebEngine/" + id));
    emit persistentStoragePathChanged();

    this->setStorageName(id);
    emit storageNameChanged();

    if (msg) {
        m_webxdcSchemehandler.setWebxdcInstance(msg);
    } else {
        qDebug() << "WebxdcEngineProfile::configureNewInstance(): msg is null, could not call m_webxdcSchemehandler->setWebxdcInstance()";
    }

    emit finishedConfiguringInstance();
}
