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

#ifndef NOTIFICATIONGENERATOR_H
#define NOTIFICATIONGENERATOR_H

#include <QObject>
#include <QString>
#include <vector>

#include "deltachat.h"

#include "deltahandler.h"
#include "emitterthread.h"
#include "accountsmodel.h"

class DeltaHandler;
class EmitterThread;
class AccountsModel;

struct IncomingMsgStruct {
    uint32_t accID;
    int chatID;
    int msgID;
};

class NotificationGenerator : public QObject {
    Q_OBJECT

signals:
    void newMessageForInactiveAccount();

public:
    explicit NotificationGenerator(DeltaHandler* dhandler, dc_accounts_t* accounts, EmitterThread* emthread, AccountsModel* accmodel);
    ~NotificationGenerator();

    void setCurrentAccId(uint32_t newAccId);
    Q_INVOKABLE void setEnablePushNotifications(bool enabled);
    Q_INVOKABLE void setDetailedPushNotifications(bool detailed);
    Q_INVOKABLE void setNotifyContactRequests(bool notifContReq);
    Q_INVOKABLE void removeSummaryNotification(uint32_t accID);

private slots:
    void processIncomingMessage(uint32_t accID, int chatID, int msgID);
    void processIncomingMsgBunch(uint32_t accID);
    void finishProcessIncomingMsgBunch(QDBusPendingCallWatcher* call);
    void finishRemoveSummaryNotification(QDBusPendingCallWatcher* call);

private:
    // set in constructor
    DeltaHandler* m_deltaHandler;
    dc_accounts_t* m_accountsManager;
    EmitterThread* m_emitterthread;
    AccountsModel* m_accountsmodel;
    uint32_t m_currentAccID;
    // end set in constructor

    bool m_enablePushNotifications;
    bool m_detailedPushNotifications;
    bool m_notifyContactRequests;

    // Caching incoming msgs along with their accIDs and chatIDs.
    // Will then be processed once the incoming msg bunch
    // event is received.
    std::vector<IncomingMsgStruct> m_incomingMsgCache;
    std::vector<uint32_t> m_accIDsToProcess;
    bool m_dbusListPersistentReplyPending;

    std::vector<uint32_t> m_accIDsToRemoveSummaryNotifs;
    bool m_dbusRemoveSummaryNotifsPending;

    // private methods
    void sendDetailedNotification(uint32_t accID, int chatID, int msgID);
    void sendSummaryNotification(uint32_t accID, int numberOfMessages, bool showSelfAvatar);
    void createNotification(QString summary, QString body, QString tag, QString icon);
    void removeNotification(QString tag);
};

#endif // NOTIFICATIONGENERATOR_H
