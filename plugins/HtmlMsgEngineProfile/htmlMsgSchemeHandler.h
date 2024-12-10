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

#ifndef HTMLMSGSCHEMEHANDLER_H
#define HTMLMSGSCHEMEHANDLER_H

#include "../deltachat.h"
#include <QWebEngineUrlSchemeHandler>

class HtmlMsgSchemeHandler : public QWebEngineUrlSchemeHandler
{

    Q_OBJECT
public:
    explicit HtmlMsgSchemeHandler(QObject *parent = Q_NULLPTR);
    ~HtmlMsgSchemeHandler();
    void requestStarted(QWebEngineUrlRequestJob *request);
    void configureSchemehandler(dc_jsonrpc_instance_t* _jsonrpcInst, uint32_t _accId, int _currentRequestId);

private:
    dc_jsonrpc_instance_t* m_jsonrpcInstance;
    uint32_t m_accountdId;
    int m_requestId;
};

#endif //HTMLMSGSCHEMEHANDLER_H
