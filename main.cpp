/*
 * Copyright (C) 2023, 2024 Lothar Ketterer
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
#include <QDBusConnection>
#include <QDBusMessage>
#include <QUrl>
#include <QString>
#include <QFile>
#include <QQuickView>
#include <QtWebEngine>
#include <QWebEngineUrlScheme>
#include <iostream>
#include <QtWebEngine>

int main(int argc, char *argv[])
{
    QProcessEnvironment procenv = QProcessEnvironment::systemEnvironment();
    bool onUbuntuTouch {false};
    QStringList sysvarlist = procenv.keys();
    for (int i = 0; i < sysvarlist.size(); ++i) {
        if (sysvarlist.at(i) == "QT_FILE_SELECTORS") {
            if (procenv.value("QT_FILE_SELECTORS") == "ubuntu-touch") {
                onUbuntuTouch = true;
            }
        }
    }

    if (!onUbuntuTouch) {
        // On non-UT platforms, url scheme handling is done by calling a
        // handling appplication with the url as parameter. For deltatouch,
        // there are two possibilities:
        // - The app is not running when the call happens: The url is then
        //   handled in Main.qml, see at the end of startupStep5().
        // - The app is already running. This can be checked by trying to
        //   register the DBus service local.deltatouch. If this fails,
        //   it means that another instance of the app is already running.
        //   In this case, we call a DBus method of the service local.deltatouch
        //   (see the constructor in DeltaHandler.cpp, and dbusUrlReceiver.h) with
        //   the url as parameter.
        //
        // (On UT, this is not needed, see the QML Connection with UriHandler as
        // target instead)
        qDebug() << "Checking if another instance is already running...";
        bool success = QDBusConnection::sessionBus().registerService("local.deltatouch");
        if (success) {
            qDebug() << "...no, continuing";
            // unregister the service again; it will be registered in DeltaHandler,
            // but only if the app is not running on UT
            QDBusConnection::sessionBus().unregisterService("local.deltatouch");
        } else {
            qDebug() << "...yes, checking if arguments need to be sent...";
            if (argc > 1) {
                qDebug() << "...yes, sending arguments and quitting.";
                 QDBusConnection tempBus = QDBusConnection::connectToBus(QDBusConnection::SessionBus, "DeltaTouch");
                 QDBusMessage message = QDBusMessage::createMethodCall("local.deltatouch", "/deltatouch/urlreceiver", "local.deltatouch", "receiveUrl");
                 message << argv[1];
                 tempBus.send(message);
            } else {
                qDebug() << "...no, quitting.";
            }
            // now quit
            exit(0);
        }
    }

    
    QWebEngineUrlScheme webxdcscheme("webxdcfilerequest");
    webxdcscheme.setSyntax(QWebEngineUrlScheme::Syntax::Host);
    webxdcscheme.setDefaultPort(QWebEngineUrlScheme::PortUnspecified);
    webxdcscheme.setFlags(QWebEngineUrlScheme::LocalAccessAllowed);
    QWebEngineUrlScheme::registerScheme(webxdcscheme);

    QWebEngineUrlScheme pgpfprscheme("openpgp4fpr");
    pgpfprscheme.setSyntax(QWebEngineUrlScheme::Syntax::Path);
    pgpfprscheme.setFlags(QWebEngineUrlScheme::LocalAccessAllowed);
    QWebEngineUrlScheme::registerScheme(pgpfprscheme);

    QtWebEngine::initialize();

    QGuiApplication *app = new QGuiApplication(argc, (char**)argv);
    app->setApplicationName("deltatouch.lotharketterer");
    
    // create the cache dir if it doesn't exist yet (it shouldn't exist,
    // as it is deleted on shutdown)
    QString cachedir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));

    if (!QFile::exists(cachedir)) {
        QDir tempdir;
        bool success = tempdir.mkpath(cachedir);
        if (!success) {
            std::cerr << "main.cpp: Could not create cache directory, exiting" << std::endl;
            exit(1);
        }
    }

    qRegisterMetaType<uint32_t>("uint32_t");
    qRegisterMetaType<int64_t>("int64_t");
    qRegisterMetaType<uint64_t>("uint64_t");
    qRegisterMetaType<dc_msg_t*>("dc_msg_t*");
    //qRegisterMetaType<size_t>("size_t");

    qDebug() << "Starting app from main.cpp";

    QQuickView *view = new QQuickView();

    view->rootContext()->setContextProperty("i18nDirectory", I18N_DIRECTORY);

    // to be able to call myview.requestActivate() to bring the app
    // on top of all other windows on the desktop (only relevant
    // for non-UT platforms)
    view->rootContext()->setContextProperty("myview", view);

    view->setSource(QUrl("qrc:/Main.qml"));
    view->setResizeMode(QQuickView::SizeRootObjectToView);
    view->show();


    // Ubuntu Touch sets QT_FILE_SELECTOR=ubuntu-touch, so on Ubuntu
    // Touch, the engine will look in a subdir called "+ubuntu-touch"
    // first for any QML file
    QQmlFileSelector* selector = new QQmlFileSelector(view->engine());

    return app->exec();
}
