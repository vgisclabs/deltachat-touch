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

#ifndef WEBXDCREQUESTINTERCEPTOR_H
#define WEBXDCREQUESTINTERCEPTOR_H

#include <QWebEngineUrlRequestInterceptor>
#include <QWebEngineUrlRequestInfo>

class WebxdcRequestInterceptor : public QWebEngineUrlRequestInterceptor
{

    Q_OBJECT
public:
    explicit WebxdcRequestInterceptor(QObject *parent = Q_NULLPTR);
    ~WebxdcRequestInterceptor() = default;
    void interceptRequest(QWebEngineUrlRequestInfo &info);
};

#endif //WEBXDCREQUESTINTERCEPTOR_H
