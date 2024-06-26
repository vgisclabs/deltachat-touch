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

#ifndef HTMLMSGENGINEPROFILE_PLUGIN_H
#define HTMLMSGENGINEPROFILE_PLUGIN_H
#include <QQmlExtensionPlugin>

class HtmlMsgEngineProfilePlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "local.deltatouch.htmlmsgengineprofile")

public:
    void registerTypes(const char *uri);
};

#endif // HTMLMSGENGINEPROFILE_PLUGIN_H
