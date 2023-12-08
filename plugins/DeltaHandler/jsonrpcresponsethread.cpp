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

#include "jsonrpcresponsethread.h"

JsonrpcResponseThread::JsonrpcResponseThread()
{
    m_jsonrpcInstance = nullptr;

}

void JsonrpcResponseThread::run()
{

    if (m_jsonrpcInstance) {
        char* response;
        while ((response = dc_jsonrpc_next_response(m_jsonrpcInstance)) != NULL) {
            QString stringResponse = response;
            dc_str_unref(response);
            
            emit newJsonrpcResponse(stringResponse);

        } // while
    } else {
         qDebug() << "JsonrpcResponseThread::run(): Fatal error: No dc_jsonrpc_instance_t defined, could not start response loop.";
    }
}


void JsonrpcResponseThread::setJsonrcpInstance(dc_jsonrpc_instance_t* jsoninst)
{
    m_jsonrpcInstance = jsoninst;
}
