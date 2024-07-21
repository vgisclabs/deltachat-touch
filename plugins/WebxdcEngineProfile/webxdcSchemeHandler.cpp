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

#include "webxdcSchemeHandler.h"
#include <QWebEngineUrlRequestJob>
#include <QDebug> // for qDebug()
#include <QBuffer>
#include <QMimeDatabase>
#include <QMimeType>
#include <QFile>

WebxdcSchemeHandler::WebxdcSchemeHandler(QObject *parent) : QWebEngineUrlSchemeHandler(parent)
{
    m_webxdcInstance = nullptr;
}


WebxdcSchemeHandler::~WebxdcSchemeHandler()
{
    if (m_webxdcInstance) {
        dc_msg_unref(m_webxdcInstance);
    }
}

void WebxdcSchemeHandler::requestStarted(QWebEngineUrlRequestJob *request)
{
    qDebug() << "WebxdcSchemeHandler::requestStarted(): request received:" << request->requestUrl();
    qDebug() << "WebxdcSchemeHandler::requestStarted(): initiator is:" << request->initiator();

    QString fileToRequest = request->requestUrl().path();

    if (!m_webxdcInstance) {
        qDebug() << "WebxdcSchemeHandler::requestStarted(): m_webxdcInstance is not set, calling request->fail";
        request->fail(QWebEngineUrlRequestJob::RequestFailed);
        return;
    }

    if (fileToRequest == "/webxdc.js") {
        QFile* tempfile = new QFile(":/assets/webxdc/webxdc.js");
        connect(request, &QObject::destroyed, tempfile, &QObject::deleteLater);
        request->reply("application/javascript", tempfile);

    } else if (fileToRequest == "/12369813asd18935zas123123a") {
        // wrapper.html will be requested by WebxdcPage.qml via the webxdcfilerequest scheme
        // and this identifier
        QFile* tempfile = new QFile(":/assets/webxdc/wrapper.html");
        connect(request, &QObject::destroyed, tempfile, &QObject::deleteLater);
        request->reply("text/html", tempfile);

    } else if (fileToRequest == "/23581asab8123hasd71jksdf1237as") {
        // sandboxed_iframe_rtcpeerconnection_check.html will be requested by
        // wrapper.html via the webxdcfilerequest scheme and this identifier
        QFile* tempfile = new QFile(":/assets/webxdc/sandboxed_iframe_rtcpeerconnection_check.html");
        connect(request, &QObject::destroyed, tempfile, &QObject::deleteLater);
        request->reply("text/html", tempfile);

    } else {
        size_t buffersize;
        char* buffercontent;

        buffercontent = dc_msg_get_webxdc_blob(m_webxdcInstance, fileToRequest.toUtf8().constData(), &buffersize);

        if (buffercontent) {
            QBuffer* tempbuffer = new QBuffer();
            tempbuffer->open(QBuffer::ReadWrite);
            tempbuffer->write(buffercontent, buffersize);
            tempbuffer->close();
            dc_str_unref(buffercontent);
            connect(request, &QObject::destroyed, tempbuffer, &QObject::deleteLater);

            QString pureFilename = fileToRequest;
            pureFilename.remove(0, pureFilename.lastIndexOf("/") + 1);
            QMimeDatabase mimedb;
            QMimeType mimetype = mimedb.mimeTypeForFile(pureFilename, QMimeDatabase::MatchExtension);

            request->reply(mimetype.name().toUtf8(), tempbuffer);

        } else {
            qDebug() << "WebxdcSchemeHandler::requestStarted(): ERROR: dc_msg_get_webxdc_blob() returned NULL for " << fileToRequest;
            request->fail(QWebEngineUrlRequestJob::UrlNotFound);
        }
    }
}


void WebxdcSchemeHandler::setWebxdcInstance(dc_msg_t* msg)
{
    if (m_webxdcInstance) {
        dc_msg_unref(m_webxdcInstance);
    }
    m_webxdcInstance = msg;
}
