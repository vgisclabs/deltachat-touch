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

#ifndef NOTIFICATIONSMISSING_H
#define NOTIFICATIONSMISSING_H

#include <QString>

#include "notificationHelper.h"

/*
 * Class to be used as dummy if no possibility exists to send notifications, so the
 * app can have a pointer to NotificationHelper and make generic calls to methods
 * defined in NotificationHelper.h.
 */
class NotificationsMissing : public NotificationHelper {
    Q_OBJECT

public:
    NotificationsMissing(DeltaHandler* dhandler, dc_accounts_t* accounts, EmitterThread* emthread, AccountsModel* accmodel);

    Q_INVOKABLE void removeSummaryNotification(uint32_t accID) override {};
    void removeNotification(QString tag) override {};
    void removeActiveNotificationsOfChat(uint32_t accID, int chatID) override {};
};

#endif // NOTIFICATIONSMISSING_H
