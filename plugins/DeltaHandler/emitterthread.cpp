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

#include "emitterthread.h"

EmitterThread::EmitterThread()
{
    accounts = nullptr;
}

void EmitterThread::run()
{

    if (accounts) {
        dc_event_emitter_t* emitter = dc_accounts_get_event_emitter(accounts);
        dc_event_t* event;
        while ((event = dc_get_next_event(emitter)) != NULL) {
            int eventType {0};
            char* eventData2Str {nullptr};
            QString data2info;

            eventType = dc_event_get_id(event);
            switch (eventType) {
                case DC_EVENT_CHAT_EPHEMERAL_TIMER_MODIFIED:
                    qDebug() << "Emitter: DC_EVENT_CHAT_EPHEMERAL_TIMER_MODIFIED";
                    qDebug() << "Emitter: chat_id: " << dc_event_get_data1_int(event);
                    qDebug() << "Emitter: timer val in s or 0 for disabled timer: " << dc_event_get_data2_int(event);
                    break;

                case DC_EVENT_CHAT_MODIFIED:
                    qDebug() << "Emitter: DC_EVENT_CHAT_MODIFIED";
                    qDebug() << "Emitter: chat id: " << dc_event_get_data1_int(event);
                    break;

                case DC_EVENT_CONFIGURE_PROGRESS:
                    qDebug() << "Emitter: DC_EVENT_CONFIGURE_PROGRESS";
                    qDebug() << "Emitter: Progress from 1 - 1000, 0 = error: " << dc_event_get_data1_int(event);
                    eventData2Str = dc_event_get_data2_str(event);
                    if (eventData2Str) {
                        qDebug() << "Emitter: Comment/Error: " << eventData2Str;
                        data2info = eventData2Str;
                    }
                    else {
                        data2info = "";
                    }
                    emit configureProgress(dc_event_get_data1_int(event), data2info);
                    break;

                case DC_EVENT_CONNECTIVITY_CHANGED:
                    qDebug() << "Emitter: DC_EVENT_CONNECTIVITY_CHANGED";
                    break;
                    
                case DC_EVENT_CONTACTS_CHANGED:
                    qDebug() << "Emitter: DC_EVENT_CONTACTS_CHANGED";
                    emit contactsChanged();
                    break;
                    
                case DC_EVENT_DELETED_BLOB_FILE:
                    qDebug() << "Emitter: DC_EVENT_DELETED_BLOB_FILE";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: Path name: " << eventData2Str;
                    break;
                    
                case DC_EVENT_ERROR:
                    /*
                     * TODO:
                     * The library-user should report an error to the end-user.
                     *
                     * As most things are asynchronous, things may go wrong at any time and the user
                     * should not be disturbed by a dialog or so. Instead, use a bubble or so.

                     * However, for ongoing processes (e.g. dc_configure()) or for functions that are
                     * expected to fail (e.g. dc_continue_key_transfer()) it might be better to delay
                     * showing these events until the function has really failed (returned false). It
                     * should be sufficient to report only the last error in a message box then.
                     */
                    qDebug() << "Emitter: DC_EVENT_ERROR";
                    eventData2Str = dc_event_get_data2_str(event); 
                    qDebug() << "Emitter: " << eventData2Str;
                    break;
                    
                case DC_EVENT_ERROR_SELF_NOT_IN_GROUP:
                    qDebug() << "Emitter: DC_EVENT_ERROR_SELF_NOT_IN_GROUP";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    break;
                    
                case DC_EVENT_IMAP_CONNECTED:
                    qDebug() << "Emitter: DC_EVENT_IMAP_CONNECTED";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    break;
                    
                case DC_EVENT_IMAP_MESSAGE_DELETED:
                    qDebug() << "Emitter: DC_EVENT_IMAP_MESSAGE_DELETED";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    break;
                    
                case DC_EVENT_IMAP_MESSAGE_MOVED:
                    qDebug() << "Emitter: DC_EVENT_IMAP_MESSAGE_MOVED";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    break;
                    
                case DC_EVENT_IMEX_FILE_WRITTEN:
                    qDebug() << "Emitter: DC_EVENT_IMEX_FILE_WRITTEN";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    data2info = eventData2Str;
                    emit imexFileWritten(data2info);
                    break;
                    
                case DC_EVENT_IMEX_PROGRESS:
                    qDebug() << "Emitter: DC_EVENT_IMEX_PROGRESS";
                    qDebug() << "Emitter: Progress from 1 - 1000, 0 = error: " << dc_event_get_data1_int(event);
                    emit imexProgress(dc_event_get_data1_int(event));
                    break;
                    
                case DC_EVENT_INCOMING_MSG:
                    qDebug() << "Emitter: DC_EVENT_INCOMING_MSG";
                    qDebug() << "Emitter: account_id: " << dc_event_get_account_id(event);
                    qDebug() << "Emitter: chat_id: " << dc_event_get_data1_int(event);
                    qDebug() << "Emitter: msg_id: " << dc_event_get_data2_int(event);
                    emit newMsg(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;
                    
//                    // not implemented yet in the version of the lib we use
//                case DC_EVENT_INCOMING_MSG_BUNCH:
//                    // TODO? 
//                    qDebug() << "Emitter: DC_EVENT_INCOMING_MSG_BUNCH";
//                    eventData2Str = dc_event_get_data2_str(event);
//                    qDebug() << "Emitter: " << eventData2Str;
//                    break;
                    
                case DC_EVENT_INFO: 
                    qDebug() << "Emitter: DC_EVENT_INFO";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    break;

                case DC_EVENT_LOCATION_CHANGED:
                    qDebug() << "Emitter: DC_EVENT_LOCATION_CHANGED";
                    qDebug() << "Emitter: contact_id: " << dc_event_get_data1_int(event);
                    break;

                case DC_EVENT_MSG_DELIVERED:
                    /* TODO */
                    qDebug() << "Emitter: DC_EVENT_MSG_DELIVERED";
                    qDebug() << "Emitter: chat_id: " << dc_event_get_data1_int(event);
                    qDebug() << "Emitter: msg_id: " << dc_event_get_data2_int(event);
                    emit msgDelivered(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;

                case DC_EVENT_MSG_FAILED:
                    qDebug() << "Emitter: DC_EVENT_MSG_FAILED";
                    qDebug() << "Emitter: chat_id: " << dc_event_get_data1_int(event);
                    qDebug() << "Emitter: msg_id: " << dc_event_get_data2_int(event);
                    emit msgFailed(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;

                case DC_EVENT_MSG_READ:
                    qDebug() << "Emitter: DC_EVENT_MSG_READ";
                    qDebug() << "Emitter: account_id: " << dc_event_get_account_id(event);
                    qDebug() << "Emitter: chat_id: " << dc_event_get_data1_int(event);
                    qDebug() << "Emitter: msg_id: " << dc_event_get_data2_int(event);
                    emit msgRead(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;

                case DC_EVENT_MSGS_CHANGED:
                    qDebug() << "Emitter: DC_EVENT_MSGS_CHANGED";
                    qDebug() << "Emitter: account_id: " << dc_event_get_account_id(event);
                    qDebug() << "Emitter: chat_id (if multiple: 0): " << dc_event_get_data1_int(event);
                    qDebug() << "Emitter: msg_id (if multiple: 0): " << dc_event_get_data2_int(event);
                    // TODO: check if it is sufficient to handle this event to update the
                    // chat view when we have sent a message
                    // or maybe it should be a different signal?
                    emit msgsChanged(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;

                case DC_EVENT_MSGS_NOTICED:
                    qDebug() << "Emitter: DC_EVENT_MSGS_NOTICED";
                    qDebug() << "Emitter: chat_id: " << dc_event_get_data1_int(event);
                    break;

                case DC_EVENT_NEW_BLOB_FILE:
                    qDebug() << "Emitter: DC_EVENT_NEW_BLOB_FILE";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    break;

//                    // not implemented yet in the version of the lib we use
//                case DC_EVENT_REACTIONS_CHANGED:
//                    qDebug() << "Emitter: chat_id: " << dc_event_get_data1_int(event);
//                    qDebug() << "Emitter: msg_id: " << dc_event_get_data2_int(event);
//                    break;

                case DC_EVENT_SECUREJOIN_INVITER_PROGRESS:
                    qDebug() << "Emitter: DC_EVENT_SECUREJOIN_INVITER_PROGRESS";
                    qDebug() << "Emitter: contact_id: " << dc_event_get_data1_int(event);
                    qDebug() << "Emitter: progress: " << dc_event_get_data2_int(event);
                    break;

                case DC_EVENT_SECUREJOIN_JOINER_PROGRESS:
                    qDebug() << "Emitter: DC_EVENT_SECUREJOIN_JOINER_PROGRESS";
                    qDebug() << "Emitter: contact_id: " << dc_event_get_data1_int(event);
                    qDebug() << "Emitter: progress: " << dc_event_get_data2_int(event);
                    break;

                case DC_EVENT_SELFAVATAR_CHANGED: 
                    qDebug() << "Emitter: DC_EVENT_SELFAVATAR_CHANGED";
                    break;

                case DC_EVENT_SMTP_CONNECTED:
                    qDebug() << "Emitter: DC_EVENT_SMTP_CONNECTED";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    break;

                case DC_EVENT_SMTP_MESSAGE_SENT:
                    qDebug() << "Emitter: DC_EVENT_SMTP_MESSAGE_SENT";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    break;

                case DC_EVENT_WARNING:
                    qDebug() << "Emitter: DC_EVENT_WARNING";
                    eventData2Str = dc_event_get_data2_str(event);
                    qDebug() << "Emitter: " << eventData2Str;
                    break;

                case DC_EVENT_WEBXDC_INSTANCE_DELETED:
                    qDebug() << "Emitter: DC_EVENT_WEBXDC_INSTANCE_DELETED";
                    qDebug() << "Emitter: msg_id: " << dc_event_get_data1_int(event);
                    break;

                case DC_EVENT_WEBXDC_STATUS_UPDATE:
                    qDebug() << "Emitter: DC_EVENT_WEBXDC_STATUS_UPDATE";
                    // has parameters, but at least one of them must
                    // not be queried.
                    break;

                default:
                    qDebug() << "Emitter: Unknown event received: " << eventType;
            }


            if (eventData2Str) {
                dc_str_unref(eventData2Str);
                eventData2Str = nullptr;
            }

            dc_event_unref(event);
        } // while

        dc_event_emitter_unref(emitter);
    }

    else {
         qDebug() << "Emitter: Fatal error: No account defined, could not start emitter.";
    }
}


void EmitterThread::setAccounts(dc_accounts_t* accs)
{
    accounts = accs;
}
