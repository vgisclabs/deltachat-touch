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

#include "htmlMsgRequestInterceptor.h"
#include <QWebEngineUrlRequestInfo>
#include <QStandardPaths>
#include <QDebug>

HtmlMsgRequestInterceptor::HtmlMsgRequestInterceptor(QObject *parent) : QWebEngineUrlRequestInterceptor(parent)
{
    this->remoteResourcesAreBlocked = true;
}

void HtmlMsgRequestInterceptor::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    QUrl requestUrl = info.requestUrl();

    // Allow access to the html message itself
    QString initialUrl = "file://" + QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/htmlmsg.html";

    if (requestUrl.scheme() == "file" && requestUrl.toString() == initialUrl) {
        info.block(false);
        return;
    }

    // block by default; allow only images if the user clicked to unblock
    bool doBlock = this->remoteResourcesAreBlocked || info.resourceType() != QWebEngineUrlRequestInfo::ResourceTypeImage;

    if (doBlock) {
        info.block(true);
        emit interceptedRemoteRequest(true);
    } else {
        // http or https requests are rewritten to schemes httpviacore or httpsviacore, respectively,
        // so our own scheme handler can route the calls through the core (it's not allowed by Qt
        // to define a custom scheme handler for file://, http:// or https://)
        if (requestUrl.scheme() == "http") {
            requestUrl.setScheme("httpviacore");
            info.redirect(requestUrl);
            info.block(false);
        } else if (requestUrl.scheme() == "https") {
            requestUrl.setScheme("httpsviacore");
            info.redirect(requestUrl);
            info.block(false);
        } else if (requestUrl.scheme() == "httpviacore" || requestUrl.scheme() == "httpsviacore") {
            info.block(false);
        } else {
            qDebug() << "HtmlMsgRequestInterceptor::interceptRequest(): remote resources are not blocked, but scheme is neither http nor https, so blocking anyway";
            doBlock = true;
            info.block(true);
            emit interceptedRemoteRequest(true);
            return;
        }
    }

    //if (doBlock) {
    //    qDebug() << "HtmlMsgRequestInterceptor::interceptedRemoteRequest: Blocked a request to " << info.requestUrl();
    //    //qDebug() << "HtmlMsgRequestInterceptor::interceptedRemoteRequest: Blocked a request.";
    //} else if (info.resourceType() != QWebEngineUrlRequestInfo::ResourceTypeMainFrame) {
    //    qDebug() << "HtmlMsgRequestInterceptor::interceptedRemoteRequest: Did NOT block a request to " << info.requestUrl();
    //    //qDebug() << "HtmlMsgRequestInterceptor::interceptedRemoteRequest: Did NOT block a request.";
    //}
}

void HtmlMsgRequestInterceptor::setBlockRemoteResources(bool doBlock)
{
    this->remoteResourcesAreBlocked = doBlock;
}

bool HtmlMsgRequestInterceptor::areRemoteResourcesBlocked() const
{
    return this->remoteResourcesAreBlocked;
}

