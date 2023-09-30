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
                    qInfo().nospace() << "Emitter: DC_EVENT_CHAT_EPHEMERAL_TIMER_MODIFIED" << ", account " << dc_event_get_account_id(event) << ", chat_id: " << dc_event_get_data1_int(event) << ", timer val in s or 0 for disabled timer: " << dc_event_get_data2_int(event);
                    break;

                case DC_EVENT_CHAT_MODIFIED:
                    qInfo().nospace() << "Emitter: DC_EVENT_CHAT_MODIFIED" << ", account " << dc_event_get_account_id(event) << ", chat id: " << dc_event_get_data1_int(event);
                    emit chatDataModified(dc_event_get_account_id(event), dc_event_get_data1_int(event));
                    break;

                case DC_EVENT_CONFIGURE_PROGRESS:
                    eventData2Str = dc_event_get_data2_str(event);
                    if (eventData2Str) {
                        data2info = eventData2Str;
                    }
                    else {
                        data2info = "";
                    }
                    qInfo().nospace() << "Emitter: DC_EVENT_CONFIGURE_PROGRESS" << ", account " << dc_event_get_account_id(event) << ", progress from 1 - 1000, 0 = error: " << dc_event_get_data1_int(event) << ", comment/error: " << qUtf8Printable(data2info);
                    emit configureProgress(dc_event_get_data1_int(event), data2info);
                    break;

                case DC_EVENT_CONNECTIVITY_CHANGED:
                    qInfo().nospace() << "Emitter: DC_EVENT_CONNECTIVITY_CHANGED" << ", account " << dc_event_get_account_id(event);
                    emit connectivityChanged(dc_event_get_account_id(event));
                    break;
                    
                case DC_EVENT_CONTACTS_CHANGED:
                    qInfo().nospace() << "Emitter: DC_EVENT_CONTACTS_CHANGED" << ", account " << dc_event_get_account_id(event);
                    emit contactsChanged();
                    break;
                    
                case DC_EVENT_DELETED_BLOB_FILE:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_DELETED_BLOB_FILE" << ", account " << dc_event_get_account_id(event) << ", path name: " << qUtf8Printable(eventData2Str);
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
                    eventData2Str = dc_event_get_data2_str(event); 
                    qInfo().nospace() << "Emitter: DC_EVENT_ERROR" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    emit errorEvent(eventData2Str);
                    break;
                    
                case DC_EVENT_ERROR_SELF_NOT_IN_GROUP:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_ERROR_SELF_NOT_IN_GROUP" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    break;
                    
                case DC_EVENT_IMAP_CONNECTED:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_IMAP_CONNECTED" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    break;
                    
                case DC_EVENT_IMAP_INBOX_IDLE:
                    qInfo().nospace() << "Emitter: DC_EVENT_IMAP_INBOX_IDLE" << ", account " << dc_event_get_account_id(event);
                    break;

                case DC_EVENT_IMAP_MESSAGE_DELETED:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_IMAP_MESSAGE_DELETED" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    break;
                    
                case DC_EVENT_IMAP_MESSAGE_MOVED:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_IMAP_MESSAGE_MOVED" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    break;
                    
                case DC_EVENT_IMEX_FILE_WRITTEN:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_IMEX_FILE_WRITTEN" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    data2info = eventData2Str;
                    emit imexFileWritten(data2info);
                    break;
                    
                case DC_EVENT_IMEX_PROGRESS:
                    qInfo().nospace() << "Emitter: DC_EVENT_IMEX_PROGRESS" << ", account " << dc_event_get_account_id(event) << ", progress from 1 - 1000, 0 = error: " << dc_event_get_data1_int(event);
                    emit imexProgress(dc_event_get_data1_int(event));
                    break;
                    
                case DC_EVENT_INCOMING_MSG:
                    qInfo().nospace() << "Emitter: DC_EVENT_INCOMING_MSG" << ", account " << dc_event_get_account_id(event) << ", chat_id: " << dc_event_get_data1_int(event) << ", msg_id: " << dc_event_get_data2_int(event);
                    emit newMsg(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;
                    
                case DC_EVENT_INCOMING_MSG_BUNCH:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_INCOMING_MSG_BUNCH" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    // TODO: eventData2Str contains a json with the messge IDs.
                    // From the DC documentation:
                    // This is an event to allow the UI to only show one notification per
                    // message bunch, instead of cluttering the user with many
                    // notifications. For each of the msg_ids, an additional
                    // DC_EVENT_INCOMING_MSG event was emitted before.
                    break;
                    
                case DC_EVENT_INFO: 
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_INFO" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    break;

                case DC_EVENT_LOCATION_CHANGED:
                    qInfo().nospace() << "Emitter: DC_EVENT_LOCATION_CHANGED" << ", account " << dc_event_get_account_id(event) << ", contact_id: " << dc_event_get_data1_int(event);
                    break;

                case DC_EVENT_MSG_DELETED:
                    qInfo().nospace() << "Emitter: DC_EVENT_MSG_DELETED" << ", account " << dc_event_get_account_id(event) << ", chat_id: " << dc_event_get_data1_int(event) << ", msg_id: " << dc_event_get_data2_int(event);
                    break;


                case DC_EVENT_MSG_DELIVERED:
                    qInfo().nospace() << "Emitter: DC_EVENT_MSG_DELIVERED" << ", account " << dc_event_get_account_id(event) << ", chat_id: " << dc_event_get_data1_int(event) << ", msg_id: " << dc_event_get_data2_int(event);
                    emit msgDelivered(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;

                case DC_EVENT_MSG_FAILED:
                    qInfo().nospace() << "Emitter: DC_EVENT_MSG_FAILED" << ", account " << dc_event_get_account_id(event) << ", chat_id: " << dc_event_get_data1_int(event) << ", msg_id: " << dc_event_get_data2_int(event);
                    emit msgFailed(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;

                case DC_EVENT_MSG_READ:
                    qInfo().nospace() << "Emitter: DC_EVENT_MSG_READ" << ", account " << dc_event_get_account_id(event) << ", chat_id: " << dc_event_get_data1_int(event) << ", msg_id: " << dc_event_get_data2_int(event);
                    emit msgRead(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;

                case DC_EVENT_MSGS_CHANGED:
                    qInfo().nospace() << "Emitter: DC_EVENT_MSGS_CHANGED" << ", account " << dc_event_get_account_id(event) << ", chat_id (if multiple: 0): " << dc_event_get_data1_int(event) << ", msg_id (if multiple: 0): " << dc_event_get_data2_int(event);
                    emit msgsChanged(dc_event_get_account_id(event), dc_event_get_data1_int(event), dc_event_get_data2_int(event));
                    break;

                case DC_EVENT_MSGS_NOTICED:
                    qInfo().nospace() << "Emitter: DC_EVENT_MSGS_NOTICED" << ", account " << dc_event_get_account_id(event) << ", chat_id: " << dc_event_get_data1_int(event);
                    break;

                case DC_EVENT_NEW_BLOB_FILE:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_NEW_BLOB_FILE" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    break;

                case DC_EVENT_REACTIONS_CHANGED:
                    qInfo().nospace() << "Emitter: DC_EVENT_REACTIONS_CHANGED" << ", account " << dc_event_get_account_id(event) << ", chat_id: " << dc_event_get_data1_int(event) << ", msg_id: " << dc_event_get_data2_int(event);
                    break;

                case DC_EVENT_SECUREJOIN_INVITER_PROGRESS:
                    qInfo().nospace() << "Emitter: DC_EVENT_SECUREJOIN_INVITER_PROGRESS" << ", account " << dc_event_get_account_id(event) << ", contact_id: " << dc_event_get_data1_int(event) << ", progress: " << dc_event_get_data2_int(event);
                    break;

                case DC_EVENT_SECUREJOIN_JOINER_PROGRESS:
                    qInfo().nospace() << "Emitter: DC_EVENT_SECUREJOIN_JOINER_PROGRESS" << ", account " << dc_event_get_account_id(event) << ", contact_id: " << dc_event_get_data1_int(event) << ", progress: " << dc_event_get_data2_int(event);
                    break;

                case DC_EVENT_SELFAVATAR_CHANGED: 
                    qInfo().nospace() << "Emitter: DC_EVENT_SELFAVATAR_CHANGED" << ", account " << dc_event_get_account_id(event);
                    break;

                case DC_EVENT_SMTP_CONNECTED:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_SMTP_CONNECTED" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    break;

                case DC_EVENT_SMTP_MESSAGE_SENT:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_SMTP_MESSAGE_SENT" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    break;

                case DC_EVENT_WARNING:
                    eventData2Str = dc_event_get_data2_str(event);
                    qInfo().nospace() << "Emitter: DC_EVENT_WARNING" << ", account " << dc_event_get_account_id(event) << ": " << qUtf8Printable(eventData2Str);
                    break;

                case DC_EVENT_WEBXDC_INSTANCE_DELETED:
                    qInfo().nospace() << "Emitter: DC_EVENT_WEBXDC_INSTANCE_DELETED" << ", account " << dc_event_get_account_id(event) << ", msg_id: " << dc_event_get_data1_int(event);
                    break;

                case DC_EVENT_WEBXDC_STATUS_UPDATE:
                    qInfo().nospace() << "Emitter: DC_EVENT_WEBXDC_STATUS_UPDATE" << ", account " << dc_event_get_account_id(event);
                    // has parameters, but at least one of them (data2) must
                    // not be queried to avoid "races in the status replication".
                    break;

                default:
                    qInfo().nospace() << "Emitter: Unknown event received" << ", account " << dc_event_get_account_id(event) << ": " << eventType;
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
