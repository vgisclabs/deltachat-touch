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

#include "DTWebEngineProfile.h"
#include "DTWebEngineUrlRequestInterceptor.h"
#include <QQmlEngine>
#include <QtQml>
#include <QDebug>
#include <QDir>
#include <QStorageInfo>
#include <QCoreApplication>
#include <QStandardPaths>

DTWebEngineProfile::DTWebEngineProfile(QQuickWebEngineProfile *parent) : QQuickWebEngineProfile(parent)
{
    this->setUrlRequestInterceptor(&this->urlRequestInterceptor);
    connect(&this->urlRequestInterceptor, SIGNAL(interceptedRemoteRequest(bool)), this, SLOT(onInterceptedRemoteRequest(bool)));
}

void DTWebEngineProfile::onInterceptedRemoteRequest(bool wasBlocked)
{
    if (wasBlocked)
    {
        emit remoteContentBlocked();
    }
}

void DTWebEngineProfile::setRemoteContentAllowed(bool allowed)
{
    this->urlRequestInterceptor.setBlockRemoteResources(!allowed);
}

bool DTWebEngineProfile::isRemoteContentAllowed() const
{
    return !this->urlRequestInterceptor.areRemoteResourcesBlocked();
}
