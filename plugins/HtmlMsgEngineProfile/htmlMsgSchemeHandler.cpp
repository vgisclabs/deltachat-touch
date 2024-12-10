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

#include "htmlMsgSchemeHandler.h"
#include <QWebEngineUrlRequestJob>
#include <QDebug>
#include <QString>
#include <QUrl>
#include <QByteArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QBuffer>
#include <QMimeDatabase>
#include <QMimeType>

HtmlMsgSchemeHandler::HtmlMsgSchemeHandler(QObject *parent) : QWebEngineUrlSchemeHandler(parent)
{
    m_jsonrpcInstance = nullptr;
}


HtmlMsgSchemeHandler::~HtmlMsgSchemeHandler()
{
}


void HtmlMsgSchemeHandler::requestStarted(QWebEngineUrlRequestJob *request)
{
    if (!m_jsonrpcInstance) {
        qDebug() << "HtmlMsgSchemeHandler::requestStarted(): ERROR: m_jsonrpcInstance is nullptr, aborting request";
        request->fail(QWebEngineUrlRequestJob::RequestAborted);
        return;
    }

    QUrl requestUrl = request->requestUrl();

    // re-write our own schemes to the original ones
    if (requestUrl.scheme() == "httpviacore") {
        requestUrl.setScheme("http");
    } else if (requestUrl.scheme() == "httpsviacore") {
        requestUrl.setScheme("https");
    } else {
        qDebug() << "HtmlMsgSchemeHandler::requestStarted(): ERROR: Unknown url scheme, aborting request";
        request->fail(QWebEngineUrlRequestJob::RequestAborted);
        return;
    }

    // create the jsonrpc call
    QString jsonreq("{ \"jsonrpc\": \"2.0\", \"method\": \"get_http_response\", \"id\": ");

    QString numberhelper;
    m_requestId++;
    numberhelper.setNum(m_requestId);
    jsonreq.append(numberhelper);
    
    jsonreq.append(", \"params\": [");
    numberhelper.setNum(m_accountdId);
    jsonreq.append(numberhelper);
    jsonreq.append(", \"");

    // Don't use toString(), toDisplayString() or url() as it will transform
    // e.g. %20 to a blank
    jsonreq.append(requestUrl.toEncoded());

    jsonreq.append("\" ] }");

    // tempText will contain the response json from the core which
    // itself will contain the blob from the server, the encoding
    // (we don't care about that atm) and the mimetype
    char* tempText = dc_jsonrpc_blocking_call(m_jsonrpcInstance, jsonreq.toLocal8Bit().constData());

    if (!tempText) {
        qDebug() << "HtmlMsgSchemeHandler::requestStarted(): dc_jsonrpc_blocking_call() returned nullptr";
        request->fail(QWebEngineUrlRequestJob::RequestAborted);
        return;
    }

    QByteArray jsonrpcResponse = tempText;
    dc_str_unref(tempText);

    QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonrpcResponse);
    QJsonObject jsonObj = jsonDoc.object();

    // check if the core returned an error instead of the server response
    QJsonValue jsonVal = jsonObj.value("error");
    if (!jsonVal.isUndefined()) {
        // Jsonrpc response is an error message
        jsonObj = jsonVal.toObject();
        jsonVal = jsonObj.value("message");
        if (!jsonVal.isString()) {
            // no string, return standard error
            qDebug() << "HtmlMsgSchemeHandler::requestStarted(): dc_jsonrpc_blocking_call() returned an unknown error for the call to " << jsonreq << "; returned response was: " << jsonrpcResponse;
        } else {
            qDebug() << "HtmlMsgSchemeHandler::requestStarted(): dc_jsonrpc_blocking_call() returned error \"" << jsonVal.toString() << "\" for the call to " << jsonreq;
        }
        request->fail(QWebEngineUrlRequestJob::RequestAborted);
        return;
    }

    jsonObj = jsonObj.value("result").toObject();
    jsonVal = jsonObj.value("blob");
    if (!jsonVal.isString()) {
        qDebug() << "HtmlMsgSchemeHandler::requestStarted(): Cannot read blob in core response for call to" << jsonreq;
        request->fail(QWebEngineUrlRequestJob::RequestAborted);
        return;
    }

    // blob is base64 encoded, decode it, then add the data to a QBuffer*
    QByteArray imagedata = QByteArray::fromBase64(jsonVal.toString().toLocal8Bit());
    QBuffer* tempbuffer = new QBuffer();
    tempbuffer->setData(imagedata);
    connect(request, &QObject::destroyed, tempbuffer, &QObject::deleteLater);

    QString mimestring;
    jsonVal = jsonObj.value("mimetype");
    if (!jsonVal.isString()) {
        // Should really not happen, but just in case the core did not provide a mimetype: Get
        // it from the filename in the request
        QString pureFilename = requestUrl.toString().remove(0, requestUrl.toString().lastIndexOf("/") + 1);
        QMimeDatabase mimedb;
        QMimeType mimetype = mimedb.mimeTypeForFile(pureFilename, QMimeDatabase::MatchExtension);
        mimestring = mimetype.name();
        qDebug() << "HtmlMsgSchemeHandler::requestStarted(): Cannot read mimetype in core response for call to" << jsonreq << "; using \"" << mimestring << "\"";
    } else {
        // that should be how we always get it
        mimestring = jsonVal.toString();
    }
    
    request->reply(mimestring.toUtf8(), tempbuffer);
}


void HtmlMsgSchemeHandler::configureSchemehandler(dc_jsonrpc_instance_t* _jsonrpcInst, uint32_t _accId, int _currentRequestId)
{
    m_jsonrpcInstance = _jsonrpcInst;
    m_accountdId = _accId;
    // Maybe not needed as we are using blocking calls here, but just in case:
    // The value of m_requestId used in jsonrpc calls should not collide with the
    // request IDs used in QML land and in DeltaHandler. QML uses from 0 to 999 999 999,
    // DeltaHandler uses between 1 000 000 000 and 2147483647. It's maybe ok to use the
    // range from DeltaHandler, but differ by at least ten million:
    if (_currentRequestId > 2'000'000'000) {
        m_requestId = 1'010'000'000;
    } else {
        m_requestId = 2'010'000'000;
    }
}
