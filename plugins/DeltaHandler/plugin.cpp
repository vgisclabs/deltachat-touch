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
 */

#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "deltahandler.h"
#include "webxdcImageProvider.h"

void DeltaHandlerPlugin::registerTypes(const char *uri)
{
    //@uri DeltaHandler
    qmlRegisterSingletonType<DeltaHandler>(uri, 1, 0, "DeltaHandler", [](QQmlEngine*, QJSEngine*) -> QObject* { return new DeltaHandler; });
}


void DeltaHandlerPlugin::initializeEngine(QQmlEngine *engine, const char *uri)
{
    engine->addImageProvider(QLatin1String("webxdcImageProvider"), new WebxdcImageProvider);
}
