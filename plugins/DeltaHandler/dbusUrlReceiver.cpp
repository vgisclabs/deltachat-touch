#include "dbusUrlReceiver.h"

DbusUrlReceiver::DbusUrlReceiver(DeltaHandler* dhandler, QObject* parent) : QDBusAbstractAdaptor(parent)
{
    m_deltahandler = dhandler;
}


void DbusUrlReceiver::receiveUrl(QString myUrl)
{
    m_deltahandler->processReceivedUrl(myUrl);
}
