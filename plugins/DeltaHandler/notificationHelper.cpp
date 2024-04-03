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

#include "notificationHelper.h"


NotificationHelper::NotificationHelper(DeltaHandler* dhandler, dc_accounts_t* accounts, EmitterThread* emthread, AccountsModel* accmodel)
    : QObject(nullptr)
{
    m_deltaHandler = dhandler;
    m_accountsManager = accounts;
    m_emitterthread = emthread;
    m_accountsmodel = accmodel;
}


void NotificationHelper::setCurrentAccId(uint32_t newAccId)
{
    m_currentAccID = newAccId;
}


void NotificationHelper::setEnablePushNotifications(bool enabled)
{
    m_enablePushNotifications = enabled;
}


void NotificationHelper::setDetailedPushNotifications(bool detailed)
{
    m_detailedPushNotifications = detailed;
}


void NotificationHelper::setNotifyContactRequests(bool notifContReq)
{
    m_notifyContactRequests = notifContReq;
}
