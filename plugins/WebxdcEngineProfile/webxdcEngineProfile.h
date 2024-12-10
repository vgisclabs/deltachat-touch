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

#ifndef WEBXDCENGINEPROFILE_H
#define WEBXDCENGINEPROFILE_H

#include "webxdcRequestInterceptor.h"
#include "webxdcSchemeHandler.h"

#include "../deltachat.h"

#include <QQuickWebEngineProfile>
#include <QString>

class WebxdcEngineProfile : public QQuickWebEngineProfile
{
    Q_OBJECT

public:
    explicit WebxdcEngineProfile(QObject *parent = Q_NULLPTR);
    ~WebxdcEngineProfile();

signals:
    void finishedConfiguringInstance();
    void urlReceived(QString urlFromWebxdc);

public slots:
    void configureNewInstance(QString id, dc_msg_t* msg);

private:
    WebxdcRequestInterceptor m_urlRequestInterceptor;
    WebxdcSchemeHandler m_webxdcSchemehandler;

private slots:
    void forwardUrl(QString url);
};

#endif //WEBXDCENGINEPROFILE_H
