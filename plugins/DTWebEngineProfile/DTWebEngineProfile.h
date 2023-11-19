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

#ifndef DTWEBENGINEPROFILE_H
#define DTWEBENGINEPROFILE_H

#include "DTWebEngineUrlRequestInterceptor.h"
#include <QString>
#include <QUrl>
#include <QQuickWebEngineProfile>

class DTWebEngineProfile : public QQuickWebEngineProfile
{
    Q_OBJECT
    Q_PROPERTY(bool remoteContentAllowed READ isRemoteContentAllowed WRITE setRemoteContentAllowed NOTIFY remoteContentAllowedChanged)

public:
    explicit DTWebEngineProfile(QQuickWebEngineProfile *parent = Q_NULLPTR);
    ~DTWebEngineProfile() {
    }

    Q_INVOKABLE void setRemoteContentAllowed(bool allowed);
    Q_INVOKABLE bool isRemoteContentAllowed() const;

signals:
    void remoteContentBlocked();
    void remoteContentAllowedChanged();

public slots:
    void onInterceptedRemoteRequest(bool wasBlocked);

private:
    DTWebEngineUrlRequestInterceptor urlRequestInterceptor;
};

#endif
