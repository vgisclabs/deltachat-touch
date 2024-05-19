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

#ifndef NOTIFICATIONSLOMIRIPOSTAL_H
#define NOTIFICATIONSLOMIRIPOSTAL_H

#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QString>

#include <vector>

#include "notificationHelper.h"

/* 
 * Used to manage notifications via com.ubuntu.Postal DBus service
 */
class NotificationsLomiriPostal : public NotificationHelper {
    Q_OBJECT

public:
    NotificationsLomiriPostal(DeltaHandler* dhandler, dc_accounts_t* accounts, EmitterThread* emthread, AccountsModel* accmodel, QDBusConnection* m_bus);
    ~NotificationsLomiriPostal() override;

    Q_INVOKABLE void removeSummaryNotification(uint32_t accID) override;
    void removeNotification(QString tag) override;
    void removeActiveNotificationsOfChat(uint32_t accID, int chatID) override;

protected slots:
    void processIncomingMessage(uint32_t accID, int chatID, int msgID);
    void processIncomingMsgBunch(uint32_t accID);
    void finishProcessIncomingMsgBunch(QDBusPendingCallWatcher* call);
    void finishRemoveSummaryNotification(QDBusPendingCallWatcher* call);
    void finishRemoveActiveNotificationsOfChat(QDBusPendingCallWatcher* call);

protected:
    // Caching incoming msgs along with their accIDs and chatIDs.
    // Will then be processed once the incoming msg bunch
    // event is received.
    std::vector<IncomingMsgStruct> m_incomingMsgCache;
    std::vector<uint32_t> m_accIDsToProcess;
    bool m_dbusListPersistentReplyPending;

    std::vector<uint32_t> m_accIDsToRemoveSummaryNotifs;
    bool m_dbusRemoveSummaryNotifsPending;

    QDBusConnection* m_bus;
 
    // used to store the beginning of tags that should
    // maybe be removed, consists of <accID>_<chatID>_, will
    // be set in removeActiveNotificationsOfChat and used
    // in finishRemoveActiveNotificationsOfChat
    std::vector<QString> m_notificationTagsToDelete;
    bool m_notifTagsToDeletePendingReply;

    // protected methods
    void createDetailedNotification(uint32_t accID, int chatID, int msgID);
    void createSummaryNotification(uint32_t accID, int numberOfMessages, bool showSelfAvatar);
    void sendNotification(QString summary, QString body, QString tag, QString icon);
};

#endif // NOTIFICATIONSLOMIRIPOSTAL_H
