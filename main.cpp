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
#include <QFile>
#include <QTextStream>
#include <QQuickView>
#include <QtWebEngine>
#include <iostream>
#include <cstdio>

// QtMessageHandler, a typedef for a pointer to a function with the following signature:
//
// void myMessageHandler(QtMsgType, const QMessageLogContext &, const QString &);
//
// For further info see the comment re logging in main()
void myMessageOutput(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QByteArray logMessage = msg.toLocal8Bit();

    QString logHeading(QDateTime::currentDateTime().toString("MMM dd hh:mm:ss "));

    if (context.file) {
        logHeading.append(context.file);
        logHeading.append(":");
        logHeading.append(QString::number(context.line));
        logHeading.append(": ");
    }

    // Currently not logging the function in which the message was generated
//    if (context.function) {
//        logHeading.append("in: ");
//        logHeading.append(context.function);
//    }

    // only needed for QtFatalMsg, to be able to rm -rf the cache dir
    QDir cachepath;

    // everything except qFatal messages will be redirected to std::cerr because
    // cerr is bound to logfile.txt via freopen in main()
    switch (type) {
    case QtDebugMsg:
        std::cerr << logHeading.toLocal8Bit().constData() << logMessage.constData() << "\n";
        break;
    case QtInfoMsg:
        std::cerr << logHeading.toLocal8Bit().constData() << "Info: " << logMessage.constData() << "\n";
        break;
    case QtWarningMsg:
        std::cerr << logHeading.toLocal8Bit().constData() << "Warning: " << logMessage.constData() << "\n";
        break;
    case QtCriticalMsg:
        std::cerr << logHeading.toLocal8Bit().constData() << "Critical: " << logMessage.constData() << "\n";
        break;
    case QtFatalMsg:
        // take care of removing the cache as DeltaHandler::shutdownTasks()
        // will not be called
        cachepath.setPath(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
        cachepath.removeRecursively();

        // Maybe not the best solution, but as we want this message to persist,
        // we can't send this message to cerr because cerr is bound to the
        // logfile in the cache which will be deleted when the app is exiting.
        // Feeding the message to std::cout will cause it to be logged by
        // journald.
        // No need for logHeading as journald will put a timestamp on it.
        std::cout << "Fatal: " << logMessage.constData() << std::endl;
        break;
    }
} // myMessageOutput

int main(int argc, char *argv[])
{
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
            qFatal("Could not create Cache directory, exiting");
        }
    }

    // Take care of logging. Log output will be written to "logfile.txt"
    // in the cache dir to avoid leaking data to journald, because
    // journald will keep the log long after the app has been closed,
    // even when the phone is not in developer mode.
    // The cache dir including the log file is removed when
    // the app closes regularly via DeltaHandler::shutdownTasks()
    // (but maybe not if the app is stopped irregularly).
    // Messages via qFatal() will appear in stderr and thus in journald
    // to be able to see reasons for fatal exits at least.
    //
    // If logging to <cache>/logfile.txt is changed, qml/LogViewer.qml has to be adapted.
    //
    // redirect stderr (and cerr) to a file, this is taking care
    // of the error messages of libdeltachat.so
    freopen((QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logfile.txt").toLocal8Bit().constData(), "w", stderr);
    // install a different message handler for Qt, this
    // will redirect Qt and QML console output and log messages
    // (via qDebug(), qWarning() etc.
    qInstallMessageHandler(myMessageOutput);

    // end logging part

    qRegisterMetaType<uint32_t>("uint32_t");
    qRegisterMetaType<int64_t>("int64_t");
    //qRegisterMetaType<size_t>("size_t");

    qDebug() << "Starting app from main.cpp";

    QQuickView *view = new QQuickView();
    view->setSource(QUrl("qrc:/Main.qml"));
    view->setResizeMode(QQuickView::SizeRootObjectToView);
    view->show();

    return app->exec();
}
