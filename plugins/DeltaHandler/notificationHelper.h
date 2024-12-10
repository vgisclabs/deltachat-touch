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

#ifndef NOTIFICATIONHELPER_H
#define NOTIFICATIONHELPER_H

#include <QObject>
#include <QString>

#include "../deltachat.h"

#include "deltahandler.h"
#include "emitterthread.h"
#include "accountsmodel.h"

class DeltaHandler;
class EmitterThread;
class AccountsModel;

// Not needed in the abstract class, but in two subclasses
struct IncomingMsgStruct {
    uint32_t accID;
    int chatID;
    int msgID;
};

/* 
 * Abstract class for notifications, cannot be instantiated. A specialized subclass has to be
 * selected that is suitable for the notification service present on the system running the app.
 */
class NotificationHelper : public QObject {
    Q_OBJECT

signals:
    void newMessageForInactiveAccount();

public:
    explicit NotificationHelper(DeltaHandler* dhandler, dc_accounts_t* accounts, EmitterThread* emthread, AccountsModel* accmodel);
    virtual ~NotificationHelper() = default;

    void setCurrentAccId(uint32_t newAccId);
    Q_INVOKABLE void setEnablePushNotifications(bool enabled);
    Q_INVOKABLE void setDetailedPushNotifications(bool detailed);
    Q_INVOKABLE void setNotifyContactRequests(bool notifContReq);
    virtual Q_INVOKABLE void removeSummaryNotification(uint32_t accID) = 0;
    virtual void removeNotification(QString tag) = 0;
    virtual void removeActiveNotificationsOfChat(uint32_t accID, int chatID) = 0;

protected:
    // set in constructor
    DeltaHandler* m_deltaHandler;
    dc_accounts_t* m_accountsManager;
    EmitterThread* m_emitterthread;
    AccountsModel* m_accountsmodel;
    // end set in constructor

    uint32_t m_currentAccID;
    bool m_enablePushNotifications;
    bool m_detailedPushNotifications;
    bool m_notifyContactRequests;
};

#endif // NOTIFICATIONHELPER_H
