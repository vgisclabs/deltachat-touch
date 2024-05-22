#ifndef DBUSURLRECEIVER_H
#define DBUSURLRECEIVER_H

#include <QDBusAbstractAdaptor>
#include <QObject>
#include <QString>
#include "deltahandler.h"

class DeltaHandler;

// On non-UT platforms, an instance of this class will be registered
// as DBus object /deltatouch/urlreceiver of the below listed interface.
// If a different program sends an URL to the app, a second instance of the app
// will be opened with the URL as parameter. This second instance checks
// whether another instance is already running (see main.cpp). If yes,
// it will send the parameter to this object of the first instance via DBus.
class DbusUrlReceiver : QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "local.deltatouch")

    public:
        DbusUrlReceiver(DeltaHandler* dhandler, QObject* parent = nullptr);

    public slots:
        Q_NOREPLY void receiveUrl(QString myUrl);

    private:
        DeltaHandler* m_deltahandler;
};

#endif // DBUSURLRECEIVER_H
