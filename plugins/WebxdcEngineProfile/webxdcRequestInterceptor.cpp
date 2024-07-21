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
    QUrl currentRequestUrl = info.requestUrl();
    qDebug() << "WebxdcRequestInterceptor::interceptRequest(): Received a request for " << currentRequestUrl << ", scheme is: " << currentRequestUrl.scheme();
    if (currentRequestUrl.scheme() == "file" || currentRequestUrl.isRelative()) {
        // This code should never be needed because the request to index.html
        // (in wrapper.html) is already with the scheme webxdcfilerequest, and thus
        // all following requests have this scheme as well, but just to be on the safe side
        qDebug() << "WebxdcRequestInterceptor::interceptRequest(): setting scheme to webxdcfilerequest";
        currentRequestUrl.setScheme("webxdcfilerequest");
        info.redirect(currentRequestUrl);
        info.block(false);
    } else if (currentRequestUrl.scheme() == "webxdcfilerequest") {
        info.block(false);
    } else {
        qDebug() << "WebxdcRequestInterceptor::interceptRequest(): BLOCKED " << currentRequestUrl;
        info.block(true);
    }
}
