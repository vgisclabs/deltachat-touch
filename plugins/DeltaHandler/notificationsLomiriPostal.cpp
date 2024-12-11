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

#include <QFile>
#include <QStandardPaths>
#include <QtDBus/QDBusMessage>
#include <QDBusPendingReply>
#include <QDBusError>
#include <QJsonValue>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>

#include "notificationsLomiriPostal.h"

namespace C {
#include <libintl.h>
}


NotificationsLomiriPostal::NotificationsLomiriPostal(DeltaHandler* dhandler, dc_accounts_t* accounts, EmitterThread* emthread, AccountsModel* accmodel, QDBusConnection* bus)
    : NotificationHelper(dhandler, accounts, emthread, accmodel), m_dbusListPersistentReplyPending {false}, m_dbusRemoveSummaryNotifsPending {false}, m_bus {bus}, m_notifTagsToDeletePendingReply {false}
{
    bool connectSuccess = connect(m_emitterthread, SIGNAL(newMsg(uint32_t, int, int)), this, SLOT(processIncomingMessage(uint32_t, int, int)));
    if (!connectSuccess) {
        qFatal("NotificationsLomiriPostal::NotificationsLomiriPostal(): Could not connect signal newMsg to slot incomingMessage");
    }

    connectSuccess = connect(m_emitterthread, SIGNAL(incomingMsgBunch(uint32_t)), this, SLOT(processIncomingMsgBunch(uint32_t)));
    if (!connectSuccess) {
        qFatal("NotificationsLomiriPostal::NotificationsLomiriPostal(): Could not connect signal incomingMsgBunch to slot processIncomingMsgBunch");
    }
}


NotificationsLomiriPostal::~NotificationsLomiriPostal()
{
    disconnect(m_emitterthread, SIGNAL(newMsg(uint32_t, int, int)), this, SLOT(incomingMessage(uint32_t, int, int)));
    disconnect(m_emitterthread, SIGNAL(incomingMsgBunch(uint32_t)), this, SLOT(processIncomingMsgBunch(uint32_t)));
}


void NotificationsLomiriPostal::processIncomingMessage(uint32_t accID, int chatID, int msgID)
{
    // When the event DC_INCOMING_MSG is received, just store the information in
    // m_incomingMsgCache. It will be processed when the core has finished
    // fetching the messages and emits the DC_INCOMING_MSG_BUNCH event.
    //
    // Don't create notifications if disabled in settings or if the account is muted
    if (m_enablePushNotifications && !(m_accountsmodel->accountIsMuted(accID))) {
        m_incomingMsgCache.push_back(IncomingMsgStruct {accID, chatID, msgID});
    }
}


void NotificationsLomiriPostal::processIncomingMsgBunch(uint32_t accID)
{
    // The signal for DC_EVENT_INCOMING_MSG_BUNCH is used to
    // trigger notification generation.

    if (!m_enablePushNotifications) {
        // Notifications disabled in the settings, so just
        // remove all cached messages. Done here in addition
        // to not adding anything to m_incomingMsgCache
        // because fetching msgs could take some time and the user
        // might disable the setting in the meantime.
        m_incomingMsgCache.resize(0);
        m_accIDsToProcess.resize(0);
        return;
    }

    // Aim is to not have more than 9 detailed notifications per
    // account, including the already existing notifications.
    // The list of existing ("persistent") notifications is
    // obtained via a DBus call to com.lomiri.Postal.
    // The response is obtained via a signal, so it's possible
    // that another call to processIncomingMsgBunch() occurs
    // while the previous one has not been processed yet. For
    // this reason, the accIDs to process is added to a vector
    // and the DBus method call is protected.
    
    m_accIDsToProcess.push_back(accID);

    if (m_dbusListPersistentReplyPending) {
        // the DBus method ListPersistent has already
        // been called, we're waiting for the response
        return;
    }

    m_dbusListPersistentReplyPending = true;

    QString appid("deltatouch.lotharketterer_deltatouch");
    QDBusMessage message;
    message = QDBusMessage::createMethodCall("com.lomiri.Postal", "/com/lomiri/Postal/deltatouch_2elotharketterer", "com.lomiri.Postal", "ListPersistent");

    message << appid;

    QDBusPendingCall pcall = m_bus->asyncCall(message);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);
    connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this, SLOT(finishProcessIncomingMsgBunch(QDBusPendingCallWatcher*)));
}


void NotificationsLomiriPostal::finishProcessIncomingMsgBunch(QDBusPendingCallWatcher* call)
{
    m_dbusListPersistentReplyPending = false;

    // Make sure the type of QDBusPendingReply matches the signature of the
    // expected DBus response. In this case, the signature is "as" (== array
    // of strings, i.e. QStringList)
    QDBusPendingReply<QStringList> reply = *call;
    QStringList taglist;

    if (reply.isError()) {
        QDBusError myerror = reply.error();
        qDebug() << "NotificationsLomiriPostal::finishProcessIncomingMsgBunch(): DBus error " << myerror.name() << ", message is: " << myerror.message();
        qDebug() << "NotificationsLomiriPostal::finishProcessIncomingMsgBunch(): Notification limit cannot be guaranteed";
        // taglist will remain empty
    } else { // no error, got valid DBus reply
        // the tags of the currently active notifications
        taglist = reply.argumentAt<0>();
    }

    call->deleteLater();

    if (!m_enablePushNotifications) {
        // Notifications disabled in the settings, so just
        // remove all cached messages. Done here in addition
        // to not adding anything to m_incomingMsgCache
        // because fetching msgs could take some time and the user
        // might disable the setting in the meantime.
        m_incomingMsgCache.resize(0);
        m_accIDsToProcess.resize(0);
        return;
    }

    // no chat opened if this call returns -1
    int currentChatID = m_deltaHandler->getCurrentChatId();

    for (size_t m = 0; m < m_accIDsToProcess.size(); ++m) {
        // No check for muted account because incoming msgs for muted
        // accounts are not added to m_incomingMsgCache
        uint32_t accID = m_accIDsToProcess[m];

        // don't send a notification if the user is looking at the chatlist of
        // the account for which a message was received...
        if (accID == m_currentAccID && -1 == currentChatID && QGuiApplication::applicationState() == Qt::ApplicationActive) {
            // ...but remove all cached IDs for this accID
            size_t i = 0;
            size_t endpos = m_incomingMsgCache.size();
            while (i < endpos) {
                if (m_incomingMsgCache[i].accID == accID) {
                    m_incomingMsgCache.erase(m_incomingMsgCache.begin() + i);
                    --endpos;
                } else {
                    // only increase if no item removed
                    ++i;
                }
            }
        }

        // sort out message IDs for which no notification
        // should be created:
        // - muted chats
        // - contact requests if the corresponding setting is off
        // - the chat the user is currently looking at, if any and if
        //   the app is active
        //
        // Cache the info about whether a notification should
        // be generated for a certain chat nor not
        struct SendNotifForChatStruct { int chatID; bool shouldSendNotification; };
        std::vector<SendNotifForChatStruct> chatInfoVec;

        // The context of accID is needed for several operations later on
        // (don't exit without unreferencing it!).
        dc_context_t* tempCon = dc_accounts_get_account(m_accountsManager, accID);

        // go through m_incomingMsgCache and put only those IDs for which a notification
        // should be created into messagesToNotify. The vector is of type
        // IncomingMsgStruct, i.e., contains accID, chatID, msgID
        std::vector<IncomingMsgStruct> messagesToNotify;


        size_t i = 0;
        size_t endpos = m_incomingMsgCache.size();

        while (i < endpos) {
            if (m_incomingMsgCache[i].accID != accID) {
                // cached incoming message does not belong to the account
                // for which the DC_EVENT_INCOMING_MSG_BUNCH event
                // was received, so just leave it in the cache
                ++i;
                continue;
            }

            int tempChatID = m_incomingMsgCache[i].chatID;

            // see if we already know whether a notification has to be
            // sent for this chat or not
            bool isInChatInfoVec = false;

            // true by default, will be sent to false if any of the
            // do-not-notify conditions is fulfilled
            bool needToSendNotif = true;

            for (size_t j = 0; j < chatInfoVec.size(); ++j) {
                SendNotifForChatStruct tempStruct = chatInfoVec[j];
                if (tempStruct.chatID == tempChatID) {
                    isInChatInfoVec = true;
                    needToSendNotif = tempStruct.shouldSendNotification;
                    break;
                }
            }

            if (!isInChatInfoVec) {
                // we did not find it in chatInfoVec, obtain the info
                // whether a notification has to be sent
                dc_chat_t* tempChat = dc_get_chat(tempCon, tempChatID);

                // is the chat muted?
                if (1 == dc_chat_is_muted(tempChat)) {
                    needToSendNotif = false;

                // or is the chat a contact request, and contact requests
                // should not be shown?
                } else if (1 == dc_chat_is_contact_request(tempChat) && !m_notifyContactRequests) {
                    needToSendNotif = false;

                // or is the user looking at the chat in question?
                } else if (accID == m_currentAccID && tempChatID == currentChatID && QGuiApplication::applicationState() == Qt::ApplicationActive) {
                    needToSendNotif = false;
                }

                // add the info about the chat to chatInfoVec
                chatInfoVec.push_back(SendNotifForChatStruct {tempChatID, needToSendNotif});

                dc_chat_unref(tempChat);
            }

            // now needToSendNotif is valid
            if (needToSendNotif) {
                messagesToNotify.push_back(IncomingMsgStruct { accID, tempChatID, m_incomingMsgCache[i].msgID });
            }

            // delete the entry from the cache
            m_incomingMsgCache.erase(m_incomingMsgCache.begin() + i);
            --endpos;
            // do not increase i; this has only to be done if no
            // item is removed (see the "continue" case above where the accID
            // of the entry in the cache does not equal the one from the event)
        }

        dc_context_unref(tempCon);

        // messagesToNotify now contains all messages for which a notification
        // should be sent. Stop here if there are no messages for which
        // a notification has to be created.
        if (messagesToNotify.size() == 0) {
            continue;
        }

        // For the GUI to adapt the counter for new messages in
        // other / incative accounts
        if (accID != m_currentAccID) {
            emit newMessageForInactiveAccount();
        }

        // Check how many notifications are already present
        // in the system for this account

        int numberOfPresentNotifications {0};
        QStringList tagsToMaybeDelete;

        for (int n = 0; n < taglist.size(); ++n) {
            QString tempTag = taglist[n];
            QStringList templist = tempTag.split('_');

            QString accNumberString;
            accNumberString.setNum(accID);

            // if details should not be shown in notifications,
            // there are no separate counts per account, so
            // never skip any present notification if !m_detailedPushNotifications
            if (m_detailedPushNotifications && templist.at(0) != accNumberString) {
                continue;
            }

            // tempTag belongs to accID
            tagsToMaybeDelete.append(tempTag);

            if (templist.at(1) == "summary") {
                numberOfPresentNotifications += templist.at(2).toInt();
            } else {
                ++numberOfPresentNotifications;
            }
        }

        // Trigger the notification depending on settings
        // and the number of notifications to be generated
        if (m_detailedPushNotifications) {
            if ((messagesToNotify.size() + numberOfPresentNotifications) > 9) {
                // don't send out a notification for each message if there 
                // are more than 9 messages to notify
                // First, delete the old notifications
                for (int o = 0; o < tagsToMaybeDelete.size(); ++o) {
                    removeNotification(tagsToMaybeDelete[o]);
                }
                createSummaryNotification(accID, messagesToNotify.size() + numberOfPresentNotifications, true);
            } else {
                for (size_t l = 0; l < messagesToNotify.size(); ++l) {
                    IncomingMsgStruct tempStruct = messagesToNotify[l];
                    createDetailedNotification(tempStruct.accID, tempStruct.chatID, tempStruct.msgID);
                }
            }
        } else { // if (m_detailedPushNotifications)
            for (int o = 0; o < tagsToMaybeDelete.size(); ++o) {
                removeNotification(tagsToMaybeDelete[o]);
            }
            createSummaryNotification(0, messagesToNotify.size() + numberOfPresentNotifications, false);
        }
    }

    m_accIDsToProcess.resize(0);
}


void NotificationsLomiriPostal::createSummaryNotification(uint32_t accID, int numberOfMessages, bool showSelfAvatar)
{
    QString icon;
    if (showSelfAvatar) {
        dc_context_t* tempCon = dc_accounts_get_account(m_accountsManager, accID);

        char* tempText = dc_get_config(tempCon, "selfavatar");
        icon = tempText;
        dc_str_unref(tempText);
    
        dc_context_unref(tempCon);
    }

    // use the app icon if the avatar of the account should not be
    // shown or if no selfavatar is set for the account
    if (!showSelfAvatar || icon == "") {
        QFile logoFile(":assets/logo.svg");
        logoFile.copy(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg");
        icon = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg";
    }

    QString notifTitle;
    QString notifBody;

    // The correct way would be to have the corresponding plural cases defined 
    // in the po files and use ngettext like this:
    //notifTitle = C::ngettext("New message", "New messages", numberOfMessages);
    //notifBody = QString(C::ngettext("%1 new message", "%1 new messages", numberOfMessages)).arg(numberOfMessages);
    //
    // However, in the xml language files from the DC Transifex project, the specifiers are "few", "many",
    // "other" - how exactly should that be converted to the po files? It doesn't seem to correspond to
    // the plural cases as in, e.g., Polish => TODO: check and solve correctly
    //
    // Here's a preliminary solution that disregards specifics of languages that
    // have more than one plural form TODO: check whether the preliminary solution works
    // at least somewhat in the po files, esp for Polish
    if (numberOfMessages == 1) {
        notifTitle = C::gettext("New message");
        notifBody = QString(C::gettext("%1 new message")).arg(numberOfMessages);
    } else {
        notifTitle = C::gettext("New messages");
        notifBody = QString(C::gettext("%1 new messages")).arg(numberOfMessages);
    }

    QString tagString;
    tagString.setNum(accID);

    tagString.append("_summary_");

    QString tempNumQStr;
    tempNumQStr.setNum(numberOfMessages);

    tagString.append(tempNumQStr);

    sendNotification(notifTitle, notifBody, tagString, icon);
}


void NotificationsLomiriPostal::createDetailedNotification(uint32_t accID, int chatID, int msgID)
{
    dc_context_t* tempCon = dc_accounts_get_account(m_accountsManager, accID);

    if (!tempCon) {
        qWarning() << "NotificationsLomiriPostal::createDetailedNotification(): ERROR: tempCon is NULL";
        return;
    }

    dc_chat_t* tempChat = dc_get_chat(tempCon, chatID);

    if (!tempChat) {
        qDebug() << "NotificationsLomiriPostal::createDetailedNotification(): ERROR: tempChat is NULL";
        dc_context_unref(tempCon);
        return;
    }

    QString accNumberString;
    accNumberString.setNum(accID);

    QString chatNumberString;
    chatNumberString.setNum(chatID);

    QString msgNumberString;
    msgNumberString.setNum(msgID);

    dc_msg_t* tempMsg = dc_get_msg(tempCon, msgID);
    if (!tempMsg) {
        qWarning() << "NotificationsLomiriPostal::createDetailedNotification(): ERROR: tempMsg is NULL";
        dc_chat_unref(tempChat);
        dc_context_unref(tempCon);
        return;
    }

    dc_lot_t* tempLot = dc_msg_get_summary(tempMsg, tempChat);
    if (!tempLot) {
        qWarning() << "NotificationsLomiriPostal::createDetailedNotification(): ERROR: tempLot is NULL";
        dc_chat_unref(tempChat);
        dc_context_unref(tempCon);
        dc_msg_unref(tempMsg);
        return;
    }


    QString fromString;
    char* tempText = dc_msg_get_override_sender_name(tempMsg);
    if (!tempText) {
        tempText = dc_contact_get_display_name(dc_get_contact(tempCon, dc_msg_get_from_id(tempMsg)));
        fromString = tempText;
        dc_str_unref(tempText);
        tempText = nullptr;
    } else {
        fromString = "~";
        fromString += tempText;
        dc_str_unref(tempText);
        tempText = nullptr;
    }

    QString messageExcerpt("?");
    tempText = dc_lot_get_text2(tempLot);
    if (tempText) {
        messageExcerpt = tempText;
        dc_str_unref(tempText);
        tempText = nullptr;
    }

    QString icon("");

    tempText = dc_chat_get_profile_image(tempChat);
    if (tempText) {
        icon = tempText;
        dc_str_unref(tempText);
        tempText = nullptr;
    }

    sendNotification(fromString, messageExcerpt, accNumberString + "_" + chatNumberString + "_" + msgNumberString, icon);

    dc_msg_unref(tempMsg);
    dc_chat_unref(tempChat);
    dc_context_unref(tempCon);
    dc_lot_unref(tempLot);
}


void NotificationsLomiriPostal::sendNotification(QString summary, QString body, QString tag, QString icon)
{
    qDebug() << "NotificationsLomiriPostal::sendNotification(): creating notification with tag " << tag;

    QDBusMessage message;
    message = QDBusMessage::createMethodCall("com.lomiri.Postal", "/com/lomiri/Postal/deltatouch_2elotharketterer", "com.lomiri.Postal", "Post");
    QString appid("deltatouch.lotharketterer_deltatouch");

    // A working Lomiri Postal notification JSON:
    // {   
    //     "message": "foobar",
    //     "notification": {
    //         "tag": tag,
    //         "card": {
    //             "summary": summary,
    //             "body": body,
    //             "popup": true,
    //             "persist": true,
    //             "icon": icon
    //         },
    //         "sound": true,
    //         "vibrate": {
    //             "pattern": [200],
    //             "duration": 200,
    //             "repeat": 1
    //         }
    //     }
    // }

    QJsonObject _card;
    _card.insert("summary", QJsonValue(summary));
    _card.insert("body", QJsonValue(body));
    _card.insert("popup", QJsonValue(true));
    _card.insert("persist", QJsonValue(true));
    _card.insert("icon", QJsonValue(icon));

    QJsonArray _pattern;
    _pattern.append(QJsonValue(200));

    QJsonObject _vibrate;
    _vibrate.insert("pattern", _pattern);
    _vibrate.insert("duration", QJsonValue(200));
    _vibrate.insert("repeat", QJsonValue(1));

    QJsonObject _notification;
    _notification.insert("tag", QJsonValue(tag));
    _notification.insert("card", _card);
    _notification.insert("sound", QJsonValue(true));
    _notification.insert("vibrate", _vibrate);

    QJsonObject _fullPostalNotif;
    _fullPostalNotif.insert("message", QJsonValue("foobar"));
    _fullPostalNotif.insert("notification", _notification);

    QJsonDocument notifJsonDoc(_fullPostalNotif);

    message << appid << QString(notifJsonDoc.toJson(QJsonDocument::Compact));
    bool success = m_bus->send(message);
    if (!success) {
        qDebug() << "NotificationsLomiriPostal::sendNotification(): ERROR: Queueing notification with tag " << tag << " was not successful";
    }
//    QDBusPendingCall pcall = m_bus->asyncCall(message);
//    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);
//    connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this, SLOT(setCounterFinished(QDBusPendingCallWatcher*)));
}


void NotificationsLomiriPostal::removeNotification(QString tag)
{
    qDebug() << "NotificationsLomiriPostal::removeNotification(): removing tag " << tag;

    QDBusMessage message;
    message = QDBusMessage::createMethodCall("com.lomiri.Postal", "/com/lomiri/Postal/deltatouch_2elotharketterer", "com.lomiri.Postal", "ClearPersistent");
    QString appid("deltatouch.lotharketterer_deltatouch");
    message << appid << tag;
    m_bus->send(message);
//    QDBusPendingCall pcall = m_bus->asyncCall(message);
//    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);
//    connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this, SLOT(setCounterFinished(QDBusPendingCallWatcher*)));
}


void NotificationsLomiriPostal::removeSummaryNotification(uint32_t accID)
{
    // Removes summary notifications for the given account ID.
    // This is triggered when the user switches to the account
    // with this ID.
    //
    // If accID == 0, the summary notification generated
    // in case of m_detailedPushNotifications == false
    // will be removed. This is triggered when the account
    // switcher is opened.
    //
    // See also the comments in processIncomingMsgBunch().
    m_accIDsToRemoveSummaryNotifs.push_back(accID);

    if (m_dbusRemoveSummaryNotifsPending) {
        return;
    }

    m_dbusRemoveSummaryNotifsPending = true;

    QDBusMessage message;
    message = QDBusMessage::createMethodCall("com.lomiri.Postal", "/com/lomiri/Postal/deltatouch_2elotharketterer", "com.lomiri.Postal", "ListPersistent");
    QString appid("deltatouch.lotharketterer_deltatouch");
    message << appid;

    QDBusPendingCall pcall = m_bus->asyncCall(message);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);
    connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this, SLOT(finishRemoveSummaryNotification(QDBusPendingCallWatcher*)));
    // the actual removal is done by finishRemoveSummaryNotification()
}


void NotificationsLomiriPostal::finishRemoveSummaryNotification(QDBusPendingCallWatcher* call)
{
    m_dbusRemoveSummaryNotifsPending = false;

    // Make sure the type of QDBusPendingReply matches the signature of the
    // expected DBus response. In this case, the signature is "as" (== array
    // of strings, i.e. QStringList)
    QDBusPendingReply<QStringList> reply = *call;
    QStringList taglist;

    if (reply.isError()) {
        QDBusError myerror = reply.error();
        qDebug() << "NotificationsLomiriPostal::finishRemoveSummaryNotification(): DBus error " << myerror.name() << ", message is: " << myerror.message();
        qDebug() << "NotificationsLomiriPostal::finishRemoveSummaryNotification(): Summary notification cannot be removed";
        // taglist will remain empty
    } else { // no error, got valid DBus reply
        // the tags of the currently active notifications
        taglist = reply.argumentAt<0>();
    }

    call->deleteLater();

    for (size_t i = 0; i < m_accIDsToRemoveSummaryNotifs.size(); ++i) {
        uint32_t accID = m_accIDsToRemoveSummaryNotifs[i];

        for (int n = 0; n < taglist.size(); ++n) {
            QString tempTag = taglist[n];
            QStringList templist = tempTag.split('_');

            QString accNumberString;
            accNumberString.setNum(accID);

            // if details should not be shown in notifications,
            // there are no separate counts per account, so
            // never skip any present notification if !m_detailedPushNotifications
            if (templist.at(0) == accNumberString && templist.at(1) == "summary") {
                removeNotification(taglist[n]);
            } 
        }
    }

    m_accIDsToRemoveSummaryNotifs.resize(0);
}


void NotificationsLomiriPostal::removeActiveNotificationsOfChat(uint32_t accID, int chatID)
{
    // fill m_notificationTagsToDelete with the current accID and chatID
    QString accNumberString;
    accNumberString.setNum(accID);

    QString chatNumberString;
    chatNumberString.setNum(chatID);

    m_notificationTagsToDelete.push_back(QString(accNumberString + "_" + chatNumberString + "_"));

    if (m_notifTagsToDeletePendingReply) {
        // the DBus method ListPersistent has already
        // been called, we're waiting for the response
        return;
    }

    // Query com.lomiri.Postal for the tags of the currently active notifications
    QDBusMessage message;
    message = QDBusMessage::createMethodCall("com.lomiri.Postal", "/com/lomiri/Postal/deltatouch_2elotharketterer", "com.lomiri.Postal", "ListPersistent");
    QString appid("deltatouch.lotharketterer_deltatouch");
    message << appid;

    QDBusPendingCall pcall = m_bus->asyncCall(message);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);
    // Actual removal will be done in the slot which receives the response to our call to Postal.
    connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this, SLOT(finishRemoveActiveNotificationsOfChat(QDBusPendingCallWatcher*)));
}


void NotificationsLomiriPostal::finishRemoveActiveNotificationsOfChat(QDBusPendingCallWatcher* call)
{
    // This method will remove active notifications if the corresponding
    // message has been marked read on another device, in which case
    // the event DC_EVENT_MSGS_NOTICED is received.
    m_notifTagsToDeletePendingReply = false;
    
    // Make sure the type of QDBusPendingReply matches the signature of the
    // expected DBus response. In this case, the signature is "as" (== array
    // of strings, i.e. QStringList)
    QDBusPendingReply<QStringList> reply = *call;

    if (reply.isError()) {
        QDBusError myerror = reply.error();
        qDebug() << "NotificationsLomiriPostal::finishRemoveActiveNotificationsOfChat(): DBus error " << myerror.name() << ", message is: " << myerror.message();
        // erase the vector to avoid it growing forever in case of constant DBus errors
        m_notificationTagsToDelete.resize(0);

    } else { // no error, got valid DBus reply
        for (size_t j = 0; j < m_notificationTagsToDelete.size(); ++j) {
            // the tags of the currently active notifications
            QStringList taglist = reply.argumentAt<0>();

            // Get the context of the account for which the DC_EVENT_MSGS_NOTICED event
            // was received. Its ID is the first part of m_notificationTagsToDelete[j].
            dc_context_t* tempCon {nullptr};

            if (taglist.size() > 0) {
                QString accIDString = m_notificationTagsToDelete[j];
                // Removing everything starting from the first '_' gets accID as string
                int indexFirstUnderscore = accIDString.indexOf('_');
                accIDString.remove(indexFirstUnderscore, accIDString.size() - indexFirstUnderscore);
                uint32_t tempAccID = accIDString.toUInt();
                tempCon = dc_accounts_get_account(m_accountsManager, tempAccID);
            }

            for (int i = 0; i < taglist.size(); ++i) {
                if (taglist.at(i).startsWith(m_notificationTagsToDelete[j])) {
                    // Notification with the current tag belongs to the context and
                    // chat in question. Now check if the corresponding message has
                    // actually been read, and only remove its notification if yes.
                    // To check this, we need the message ID in addition to the context.

                    // Get the message ID of the current tag
                    // Tags are <accID>_<chatID_<msgID>
                    QStringList templist = taglist.at(i).split('_');
                    uint32_t tempMsgID = templist.at(2).toUInt();

                    dc_msg_t* tempMsg = dc_get_msg(tempCon, tempMsgID);

                    // check if the message has been marked seen and remove, if yes
                    if (dc_msg_get_state(tempMsg) == DC_STATE_IN_SEEN) {
                        removeNotification(taglist.at(i));
                    } 

                    if (tempMsg) {
                        dc_msg_unref(tempMsg);
                    }
                }
            } // for

            if (tempCon) {
                dc_context_unref(tempCon);
            }
        }

        // don't forget to empty the cache
        m_notificationTagsToDelete.resize(0);

    } // else // no error
    call->deleteLater();
}
