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

#ifndef JSONRPCRESPONSETHREAD_H
#define JSONRPCRESPONSETHREAD_H

#include <QtCore>
#include <QtGui>
#include <string>
#include "deltachat.h"

class JsonrpcResponseThread : public QThread {
    Q_OBJECT

    public:
        JsonrpcResponseThread(dc_jsonrpc_instance_t* jsoninst, std::atomic<bool>* _stopLoop);

        void run();

    signals:
        void newJsonrpcResponse(QString stringResponse);

    private:
        dc_jsonrpc_instance_t* m_jsonrpcInstance;
        std::atomic<bool>* m_stopLoop;
};

#endif
