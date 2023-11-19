/*
 * Copyright (C) 2023  Lothar Ketterer
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * deltatouch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <QGuiApplication>
#include <QCoreApplication>
#include <QUrl>
#include <QString>
#include <QQuickView>
#include <QtWebEngine>

int main(int argc, char *argv[])
{
    QGuiApplication *app = new QGuiApplication(argc, (char**)argv);
    app->setApplicationName("deltatouch.lotharketterer");

    QtWebEngine::initialize();

    qRegisterMetaType<uint32_t>("uint32_t");
    qRegisterMetaType<int64_t>("int64_t");
    //qRegisterMetaType<size_t>("size_t");

    qDebug() << "Starting app from main.cpp";

    qSetMessagePattern("%{time yyyy-MM-dd hh:mm:ss} %{message}");

    QQuickView *view = new QQuickView();
    view->setSource(QUrl("qrc:/Main.qml"));
    view->setResizeMode(QQuickView::SizeRootObjectToView);
    view->show();

    return app->exec();
}
