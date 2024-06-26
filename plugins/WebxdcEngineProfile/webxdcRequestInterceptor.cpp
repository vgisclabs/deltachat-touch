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

#include "webxdcRequestInterceptor.h"

#include <QStandardPaths>
#include <QDebug> // for qDebug()
#include <QUrl>
#include <QString>

WebxdcRequestInterceptor::WebxdcRequestInterceptor(QObject *parent) : QWebEngineUrlRequestInterceptor(parent)
{
}

void WebxdcRequestInterceptor::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    QString requestUrl = info.requestUrl().toString();
    qDebug() << "WebxdcRequestInterceptor::interceptRequest: Received a request for " << requestUrl;
    if (requestUrl.startsWith("file:///")) {
        requestUrl.replace(0, 7, "webxdcfilerequest:");
        info.redirect(QUrl(requestUrl));
        info.block(false);
    } else if (requestUrl.startsWith("webxdcfilerequest:")) {
        info.block(false);
    } else {
        info.block(true);
    }
}
