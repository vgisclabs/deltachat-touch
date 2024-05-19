#ifndef DBUSURLRECEIVER_H
#define DBUSURLRECEIVER_H

#include <QDBusAbstractAdaptor>
#include <QObject>
#include <QString>
#include "deltahandler.h"

class DeltaHandler;

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
