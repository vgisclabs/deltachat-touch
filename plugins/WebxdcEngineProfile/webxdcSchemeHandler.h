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

#ifndef WEBXDCSCHEMEHANDLER_H
#define WEBXDCSCHEMEHANDLER_H

#include <QWebEngineUrlSchemeHandler>

#include "../deltachat.h"

class WebxdcSchemeHandler : public QWebEngineUrlSchemeHandler
{

    Q_OBJECT
public:
    explicit WebxdcSchemeHandler(QObject *parent = Q_NULLPTR);
    ~WebxdcSchemeHandler();
    void requestStarted(QWebEngineUrlRequestJob *request);
    void setWebxdcInstance(dc_msg_t* msg);

signals:
    void urlReceivedFromWebxdc(QString url);

private:
    dc_msg_t* m_webxdcInstance;
};

#endif //WEBXDCSCHEMEHANDLER_H
