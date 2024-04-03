/*
 * Copyright (C) 2024  Lothar Ketterer
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

#ifndef NOTIFICATIONSFREEDESKTOP_H
#define NOTIFICATIONSFREEDESKTOP_H

#include <QDBusPendingCallWatcher>
#include <QDBusConnection>
#include <QString>
#include <QMap>

#include <vector>

#include "notificationHelper.h"

/* 
 * Used to manage notifications via org.freedesktop.Notifications DBus service
 */
class NotificationsFreedesktop : public NotificationHelper {
    Q_OBJECT

public:
    NotificationsFreedesktop(DeltaHandler* dhandler, dc_accounts_t* accounts, EmitterThread* emthread, AccountsModel* accmodel, QDBusConnection* bus);
    ~NotificationsFreedesktop() override;

    Q_INVOKABLE void removeSummaryNotification(uint32_t accID) override;
    void removeNotification(QString tag) override;
    void removeActiveNotificationsOfChat(uint32_t accID, int chatID) override;

protected slots:
    void processIncomingMessage(uint32_t accID, int chatID, int msgID);
    void processIncomingMsgBunch(uint32_t accID);
    void getDbusResponseForNotifyCall(QDBusPendingCallWatcher* call);
    void processNotificationClosedDbusSignal(unsigned int id, unsigned int reason);

protected:
    // Caching incoming msgs along with their accIDs and chatIDs.
    // Will then be processed once the incoming msg bunch
    // event is received.
    std::vector<IncomingMsgStruct> m_incomingMsgCache;

    // When creating a call watcher for the Notify DBus method, the pointer to it
    // is saved along with the tag of the notification. This enables
    // to close the notification later on.
    QMap<QDBusPendingCallWatcher*, QString> m_callTagCorrelation;

    // Intended to map tags to actual notification IDs as assigned by
    // the Freedesktop DBus Notification service. The value type
    // cannot be just int as the same tag might be generated multiple
    // times (e.g., for summary notifications).
    QMap<QString, std::vector<unsigned int>> m_tagNotificationIdCorrelation;

    QDBusConnection* m_bus;

    // protected methods
    void createDetailedNotification(uint32_t accID, int chatID, int msgID);
    void createSummaryNotification(uint32_t accID, int numberOfMessages, bool showSelfAvatar);
    void sendNotification(QString summary, QString body, QString tag, QString icon);
};

#endif // NOTIFICATIONSFREEDESKTOP_H
