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

#include "notificationsFreedesktop.h"

namespace C {
#include <libintl.h>
}


NotificationsFreedesktop::NotificationsFreedesktop(DeltaHandler* dhandler, dc_accounts_t* accounts, EmitterThread* emthread, AccountsModel* accmodel, QDBusConnection* bus)
    : NotificationHelper(dhandler, accounts, emthread, accmodel), m_bus {bus}
{
    bool connectSuccess = connect(m_emitterthread, SIGNAL(newMsg(uint32_t, int, int)), this, SLOT(processIncomingMessage(uint32_t, int, int)));
    if (!connectSuccess) {
        qFatal("NotificationsFreedesktop::NotificationsFreedesktop(): Could not connect signal newMsg to slot incomingMessage");
    }

    connectSuccess = connect(m_emitterthread, SIGNAL(incomingMsgBunch(uint32_t)), this, SLOT(processIncomingMsgBunch(uint32_t)));
    if (!connectSuccess) {
        qFatal("NotificationsFreedesktop::NotificationsFreedesktop(): Could not connect signal incomingMsgBunch to slot processIncomingMsgBunch");
    }

    // connect to the NotificationClosed signal of the freedesktop Notification service
    m_bus->connect("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "NotificationClosed", this, SLOT(processNotificationClosedDbusSignal(unsigned int, unsigned int)));

    // In theory, a check for capability "persistence" in org.freedesktop.Notifications.GetCapabilities
    // could be performed. The whole system to remove ("close") notifications would then only
    // be active if this capability exists. However, phosh on at least droidian does
    // not list this capability, but still maintains a list of notifications that
    // can be closed => don't check for this capability, always try to close notifications
}


NotificationsFreedesktop::~NotificationsFreedesktop()
{
    disconnect(m_emitterthread, SIGNAL(newMsg(uint32_t, int, int)), this, SLOT(incomingMessage(uint32_t, int, int)));
    disconnect(m_emitterthread, SIGNAL(incomingMsgBunch(uint32_t)), this, SLOT(processIncomingMsgBunch(uint32_t)));
    m_bus->disconnect("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "NotificationClosed", this, SLOT(processNotificationClosedDbusSignal(unsigned int, unsigned int)));
}


void NotificationsFreedesktop::processIncomingMessage(uint32_t accID, int chatID, int msgID)
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


void NotificationsFreedesktop::processIncomingMsgBunch(uint32_t accID)
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
        return;
    }

    // Aim is to not have more than 9 detailed notifications per
    // IMAP fetch. If there are more, one single summary notification
    // is generated instead.
    // In contrast to the NotificationsLomiriPostal class, previous
    // notifications are not replaced and not considered in 
    // the generation of summary notifications.
    // With the Freedesktop notification service, notifications
    // may not be persistent, and even if they are, the server cannot
    // be queried for non-closed notifications.
    // It could still be implemented, as this class already keeps
    // track of generated notifications and listens to the 
    // NotificationClosed DBus signal. However, this cannot span across
    // several runs of the app. Even if the current method of
    // tracking (via runtime variable, restricted to 299 entries) 
    // would be replaced by a database, the app has no way of knowing
    // which notifications have been closed by the user while the app
    // was not running.
    //
    // It even may not be desired to copy the behaviour of
    // NotificationsLomiriPostal, because the main reason for the
    // auto-aggregation on Ubuntu Touch is that it is inconvenient
    // to handle a large number of notifications on this platform.
    // This is not necessarily true by other implementations.

    // no chat opened if this call returns -1
    int currentChatID = m_deltaHandler->getCurrentChatId();

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

        // In contrast to the similar method in NotificationsLomiriPostal,
        // we can return here as we are dealing with only one accID.
        return;
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
        return;
    }

    // For the GUI to adapt the counter for new messages in
    // other / incative accounts
    if (accID != m_currentAccID) {
        emit newMessageForInactiveAccount();
    }

    // TODO: maybe via the
    // Check how many notifications are already present
    // in the system for this account

    // Trigger the notification depending on settings
    // and the number of notifications to be generated
    if (m_detailedPushNotifications) {
        if ((messagesToNotify.size()) > 9) {
            // don't send out a notification for each message if there 
            // are more than 9 messages to notify
            createSummaryNotification(accID, messagesToNotify.size(), true);
        } else {
            for (size_t l = 0; l < messagesToNotify.size(); ++l) {
                IncomingMsgStruct tempStruct = messagesToNotify[l];
                createDetailedNotification(tempStruct.accID, tempStruct.chatID, tempStruct.msgID);
            }
        }
    } else { // if (m_detailedPushNotifications)
        createSummaryNotification(0, messagesToNotify.size(), false);
    }
}


void NotificationsFreedesktop::createSummaryNotification(uint32_t accID, int numberOfMessages, bool showSelfAvatar)
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
        icon = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg";
        if (!QFile::exists(icon)) {
            QFile logoFile(":assets/logo.svg");
            logoFile.copy(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg");
        }
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


void NotificationsFreedesktop::createDetailedNotification(uint32_t accID, int chatID, int msgID)
{
    dc_context_t* tempCon = dc_accounts_get_account(m_accountsManager, accID);

    if (!tempCon) {
        qWarning() << "NotificationsFreedesktop::createDetailedNotification(): ERROR: tempCon is NULL";
        return;
    }

    dc_chat_t* tempChat = dc_get_chat(tempCon, chatID);

    if (!tempChat) {
        qDebug() << "NotificationsFreedesktop::createDetailedNotification(): ERROR: tempChat is NULL";
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
        qWarning() << "NotificationsFreedesktop::createDetailedNotification(): ERROR: tempMsg is NULL";
        dc_chat_unref(tempChat);
        dc_context_unref(tempCon);
        return;
    }

    dc_lot_t* tempLot = dc_msg_get_summary(tempMsg, tempChat);
    if (!tempLot) {
        qWarning() << "NotificationsFreedesktop::createDetailedNotification(): ERROR: tempLot is NULL";
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

    if (icon == "") {
        icon = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg";
        if (!QFile::exists(icon)) {
            QFile logoFile(":assets/logo.svg");
            logoFile.copy(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg");
        }
    }

    sendNotification(fromString, messageExcerpt, accNumberString + "_" + chatNumberString + "_" + msgNumberString, icon);

    dc_msg_unref(tempMsg);
    dc_chat_unref(tempChat);
    dc_context_unref(tempCon);
    dc_lot_unref(tempLot);
}


void NotificationsFreedesktop::sendNotification(QString summary, QString body, QString tag, QString icon)
{
    qDebug() << "NotificationsFreedesktop::sendNotification(): Creating notification with tag " << tag;

    // The Notify method expects susssasa{sv}i as argument
    QDBusMessage message = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "Notify");

    QString app_name("DeltaTouch");
    unsigned int replaces_id {0};
    // The "actions" parameter is "as" = array of strings = QStringList,
    // leave it empty
    QStringList actions;
    QMap<QString, QVariant> hints;
    int expire_timeout {3000};

    message << app_name << replaces_id << icon << summary << body << actions << hints << expire_timeout;

    QDBusPendingCall pcall = m_bus->asyncCall(message);
    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);
    connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this, SLOT(getDbusResponseForNotifyCall(QDBusPendingCallWatcher*)));

    // The Notify DBus call will return the ID of the notification. A
    // blocking call is not an option, so we have to store the tag
    // to correlate it with the notification ID later on in
    // getDbusResponseForNotifyCall. Several calls to sendNotification
    // might occur before the DBus reply for the first call arrives, thus
    // multiple tags exist that have to be correlated to IDs. A QMap
    // with the call watcher as key and the tag as value is used to keep
    // track.
    m_callTagCorrelation.insert(watcher, tag);
}


void NotificationsFreedesktop::getDbusResponseForNotifyCall(QDBusPendingCallWatcher* watcher)
{
    // QDBusPendingReply has to match the signature of the
    // expected DBus response. In this case, the signature is "u" == uint32_t
    QDBusPendingReply<uint32_t> reply = *watcher;
    uint32_t notificationId;

    if (reply.isError()) {
        QDBusError myerror = reply.error();
        qDebug() << "NotificationsFreedesktop::getDbusResponseForNotifyCall(): ERROR: Could not create notification due to DBus error " << myerror.name() << ", message is: " << myerror.message();
        // still remove the entry in m_callTagCorrelation
        m_callTagCorrelation.remove(watcher);

    } else { // no error, got valid DBus reply
        // the ID of the notification
        notificationId = reply.argumentAt<0>();

        // correlate this ID to the tag, for that get
        // the tag corresponding to this watcher
        QString tag = m_callTagCorrelation.take(watcher);

        // If not found, QMap::take will return a default generated QString(). In
        // this case, don't enter anything in m_tagNotificationIdCorrelation.
        // This means that the notification cannot be closed by the app.
        //
        // Also, check for the size of m_tagNotificationIdCorrelation and
        // don't let this QMap grow larger than 299 entries.
        if (tag != "" && m_tagNotificationIdCorrelation.size() < 300) {
            // For summary notifications, the tag might already exist.
            // Just inserting it again would overwrite the previous value, so
            // first take (= get and remove) the value, append the ID (the take
            // method will return an empty vector, if the key (tag) doesn't
            // exist yet, so this is safe.
            std::vector<unsigned int> listOfIds = m_tagNotificationIdCorrelation.take(tag);
            listOfIds.push_back(notificationId);
            m_tagNotificationIdCorrelation.insert(tag, listOfIds);
        } else if (tag != "") {
            qWarning() << "NotificationsFreedesktop::getDbusResponseForNotifyCall(): Warning: Size of m_tagNotificationIdCorrelation is >= 300, not adding any more tag/ID pairs.";
        } else {
            // did not find the tag for this call watcher
            qDebug() << "NotificationsFreedesktop::getDbusResponseForNotifyCall(): ERROR: Call watcher not found in cache, could not attribute notification ID to tag";
        }
    }

    watcher->deleteLater();
}


void NotificationsFreedesktop::processNotificationClosedDbusSignal(unsigned int id, unsigned int reason)
{
    // This slot is connected to the NotificationClosed DBus signal of the Freedesktop
    // Notification service. It removes the id of the notification from
    // m_tagNotificationIdCorrelation, if present.

    // Cycle through the vector and check whether the ID is in the 
    // value of the QMap entry.
    QMap<QString, std::vector<unsigned int>>::Iterator it = m_tagNotificationIdCorrelation.begin();
    bool found {false};

    while (it != m_tagNotificationIdCorrelation.end() && !found) {
        std::vector<unsigned int> tempVec = it.value();
        
        for (size_t j = 0; j < tempVec.size(); ++j) {
            if (tempVec[j] == id) {
                found = true;

                // If the vector has more than 1 entry, update the vector,
                // remove the QMap entry and create it new with
                // the updated vector. If not, just remove the QMap entry.
                if (tempVec.size() > 1) {
                    tempVec.erase(tempVec.begin() + j);
                    QString tempKey = it.key();
                    m_tagNotificationIdCorrelation.erase(it);
                    m_tagNotificationIdCorrelation.insert(tempKey, tempVec);
                } else {
                    m_tagNotificationIdCorrelation.erase(it);
                }
                break;
            }
        } // for

        if (!found) {
            ++it;
        }
    } // while
}


void NotificationsFreedesktop::removeNotification(QString tag)
{
    std::vector<unsigned int> tempVec = m_tagNotificationIdCorrelation.take(tag);

    // if the tag was not found in m_tagNotificationIdCorrelation, tempVec
    // is automatically 0.
    for (size_t i = 0; i < tempVec.size(); ++i) {
        QDBusMessage message = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "CloseNotification");
        message << tempVec[i];
        m_bus->send(message);
    }
}


void NotificationsFreedesktop::removeSummaryNotification(uint32_t accID)
{
    QString startOfTag;
    startOfTag.setNum(accID);
    startOfTag.append("_summary");


    QMap<QString, std::vector<unsigned int>>::Iterator it = m_tagNotificationIdCorrelation.begin();
    QList<unsigned int> idsToClose;

    // Find the notification IDs that belong to a summary
    // notification for this account and append them to
    // idsToClose
    while (it != m_tagNotificationIdCorrelation.end()) {
        if (it.key().startsWith(startOfTag)) {
            std::vector<unsigned int> tempVec = it.value();
            for (size_t i = 0; i < tempVec.size(); ++i) {
                idsToClose.append(tempVec[i]);
            }
        }
        ++it;
    } // while

    // Close the IDs
    for (int i = 0; i < idsToClose.size(); ++i) {
        QDBusMessage message = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "CloseNotification");
        message << idsToClose[i];
        m_bus->send(message);
    }
}


void NotificationsFreedesktop::removeActiveNotificationsOfChat(uint32_t accID, int chatID)
{
    // Go through m_tagNotificationIdCorrelation and search for
    // all tags starting with accID_chatID
    QString startOfTag;
    startOfTag.setNum(accID);
    startOfTag.append("_");
    QString tempStr;
    tempStr.setNum(chatID);
    startOfTag.append(tempStr);

    QMap<QString, std::vector<unsigned int>>::Iterator it = m_tagNotificationIdCorrelation.begin();

    QStringList tagList;

    while (it != m_tagNotificationIdCorrelation.end()) {
        if (it.key().startsWith(startOfTag)) {
            tagList.append(it.key());
        }
        ++it;
    }

    for (int i = 0; i < tagList.size(); ++i) {
        removeNotification(tagList[i]);
    }
}
