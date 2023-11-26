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
 *
 * 
 * Much of the code in this file was taken from 
 * Dekko2, commit 17338101bf1dcdd9ce1aad59b7d9d2ab429ecb7f
 * https://gitlab.com/dekkan/dekko
 * licensed under GPLv3
 * 
 * modified by (C) 2023 Lothar Ketterer
 */

#include "DTWebEngineUrlRequestInterceptor.h"
#include <QWebEngineUrlRequestInfo>
//#include <QDebug>
#include <QSettings>

DTWebEngineUrlRequestInterceptor::DTWebEngineUrlRequestInterceptor(QWebEngineUrlRequestInterceptor *parent) : QWebEngineUrlRequestInterceptor(parent)
{
    QSettings settings("deltatouch.lotharketterer", "deltatouch.lotharketterer");

    if (settings.contains("alwaysLoadRemote")) {
        this->remoteResourcesAreBlocked = !(settings.value("alwaysLoadRemote").toBool());
    } else {
        this->remoteResourcesAreBlocked = true;
    }
}

void DTWebEngineUrlRequestInterceptor::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    auto requestUrl = info.requestUrl();

        // The following comment is present in the original Dekko code
        // (https://gitlab.com/dekkan/dekko/-/blob/17338101bf1dcdd9ce1aad59b7d9d2ab429ecb7f/plugins/ubuntu-plugin/plugins/core/mail/webview/DekkoWebEngineUrlRequestInterceptor.cpp):
        //
        // check the resourceType() to not block links, not sure thats reliable, but it
        // seems navigationType() == QWebEngineUrlRequestInfo::NavigationTypeLink always...
        bool doBlock = this->remoteResourcesAreBlocked
                       && (info.resourceType() != QWebEngineUrlRequestInfo::ResourceTypeMainFrame);
        info.block(doBlock);
        emit interceptedRemoteRequest(doBlock);

        //if (doBlock) {
        //    //qDebug() << "DTWebEngineUrlRequestInterceptor::interceptedRemoteRequest: Blocked a request to " << info.requestUrl();
        //    qDebug() << "DTWebEngineUrlRequestInterceptor::interceptedRemoteRequest: Blocked a request.";
        //} else if (info.resourceType() != QWebEngineUrlRequestInfo::ResourceTypeMainFrame) {
        //    //qDebug() << "DTWebEngineUrlRequestInterceptor::interceptedRemoteRequest: Did NOT block a request to " << info.requestUrl();
        //    qDebug() << "DTWebEngineUrlRequestInterceptor::interceptedRemoteRequest: Did NOT block a request.";
        //}
}

void DTWebEngineUrlRequestInterceptor::setBlockRemoteResources(bool doBlock)
{
    this->remoteResourcesAreBlocked = doBlock;
}

bool DTWebEngineUrlRequestInterceptor::areRemoteResourcesBlocked() const
{
    return this->remoteResourcesAreBlocked;
}

