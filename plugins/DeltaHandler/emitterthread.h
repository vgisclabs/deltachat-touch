/*
 * Copyright (C) 2023  Lothar Ketterer
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

#ifndef EMITTERTHREAD_H
#define EMITTERTHREAD_H

#include <QtCore>
#include <QtGui>
#include <string>
#include "deltachat.h"

class EmitterThread : public QThread {
    Q_OBJECT

    public:
        EmitterThread(dc_accounts_t* accs);

        void run();

    signals:
            void newMsg(uint32_t accID, int chatID, int msgID);
            void msgsChanged(uint32_t accID, int chatID, int msgID);
            void msgsNoticed(uint32_t accID, int chatID);
            void msgFailed(uint32_t accID, int chatID, int msgID);
            void msgDelivered(uint32_t accID, int chatID, int msgID);
            void msgRead(uint32_t accID, int chatID, int msgID);
            void reactionsChanged(uint32_t accID, int chatID, int msgID);
            void configureProgress(int permill, QString errorMsg);
            void imexProgress(int permill);
            void imexFileWritten(QString filepath);
            void contactsChanged();
            void errorEvent(QString errorMessage);
            void chatDataModified(uint32_t accID, int chatID);
            void connectivityChanged(uint32_t accID);

    private:
        dc_accounts_t* accounts;
};

#endif
