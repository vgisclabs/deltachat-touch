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

#include <fstream>
#include "deltahandler.h"
//#include <unistd.h> // for sleep
#include <QtDBus/QDBusMessage>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QDBusError>

#include "notificationsLomiriPostal.h"
#include "notificationsFreedesktop.h"
#include "notificationsMissing.h"

namespace C {
#include <libintl.h>
}


DeltaHandler::DeltaHandler(QObject* parent)
    : QAbstractListModel(parent), tempContext {nullptr}, m_blockedcontactsmodel {nullptr}, m_groupmembermodel {nullptr}, m_workflowDbEncryption {nullptr}, m_workflowDbDecryption {nullptr}, m_currentAccID {0}, currentChatID {0}, m_hasConfiguredAccount {false}, m_networkingIsAllowed {true}, m_networkingIsStarted {false}, m_showArchivedChats {false}, m_tempGroupChatID {0}, m_query {""}, m_bus("DeltaTouch"), m_qr {nullptr}, m_audioRecorder {nullptr}, m_backupProvider {nullptr}, m_coreTranslationsAlreadySet {false}, m_signalQueue_refreshChatlist {false}
{
    // Determine if the app is running on Ubuntu Touch,
    // if it is in desktop mode and if the on-screen
    // keyboard shall be summoned via
    // dbus session bus call sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
    m_onUbuntuTouch = false;
    m_isDesktopMode = false;
    m_openOskViaDbus = false;


    QProcessEnvironment procenv = QProcessEnvironment::systemEnvironment();
    QStringList sysvarlist = procenv.keys();
    for (int i = 0; i < sysvarlist.size(); ++i) {
        if (sysvarlist.at(i) == "QT_FILE_SELECTORS") {
            if (procenv.value("QT_FILE_SELECTORS") == "ubuntu-touch") {
                m_onUbuntuTouch = true;
            }
        }

        // 'clickable desktop' sets the env var CLICKABLE_DESKTOP_MODE.
        // In this case, QT_FILE_SELECTORS is not set to "ubuntu-touch"
        // , but m_onUbuntuTouch should still be true as desktop mode
        // is to test code that will run on Ubuntu Touch.
        if (sysvarlist.at(i) == "CLICKABLE_DESKTOP_MODE") {
            m_onUbuntuTouch = true;
            m_isDesktopMode = true;
        }

        if (sysvarlist.at(i) == "OPEN_OSK_VIA_DBUS") {
            qDebug() << "DeltaHandler::DeltaHandler(): Found env var OPEN_OSK_VIA_DBUS, setting m_openOskViaDbus to true";
            m_openOskViaDbus = true;
        }
    }

    if (m_onUbuntuTouch && !m_isDesktopMode) {
        qDebug() << "DeltaHandler::DeltaHandler(): Running on Ubuntu Touch " << QSysInfo::productVersion();
    } else if (m_isDesktopMode) {
        qDebug() << "DeltaHandler::DeltaHandler(): Running in clickable desktop mode";
    } else {
        qDebug() << "DeltaHandler::DeltaHandler(): Not running on Ubuntu Touch";
    }

    // Set the initial id for jsonrpc requests to 1 billion, i.e. around half of the
    // max of an unsigned int (although the id in libdeltachat might
    // be unsigned). Reason is that jsonrpc.mjs as used in QML has its own
    // ids that start with 0.
    // TODO modify jsonrpc.mjs so that the next id after 999 999 999 is
    // 0 again to avoid collisions. (not done yet because that might
    // give license problems, see https://www.mozilla.org/en-US/MPL/2.0/combining-mpl-and-gpl/)
    m_jsonrpcRequestId = 1000000000;
    {
        // to be able to access the files under assets
        Q_INIT_RESOURCE(assets);

        // make the logo accessible in the cache (needed for
        // notifications)
        QFile logoFile(":assets/logo.svg");
        logoFile.copy(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg");

        // prepare directory for the user to put keys to import into
        // This is connected to the menu items under Advanced => Manage Keys
        // and has nothing to do with database encryption
        QString keysToImportDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
        keysToImportDir.append("/keys_to_import");

        if (!QFile::exists(keysToImportDir)) {
            QDir keysdir;
            bool mkdirsuccess = keysdir.mkpath(keysToImportDir);
            if (!mkdirsuccess) {
                qFatal("DeltaHandler::DeltaHandler(): Error: Could not create directory ~/.cache/deltatouch.lotharketterer/keys_to_import");
            }
        }
    }
    // Must use QStandardPaths::AppConfigLocation to get the config dir. With
    // QStandardPaths::ConfigLocation, we just get /home/phablet/.config
    QString configdir(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation));
    qDebug() << "DeltaHandler::DeltaHandler(): Config directory set to: " << configdir;

    if (!QFile::exists(configdir)) {
        qDebug() << "DeltaHandler::DeltaHandler(): Config directory not existing, creating it now";
        QDir tempdir;
        bool success = tempdir.mkpath(configdir);
        if (success) {
            qDebug() << "DeltaHandler::DeltaHandler(): Config directory successfully created";
        }
        else {
            qFatal("DeltaHandler::DeltaHandler(): Could not create config directory, exiting");
        }
    }

    // create the cache dir if it doesn't exist yet (it shouldn't exist,
    // as it is deleted on shutdown)
    QString cachedir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));

    if (!QFile::exists(cachedir)) {
        QDir tempdir;
        bool success = tempdir.mkpath(cachedir);
        if (!success) {
            qFatal("DeltaHandler::DeltaHandler(): Could not create Cache directory, exiting");
        }
        else {
        }
    }

    settings = new QSettings("deltatouch.lotharketterer", "deltatouch.lotharketterer");

    // check whether (according to the settings) the database
    // is encrypted
    if (settings->contains("encryptDb")) {
        m_encryptedDatabase = settings->value("encryptDb").toBool();
    } else {
        m_encryptedDatabase = false;
    }

    if (m_encryptedDatabase) {
        qDebug() << "DeltaHandler::DeltaHandler(): Setting \"encrypted database\" is on";
    } else {
        qDebug() << "DeltaHandler::DeltaHandler(): Setting \"encrypted database\" is off";
    }

    m_chatmodel = new ChatModel();
    // TODO: should be something like chatIsCurrentlyViewed or
    // similar because the only time the variable is used is
    // when a new message arrives. Actions to do upon arrival of
    // a new message depends on whether the corresponding chat is
    // currently shown to the user.
    // Also, the page that shows the chat needs to set it to false
    // when the page is destroyed.
    currentChatIsOpened = false;

    m_accountsmodel = new AccountsModel();

    m_contactsmodel = new ContactsModel();

    m_signalQueueTimer = new QTimer(this);

    bool connectSuccess = connect(m_signalQueueTimer, SIGNAL(timeout()), this, SLOT(processSignalQueueTimerTimeout()));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal timeout to slot processSignalQueueTimerTimeout");
    }

    configdir.append("/accounts/");  
    // Qt documentation for QString:
    // [...] you can pass a QString to a function that takes a const char *
    // argument using the qPrintable() macro which returns the given QString
    // as a const char *. This is equivalent to calling
    // <QString>.toLocal8Bit().constData().
    //
    // Also possible: <QString>.toUtf8().constData() ==>> preferred!
    //
    // Also possible: <QString>.toStdString().c_str()
    allAccounts = dc_accounts_new(qPrintable(configdir), 1);

    if (!allAccounts) {
        qFatal("DeltaHandler::DeltaHandler: Fatal error trying to create account manager.");
    }

    // will be started later
    eventThread = new EmitterThread(allAccounts);

    m_bus = QDBusConnection::connectToBus(QDBusConnection::SessionBus, "DeltaTouch");

    bool tempHasLomiriPostal {false};
    bool tempHasFreedesktopNotifications {false};

    // Don't use ListNames as org.freedesktop.Notifications is not
    // always showing up in the response from ListNames,
//    QDBusMessage message = QDBusMessage::createMethodCall("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListNames");
//    QDBusPendingReply<QStringList> reply = m_bus.call(message);
//
//    if (reply.isError()) {
//        QDBusError myerror = reply.error();
//        qDebug() << "DeltaHandler::DeltaHandler(): DBus error " << myerror.name() << ", message is: " << myerror.message();
//    } else {
//        QStringList dbusServiceList = reply.argumentAt<0>();
//
//        for (int i = 0; i < dbusServiceList.size(); ++i) {
//            if (dbusServiceList[i] == "com.lomiri.Postal") {
//                tempHasLomiriPostal = true;
//            } else if (dbusServiceList[i] == "org.freedesktop.Notifications") {
//                tempHasFreedesktopNotifications = true;
//            }
//        }
//    }
    
    // Try to call methods of the services directly and check
    // if a reply is received
    //
    // Check org.freedesktop.Notifications
    QDBusMessage message = QDBusMessage::createMethodCall("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "GetCapabilities");
    QDBusReply<QStringList> reply = m_bus.call(message);

    if (reply.isValid()) {
        qDebug() << "DeltaHandler::DeltaHandler(): Received valid DBus reply from org.freedesktop.Notifications";
        tempHasFreedesktopNotifications = true;
    } else {
        QDBusError myerror = reply.error();
        qDebug() << "DeltaHandler::DeltaHandler(): DBus error when contacting org.freedesktop.Notifications: " << myerror.name() << ", message is: " << myerror.message();
    }

    // Check com.lomiri.Postal
    message = QDBusMessage::createMethodCall("com.lomiri.Postal", "/com/lomiri/Postal/deltatouch_2elotharketterer", "com.lomiri.Postal", "ListPersistent");
    QString appid("deltatouch.lotharketterer_deltatouch");
    message << appid;
    reply = m_bus.call(message);

    if (reply.isValid()) {
        qDebug() << "DeltaHandler::DeltaHandler(): Received valid DBus reply from com.lomiri.Postal";
        tempHasLomiriPostal = true;
    } else {
        QDBusError myerror = reply.error();
        qDebug() << "DeltaHandler::DeltaHandler(): DBus error when contacting com.lomiri.Postal: " << myerror.name() << ", message is: " << myerror.message();
    }

    // Prefer com.lomiri.Postal (on Ubuntu Touch, the freedesktop notification service
    // is present as well, but not really functional)
    if (tempHasLomiriPostal) {
        m_notificationHelper = new NotificationsLomiriPostal(this, allAccounts, eventThread, m_accountsmodel, &m_bus);
        qDebug() << "DeltaHandler::DeltaHandler(): Using com.lomiri.Postal DBus service for notifications";
    } else if (tempHasFreedesktopNotifications) {
        m_notificationHelper = new NotificationsFreedesktop(this, allAccounts, eventThread, m_accountsmodel, &m_bus);
        qDebug() << "DeltaHandler::DeltaHandler(): Using org.freedesktop.Notifications DBus service for notifications";
    } else {
        m_notificationHelper = new NotificationsMissing(this, allAccounts, eventThread, m_accountsmodel);
        qDebug() << "DeltaHandler::DeltaHandler(): Cannot use DBus for notifications, notifications are not available";
    }

    m_jsonrpcInstance = dc_jsonrpc_init(allAccounts);

    m_jsonrpcResponseThread = new JsonrpcResponseThread(m_jsonrpcInstance);
    m_jsonrpcResponseThread->start();


    connectSuccess = connect(eventThread, SIGNAL(newMsg(uint32_t, int, int)), this, SLOT(incomingMessage(uint32_t, int, int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal newMsg to slot incomingMessage");
    }

    connectSuccess = connect(eventThread, SIGNAL(msgsChanged(uint32_t, int, int)), this, SLOT(messagesChanged(uint32_t, int, int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal msgsChanged to slot messagesChanged");
    }

    connectSuccess = connect(eventThread, SIGNAL(msgsNoticed(uint32_t, int)), this, SLOT(messagesNoticed(uint32_t, int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal msgsNoticed to slot messagesNoticed");
    }

    connectSuccess = connect(eventThread, SIGNAL(connectivityChanged(uint32_t)), this, SLOT(connectivityUpdate(uint32_t)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal connectivityChanged to slot connectivityUpdate");
    }

    connectSuccess = connect(eventThread, SIGNAL(chatDataModified(uint32_t, int)), this, SLOT(chatDataModifiedReceived(uint32_t, int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal chatDataModified to slot chatDataModifiedReceived");
    }

    connectSuccess = connect(eventThread, SIGNAL(configureProgress(int, QString)), this, SLOT(progressEvent(int, QString)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal configureProgress to slot progressEvent");
    }

    connectSuccess = connect(eventThread, SIGNAL(contactsChanged()), m_contactsmodel, SLOT(updateContacts()));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal contactsChanged to slot updateContacts");
    }

    connectSuccess = connect(eventThread, SIGNAL(msgDelivered(uint32_t, int, int)), this, SLOT(messageDeliveredToServer(uint32_t, int, int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal msgDelivered to slot messageDeliveredToServer");
    }

    connectSuccess = connect(eventThread, SIGNAL(msgRead(uint32_t, int, int)), this, SLOT(messageReadByRecipient(uint32_t, int, int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal msgRead to slot messageReadByRecipient");
    }

    connectSuccess = connect(eventThread, SIGNAL(msgFailed(uint32_t, int, int)), this, SLOT(messageFailedSlot(uint32_t, int, int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal msgFailed to slot messageFailedSlot");
    }

    connectSuccess = connect(eventThread, SIGNAL(reactionsChanged(uint32_t, int, int)), this, SLOT(msgReactionsChanged(uint32_t, int, int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal reactionsChanged to slot msgReactionsChanged");
    }

    connectSuccess = connect(m_jsonrpcResponseThread, SIGNAL(newJsonrpcResponse(QString)), this, SLOT(receiveJsonrcpResponse(QString)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal newJsonrpcResponse to slot receiveJsonrcpResponse");
    }


    connectSuccess = connect(m_contactsmodel, SIGNAL(chatCreationSuccess(uint32_t)), this, SLOT(chatCreationReceiver(uint32_t)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal chatCreationSuccess to slot chatCreationReceiver");
    }

    connectSuccess = connect(m_chatmodel, SIGNAL(markedAllMessagesSeen()), this, SLOT(resetCurrentChatMessageCount()));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal markedAllMessagesSeen to slot resetCurrentChatMessageCount");
    }

    connectSuccess = connect(this, SIGNAL(openChatViewRequest(uint32_t, uint32_t)), m_chatmodel, SLOT(chatViewIsOpened(uint32_t, uint32_t)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal openChatViewRequest to slot chatViewIsOpened");
    }

    connectSuccess = connect(this, SIGNAL(messageDelivered(int)), m_chatmodel, SLOT(messageStatusChangedSlot(int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal messageDelivered to slot messageStatusChangedSlot");
    }

    connectSuccess = connect(this, SIGNAL(messageRead(int)), m_chatmodel, SLOT(messageStatusChangedSlot(int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal messageRead to slot messageStatusChangedSlot");
    }

    connectSuccess = connect(this, SIGNAL(messageFailed(int)), m_chatmodel, SLOT(messageStatusChangedSlot(int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal messageFailed to slot messageStatusChangedSlot");
    }

    connectSuccess = connect(this, SIGNAL(messageReaction(int)), m_chatmodel, SLOT(messageStatusChangedSlot(int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal messageReaction to slot messageStatusChangedSlot");
    }

    connectSuccess = connect(m_accountsmodel, SIGNAL(deletedAccount(uint32_t)), this, SLOT(removeClosedAccountFromList(uint32_t)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal deletedAccount of m_accountsmodel to slot removeClosedAccountFromList");
    }

    connectSuccess = connect(this, SIGNAL(chatIsNotContactRequestAnymore(uint32_t, uint32_t)), m_accountsmodel, SLOT(removeChatIdFromContactRequestList(uint32_t, uint32_t)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal chatIsNotContactRequestAnymore of eventThread to slot removeChatIdFromContactRequestList of m_accountsmodel";
        // not critical, thus no exit() statement
    }

    currentContext = nullptr;

    dc_array_t* tempArray = dc_accounts_get_all(allAccounts);
    size_t noOfAccounts = dc_array_get_cnt(tempArray);
    qDebug() << "DeltaHandler::DeltaHandler: Found " << noOfAccounts << " account(s)";

    if (noOfAccounts != 0) {
        // Perform check whether a workflow to convert the database
        // from unencrypted to encrypted or vice versa did not finish,
        // and if so, check if an incomplete and thus unconfigured
        // account has to be removed.
        if (workflowToEncryptedPending() || workflowToUnencryptedPending()) {
            qDebug() << "DeltaHandler::DeltaHandler(): Workflow is pending, checking whether incomplete account has to be removed";
            // The workflows to convert accounts to encrypted or
            // unencrypted work like this:
            // - create a backup of an account
            // - add a new account (encrypted or not, depending on the
            //   workflow)
            // - import the backup into the new account
            // - delete the old account
            // - repeat if further accounts are present
            // If such a workflow is interrupted during the importing
            // phase, a new account is present that is incomplete and
            // not usable. As the old/original account is still present,
            // the new account can be deleted and the process as
            // described above can be repeated. Deletion of the new
            // (incomplete) account is done here, resuming the process
            // is done later on (controlled by Main.qml).  To determine
            // whether there's an account to be deleted, the setting
            // "workflowDbImportingInto" is checked. This setting is
            // created by the workflows prior to adding a new account in
            // the form "<new accID> importedFrom <old accID>". After
            // successful import and deletion of the old account, the
            // setting is deleted. So if such a setting is present, the
            // new accID has to be deleted.
            if (settings->contains("workflowDbImportingInto")) {
                QString tempQString = settings->value("workflowDbImportingInto").toString();
                // save the IDs of the incomplete (new) and the original (old) account
                QStringList tempStringList = tempQString.split(' ');
                if (tempStringList.size() == 3) {
                    // Will trigger a warning by the compiler due to
                    // different number formats :(
                    uint32_t newAccID = tempStringList.at(0).toInt();
                    uint32_t oldAccID = tempStringList.at(2).toInt();
                    qDebug() << "DeltaHandler::DeltaHandler(): Found incomplete account ID " << newAccID << ", based on original ID " << oldAccID;
                    // Just to make sure: Check if the old account is still present, and
                    // only remove the new one if yes.
                    bool oldOneStillExists = false;
                    for (size_t i = 0; i < dc_array_get_cnt(tempArray); ++i) {
                        if (oldAccID == dc_array_get_id(tempArray, i)) {
                            oldOneStillExists = true;
                            break;
                        }
                    }

                    if (oldOneStillExists) {
                        qDebug() << "DeltaHandler::DeltaHandler(): Removing incomplete account with ID " << newAccID;
                        dc_accounts_remove_account(allAccounts, newAccID);

                        // now tempArray needs to be reloaded, and noOfAccounts recalculated
                        dc_array_unref(tempArray);
                        tempArray = dc_accounts_get_all(allAccounts);
                        noOfAccounts = dc_array_get_cnt(tempArray);
                        qDebug() << "DeltaHandler::DeltaHandler: Now it's " << noOfAccounts << " account(s)";

                    } else {
                        qDebug() << "DeltaHandler::DeltaHandler(): Precondition to remove incomplete account not given: Original account does not exist anymore.";
                        // TODO: how to deal with this situation? communicate to the user?
                    }

                    // Whether the incomplete account could be removed or not,
                    // we're not doing anything else anyway, so remove the setting
                    // TODO: depending on the reaction to the situation when the old account
                    // does not exist anymore, something else should be done?
                    settings->remove("workflowDbImportingInto");

                } else {
                    qDebug() << "DeltaHandler::DeltaHandler(): ERROR: Wrong format of setting workflowDbImportingInto, state of accounts unclear";
                    // TODO: how to deal with this situation? communicate to the user?
                }
            } else {
                qDebug() << "DeltaHandler::DeltaHandler(): No incomplete account has to be removed";
            }
        }

        // check for open and closed accounts and put them into
        // m_closedAccounts
        for (size_t i = 0; i < noOfAccounts; ++i) {
            uint32_t tempAccID = dc_array_get_id(tempArray, i);
            tempContext = dc_accounts_get_account(allAccounts, tempAccID);
            if (0 == dc_context_is_open(tempContext)) {
                qDebug() << "DeltaHandler::DeltaHandler(): Account ID " << tempAccID << " is closed";
                m_closedAccounts.push_back(tempAccID);
            } else {
                qDebug() << "DeltaHandler::DeltaHandler(): Account ID " << tempAccID << " is open";
            }
            dc_context_unref(tempContext);
            tempContext = nullptr;
        }
    }

    dc_array_unref(tempArray);
}


DeltaHandler::~DeltaHandler()
{
    qDebug() << "entering DeltaHandler::~DeltaHandler()";

    if (currentContext) {
        dc_context_unref(currentContext);
    }

    if (tempContext) {
        dc_context_unref(tempContext);
    }

    if (allAccounts) {
        dc_accounts_unref(allAccounts);
    }

    delete eventThread;
    delete m_accountsmodel;
    delete m_chatmodel;
    delete m_contactsmodel;

    if (m_blockedcontactsmodel) {
        delete m_blockedcontactsmodel;
    }

    if (m_groupmembermodel) {
        delete m_groupmembermodel;
    }

    if (m_audioRecorder) {
        delete m_audioRecorder;
    }

    if (m_qr) {
        quirc_destroy(m_qr);
    }
}


bool DeltaHandler::isDesktopMode()
{
    return m_isDesktopMode;
}


bool DeltaHandler::onUbuntuTouch()
{
    return m_onUbuntuTouch;
}


bool DeltaHandler::shouldOpenOskViaDbus()
{
    return m_openOskViaDbus;
}


void DeltaHandler::loadSelectedAccount()
{
    qDebug() << "entering DeltaHandler::loadSelectedAccount()";

    // Enabling verified 1:1 chats for all accounts. Done here
    // as all startup routines will end up calling this function.
    enableVerifiedOneOnOneForAllAccs();

    m_accountsmodel->configure(allAccounts, this);

    // safe to call repeatedly as the documentation says:
    // "If the thread is already running, this function does nothing."
    eventThread->start();

    beginResetModel();

    m_hasConfiguredAccount = false;

    if (numberOfAccounts() > 0) {
        currentContext = dc_accounts_get_selected_account(allAccounts);
        // m_currentAccID is set in contextSetupTasks(), but this
        // may not be called if there's no configured context
        // in this dc_accounts_t
        m_currentAccID = dc_get_id(currentContext);
        m_notificationHelper->setCurrentAccId(m_currentAccID);

        if (dc_is_configured(currentContext)) {
            m_hasConfiguredAccount = true;
            contextSetupTasks();
        } else {
            qDebug() << "DeltaHandler::DeltaHandler: Selected account is not configured, searching for another account..";
            dc_array_t* tempArray = dc_accounts_get_all(allAccounts);

            for (size_t i = 0; i < dc_array_get_cnt(tempArray); ++i) {
                uint32_t tempAccID = dc_array_get_id(tempArray, i);
                tempContext = dc_accounts_get_account(allAccounts, tempAccID);
                if (dc_is_configured(tempContext)) {
                    m_hasConfiguredAccount = true;
                    // TODO: does the signal have to be emitted?
                    emit hasConfiguredAccountChanged();
                    dc_accounts_select_account(allAccounts, tempAccID);

                    dc_context_unref(currentContext);
                    currentContext = tempContext;
                    contextSetupTasks();

                    tempContext = nullptr;

                    qDebug() << "DeltaHandler::DeltaHandler: ...found one!";
                    break;
                }
                dc_context_unref(tempContext);
                tempContext = nullptr;
            } // for
            dc_array_unref(tempArray);

            if (!m_hasConfiguredAccount) {
                qDebug() << "DeltaHandler::DeltaHandler: ...did not find one.";
            }
        } // else of if(dc_is_configured(currentContext)
    }

    setCoreTranslations();

    endResetModel();
    emit accountChanged();

    qDebug() << "exiting DeltaHandler::loadSelectedAccount()";
}


uint32_t DeltaHandler::getCurrentAccountId() const
{
    return m_currentAccID;
}


int DeltaHandler::getCurrentChatId() const
{
    if (!currentChatIsOpened) {
        return -1;
    } else {
        return currentChatID;
    }
}


void DeltaHandler::sendJsonrpcRequest(QString request)
{
    dc_jsonrpc_request(m_jsonrpcInstance, request.toUtf8().constData());
}


QString DeltaHandler::sendJsonrpcBlockingCall(QString request) const
{
    char* tempText;
    QString retval;

    tempText = dc_jsonrpc_blocking_call(m_jsonrpcInstance, request.toLocal8Bit().constData());
    retval = tempText;

    dc_str_unref(tempText);
    return retval;
}


void DeltaHandler::addDeviceMessageForVersion(QString appVersion)
{
    // Device message for version 1.3.0;
    // remove/adapt for newer versions
    if (appVersion == "1.3.0" || appVersion == "1.3.1") {
        QString tempQString = "What's new in 1.3.0?<br><br>• 1:1 chats guarantee end-to-end encryption for introduced contacts now<br>• these contacts and chats are marked with green checkmarks<br>• voice message recording starts immediately<br>• HTML mail view (\"Show Full Message…\")<br><br>For full changelog see <a href=\"https://codeberg.org/lk108/deltatouch/src/branch/main/CHANGELOG\">https://codeberg.org/lk108/deltatouch/src/branch/main/CHANGELOG</a>";

        QString versionLabel = "1-3-0";

        addDeviceMessageToAllContexts(tempQString, versionLabel);
    }

    // Device message for version 1.3.1;
    if (appVersion == "1.3.1") {
        QString tempQString = "What's new in 1.3.1?<br><br>• App logs are redirected to file in cache to avoid sensitive data persisting in journald logs. Log file is deleted upon app closure.<br>• Log viewer page (via Advanced Settings)<br>• Fixed audio/file attachment preview<br>• Click on header in chat view opens profile of chat partner (1:1 chats) or group edit page<br>• Chat list shows status of outgoing messages<br>• Synchronize state of received messages across devices (needs support by mail server)<br>• New message count in account overview page<br><br>For full changelog see <a href=\"https://codeberg.org/lk108/deltatouch/src/branch/main/CHANGELOG\">https://codeberg.org/lk108/deltatouch/src/branch/main/CHANGELOG</a>";

        QString versionLabel = "1-3-1";

        addDeviceMessageToAllContexts(tempQString, versionLabel);
    }

    // Device message for version 1.4.0;
    if (appVersion == "1.4.0") {
        QString tempQString = "What's new in 1.4.0?<br><br>• Reactions! Long-press messages to react with an emoji.<br>• Many bugfixes and refactorings to enhance performance, improve UX and increase consistency with official clients.<br><br>For full changelog see <a href=\"https://codeberg.org/lk108/deltatouch/src/branch/main/CHANGELOG\">https://codeberg.org/lk108/deltatouch/src/branch/main/CHANGELOG</a>";

        QString versionLabel = "1-4-0";

        addDeviceMessageToAllContexts(tempQString, versionLabel);
    }
}


QString DeltaHandler::timeToString(uint64_t unixSeconds, bool divideByThousand)
{
    QString retval {""};

    if (divideByThousand) {
        unixSeconds /= 1000;
    }

    if (unixSeconds == 0) {
        retval = "";
    } else {
        QDateTime timestampDate;
        timestampDate = QDateTime::fromSecsSinceEpoch(unixSeconds);
        if (timestampDate.date() == QDate::currentDate()) {
            retval = timestampDate.toString("hh:mm");
            // TODO: if <option_for_am/pm> ...("hh:mm ap")
            // => check the QLocale Class
        }
        else if (timestampDate.date().daysTo(QDate::currentDate()) < 7) {
            // TODO: "...hh:mm ap " as above
            retval = timestampDate.toString("ddd hh:mm");
        }
        else {
            retval = timestampDate.toString("dd MMM yy" );
        }
    }

    return retval;
}


int DeltaHandler::intToMessageStatus(int status)
{
    int retval {0};

    switch(status) {
        case DC_STATE_OUT_PENDING:
            retval = DeltaHandler::MsgState::StatePending;
            break;

        case DC_STATE_OUT_FAILED:
            retval = DeltaHandler::MsgState::StateFailed;
            break;

        case DC_STATE_OUT_DELIVERED:
            retval = DeltaHandler::MsgState::StateDelivered;
            break;

        case DC_STATE_OUT_MDN_RCVD:
            retval = DeltaHandler::MsgState::StateReceived;
            break;
            
        default:
            // TODO: there are more states, and also states of
            // incoming messages
            retval = DeltaHandler::MsgState::StateUnknown;
            break;
    } 

    return retval;
}


void DeltaHandler::addDeviceMessageToAllContexts(QString deviceMessage, QString messageLabel)
{
    // need to cycle through all contexts and add a device message to all of them
    dc_array_t* tempArray = dc_accounts_get_all(allAccounts);

    for (size_t i = 0; i < dc_array_get_cnt(tempArray); ++i) {
        uint32_t tempAccID = dc_array_get_id(tempArray, i);
        dc_context_t* tempCon = dc_accounts_get_account(allAccounts, tempAccID);

        dc_msg_t* tempMsg = dc_msg_new(tempCon, DC_MSG_TEXT);
        dc_msg_set_text(tempMsg, deviceMessage.toUtf8().constData());

        dc_add_device_msg(tempCon, messageLabel.toUtf8().constData(), tempMsg);

        dc_msg_unref(tempMsg);
        dc_context_unref(tempCon);
    }

    dc_array_unref(tempArray);
}


void DeltaHandler::enableVerifiedOneOnOneForAllAccs()
{
    dc_array_t* tempArray = dc_accounts_get_all(allAccounts);

    for (size_t i = 0; i < dc_array_get_cnt(tempArray); ++i) {
        uint32_t tempAccID = dc_array_get_id(tempArray, i);
        dc_context_t* tempCon = dc_accounts_get_account(allAccounts, tempAccID);

        dc_set_config(tempCon, "verified_one_on_one_chats", "1");

        dc_context_unref(tempCon);
    }

    dc_array_unref(tempArray);
}


bool DeltaHandler::databaseIsEncryptedSetting()
{
    return m_encryptedDatabase;
}


// Method will not only set the database passphrase, but try to 
// open any closed account
void DeltaHandler::setDatabasePassphrase(QString passphrase, bool twiceChecked)
{
    if (m_closedAccounts.size() > 0) {
        // try to open all closed accounts
        bool failedToOpen = false;
        for (size_t i = 0; i < m_closedAccounts.size(); ++i) {
            uint32_t tempAccID = m_closedAccounts[i];
            tempContext = dc_accounts_get_account(allAccounts, tempAccID);
            qDebug() << "DeltaHandler::setDatabasePassphrase(): Trying to open account with ID " << tempAccID;
            if (0 == dc_context_open(tempContext, passphrase.toUtf8().constData())) {
                // incorrect passphrase, break the loop after emitting the failure signal
                qDebug() << "DeltaHandler::setDatabasePassphrase(): Could not open context: wrong passphrase or error on opening";
                if (i > 0) {
                    qDebug() << "DeltaHandler::setDatabasePassphrase():  WARNING: Previously, " << i << " context(s) could be opened with this passphrase!";
                }
                emit databaseDecryptionFailure();
                failedToOpen = true;
                // need to unref tempContext before break
                dc_context_unref(tempContext);
                tempContext = nullptr;
                break;
            } else {
                qDebug() << "DeltaHandler::setDatabasePassphrase(): Successfully opened account with ID " << tempAccID;
            }
            dc_context_unref(tempContext);
            tempContext = nullptr;
        }

        if (!failedToOpen) {
            emit databaseDecryptionSuccess();
            m_databasePassphrase = passphrase;

            // In a normal startup, eventThread is started in
            // loadSelectedAccount(), which is called AFTER possible
            // workflows to convert the database, but that's too late
            // for these workflows as they need the imex events.  It's
            // safe to call start() on the thread repeatedly as the
            // documentation says: "If the thread is already running,
            // this function does nothing."
            eventThread->start();
        }
    } else {
        // no closed accounts found at startup
        // OR
        // passphrase is set for the first time (in which case
        // this function should only be called after the passphrase
        // has been entered twice by the user and both entries match,
        // which should then signalled by the parameter twiceChecked being
        // true)
        if (twiceChecked) {
            m_databasePassphrase = passphrase;

            // eventThread is started in loadSelectedAccount(), which is
            // called AFTER possible workflows to convert the database, but
            // that's too late for the workflows as they need the imex events.
            // It's safe to call repeatedly as the documentation says:
            // "If the thread is already running, this function does nothing."
            eventThread->start();
        } else {
            // If we're here, the user has entered the passphrase only once
            // up to now, but no closed account exists. This is the case
            // - if the setting to encrypt the database is true, but
            //   no accounts exist at all or
            // - if the workflow to encrypt the databases (which is started if
            //   at least one account exists and the user checks the setting
            //   to encrypt the database) was interrupted before any database
            //   could be encrypted. In this case, the workflow will be resumed
            //   after next startup of the app, but the passphrase cannot be checked
            //   for correctness against a closed account. 
            emit noEncryptedDatabase();
        }
    }
    return;
}


bool DeltaHandler::hasEncryptedAccounts()
{
    return (m_closedAccounts.size() > 0);
}


bool DeltaHandler::hasDatabasePassphrase()
{
    return (m_databasePassphrase != "");
}


void DeltaHandler::invalidateDatabasePassphrase()
{
    resetPassphrase();
}


int DeltaHandler::numberOfUnconfiguredAccounts()
{
    dc_array_t* tempArray = dc_accounts_get_all(allAccounts);

    int numberUnconfigured {0};

    for (size_t i = 0; i < dc_array_get_cnt(tempArray); ++i) {
        uint32_t tempAccID = dc_array_get_id(tempArray, i);
        dc_context_t* tempcon = dc_accounts_get_account(allAccounts, tempAccID);
        if (dc_is_configured(tempcon) == 0) {
            ++numberUnconfigured;
        }
        dc_context_unref(tempcon);
    } 
    dc_array_unref(tempArray);

    return numberUnconfigured;
}


int DeltaHandler::numberOfEncryptedAccounts()
{
    return m_closedAccounts.size();
}


bool DeltaHandler::isCurrentDatabasePassphrase(QString pw)
{
    return m_databasePassphrase == pw;
}


void DeltaHandler::changeDatabasePassphrase(QString newPw)
{
    dc_context_t* tempcon {nullptr};

    for (size_t i = 0; i < m_closedAccounts.size(); ++i) {
        if (currentContext && m_closedAccounts[i] == m_currentAccID) {
            int success = dc_context_change_passphrase(currentContext, newPw.toUtf8().constData());
            if (success) {
                qDebug() << "DeltaHandler::changeDatabasePassphrase(): Success changing passphrase of account ID " << m_closedAccounts[i];
            } else {
                qDebug() << "DeltaHandler::changeDatabasePassphrase(): ERROR: Changing passphrase of account ID " << m_closedAccounts[i] << " failed";
            }

        } else {
            tempcon = dc_accounts_get_account(allAccounts, m_closedAccounts[i]);
            if (tempcon) {
                int success = dc_context_change_passphrase(tempcon, newPw.toUtf8().constData());
                if (success) {
                    qDebug() << "DeltaHandler::changeDatabasePassphrase(): Success changing passphrase of account ID " << m_closedAccounts[i];
                } else {
                    qDebug() << "DeltaHandler::changeDatabasePassphrase(): ERROR: Changing passphrase of account ID " << m_closedAccounts[i] << " failed";
                }
                dc_context_unref(tempcon);
            } else {
                qDebug() << "DeltaHandler::changeDatabasePassphrase(): ERROR: could not get context of account ID " << m_closedAccounts[i];
            }
        }
    }

    m_databasePassphrase = newPw;
}


void DeltaHandler::resetPassphrase()
{
    // only reset if there's no closed account left
    if (m_closedAccounts.size() == 0) {
        m_databasePassphrase = "";
    }
}


void DeltaHandler::changeEncryptedDatabaseSetting(bool shouldBeEncrypted)
{
    if (shouldBeEncrypted) {
        qDebug() << "DeltaHandler::changeEncryptedDatabaseSetting(): setting it to true";
    } else {
        qDebug() << "DeltaHandler::changeEncryptedDatabaseSetting(): setting it to false";
    }

    m_encryptedDatabase = shouldBeEncrypted;
    settings->setValue("encryptDb", shouldBeEncrypted);
}


void DeltaHandler::prepareDbConversionToEncrypted()
{
    m_networkingIsAllowed = false;
    emit networkingIsAllowedChanged();

    uint32_t currentAccountID {0};

    beginResetModel();

    m_chatlistVector.resize(0);

    if (currentContext) {
        currentAccountID = dc_get_id(currentContext);
        dc_context_unref(currentContext);
        currentContext = nullptr;
    }

    if (tempContext) {
        dc_context_unref(tempContext);
        tempContext = nullptr;
    }

    endResetModel();

    // To be on the safe side, disconnnect the imexProgress signal from all
    // possible slots
    disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
    disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupProviderProgressReceiver(int)));
    disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));

    m_workflowDbEncryption = new WorkflowDbToEncrypted(allAccounts, eventThread, settings, m_closedAccounts, currentAccountID, m_databasePassphrase);

    // Connect the successful end of the workflow with the accountsmodel.
    // Do NOT connect our own method databaseEncryptionCleanup() with the signal of the workflow
    // because this would prematurely destroy the workflow object
    bool connect_success = connect(m_workflowDbEncryption, SIGNAL(removedAccount(uint32_t)), m_accountsmodel, SLOT(reset()));
    if (!connect_success) {
        qDebug() << "DeltaHandler::prepareDbConversionToEncrypted(): ERROR: Could not connect signal removedAccount of m_workflowDbEncryption with slot reset of m_accountsmodel";
    }

    connect_success = connect(m_workflowDbEncryption, SIGNAL(addedNewClosedAccount(uint32_t)), m_accountsmodel, SLOT(reset()));
    if (!connect_success) {
        qDebug() << "DeltaHandler::prepareDbConversionToEncrypted(): ERROR: Could not connect signal addedNewClosedAccount of m_workflowDbEncryption with slot reset of m_accountsmodel";
    }

    connect_success = connect(m_workflowDbEncryption, SIGNAL(removedAccount(uint32_t)), this, SLOT(removeClosedAccountFromList(uint32_t)));
    if (!connect_success) {
        qDebug() << "DeltaHandler::prepareDbConversionToEncrypted(): ERROR: Could not connect signal removedAccount of m_workflowDbEncryption with slot removeClosedAccountFromList";
    }

    connect_success = connect(m_workflowDbEncryption, SIGNAL(addedNewClosedAccount(uint32_t)), this, SLOT(addClosedAccountToList(uint32_t)));
    if (!connect_success) {
        qDebug() << "DeltaHandler::prepareDbConversionToEncrypted(): ERROR: Could not connect signal addedNewClosedAccount of m_workflowDbEncryption with slot addClosedAccountToList";
    }
}


bool DeltaHandler::workflowToEncryptedPending()
{
    if (settings->contains("workflowDbToEncryptedRunning")) {
        return settings->value("workflowDbToEncryptedRunning").toBool();
    } else {
        return false;
    }
}


void DeltaHandler::databaseEncryptionCleanup()
{
    if (!m_workflowDbEncryption) {
        // Nothing to do if no workflow has been created
        return;
    }

    disconnect(m_workflowDbEncryption, SIGNAL(removedAccount(uint32_t)), m_accountsmodel, SLOT(reset()));
    disconnect(m_workflowDbEncryption, SIGNAL(addedNewClosedAccount(uint32_t)), m_accountsmodel, SLOT(reset()));
    disconnect(m_workflowDbEncryption, SIGNAL(removedAccount(uint32_t)), this, SLOT(removeClosedAccountFromList(uint32_t)));
    disconnect(m_workflowDbEncryption, SIGNAL(addedNewClosedAccount(uint32_t)), this, SLOT(addClosedAccountToList(uint32_t)));
    delete m_workflowDbEncryption;
    m_workflowDbEncryption = nullptr;

    dc_array_t* tempArray = dc_accounts_get_all(allAccounts);
    // have to open each account as they are closed now
    for (size_t i = 0; i < dc_array_get_cnt(tempArray); ++i) {
        uint32_t tempAccID = dc_array_get_id(tempArray, i);
        tempContext = dc_accounts_get_account(allAccounts, tempAccID);
        if (0 == dc_context_is_open(tempContext)) {
            dc_context_open(tempContext, m_databasePassphrase.toUtf8().constData());
        }
        dc_context_unref(tempContext);
        tempContext = nullptr;
    }
    dc_array_unref(tempArray);

    loadSelectedAccount();

    m_networkingIsAllowed = true;
    emit networkingIsAllowedChanged();
}


void DeltaHandler::prepareDbConversionToUnencrypted()
{
    m_networkingIsAllowed = false;
    emit networkingIsAllowedChanged();

    uint32_t currentAccountID {0};

    beginResetModel();

    m_chatlistVector.resize(0);

    if (currentContext) {
        currentAccountID = dc_get_id(currentContext);
        dc_context_unref(currentContext);
        currentContext = nullptr;
    }

    if (tempContext) {
        dc_context_unref(tempContext);
        tempContext = nullptr;
    }

    endResetModel();

    // To be on the safe side, disconnnect the imexProgress signal from all
    // possible slots
    disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
    disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupProviderProgressReceiver(int)));
    disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));

    m_workflowDbDecryption = new WorkflowDbToUnencrypted(allAccounts, eventThread, settings, m_closedAccounts, currentAccountID, m_databasePassphrase);

    // Connect the successful end of the workflow with the accountsmodel.
    // Do NOT connect our own method databaseEncryptionCleanup() with the signal of the workflow
    // because this would prematurely destroy the workflow object
    bool connect_success = connect(m_workflowDbDecryption, SIGNAL(removedAccount(uint32_t)), m_accountsmodel, SLOT(reset()));
    if (!connect_success) {
        qDebug() << "DeltaHandler::prepareDbConversionToUnencrypted(): ERROR: Could not connect signal removedAccount of m_workflowDbDecryption with slot reset of m_accountsmodel";
    }

    connect_success = connect(m_workflowDbDecryption, SIGNAL(addedNewOpenAccount()), m_accountsmodel, SLOT(reset()));
    if (!connect_success) {
        qDebug() << "DeltaHandler::prepareDbConversionToUnencrypted(): ERROR: Could not connect signal addedNewOpenAccount of m_workflowDbDecryption with slot reset of m_accountsmodel";
    }

    connect_success = connect(m_workflowDbDecryption, SIGNAL(removedAccount(uint32_t)), this, SLOT(removeClosedAccountFromList(uint32_t)));
    if (!connect_success) {
        qDebug() << "DeltaHandler::prepareDbConversionToUnencrypted(): ERROR: Could not connect signal removedAccount of m_workflowDbDecryption with slot removeClosedAccountFromList";
    }

    connect_success = connect(m_workflowDbDecryption, SIGNAL(workflowCompleted()), this, SLOT(resetPassphrase()));
    if (!connect_success) {
        qDebug() << "DeltaHandler::prepareDbConversionToUnencrypted(): ERROR: Could not connect signal removedAccount of m_workflowDbDecryption with slot removeClosedAccountFromList";
    }
}


bool DeltaHandler::workflowToUnencryptedPending()
{
    if (settings->contains("workflowDbToUnencryptedRunning")) {
        return settings->value("workflowDbToUnencryptedRunning").toBool();
    } else {
        return false;
    }
}


void DeltaHandler::databaseDecryptionCleanup()
{
    if (!m_workflowDbDecryption) {
        // Nothing to do if no workflow has been created
        return;
    }

    disconnect(m_workflowDbDecryption, SIGNAL(removedAccount(uint32_t)), m_accountsmodel, SLOT(reset()));
    disconnect(m_workflowDbDecryption, SIGNAL(addedNewOpenAccount()), m_accountsmodel, SLOT(reset()));
    disconnect(m_workflowDbDecryption, SIGNAL(removedAccount(uint32_t)), this, SLOT(removeClosedAccountFromList(uint32_t)));
    disconnect(m_workflowDbDecryption, SIGNAL(workflowCompleted()), this, SLOT(resetPassphrase()));
    delete m_workflowDbDecryption;
    m_workflowDbDecryption = nullptr;

    loadSelectedAccount();

    m_networkingIsAllowed = true;
    emit networkingIsAllowedChanged();
}


int DeltaHandler::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    // return our data count
    return static_cast<int>(m_chatlistVector.size());
}


int DeltaHandler::numberOfAccounts()
{
    dc_array_t* tempArray = dc_accounts_get_all(allAccounts);
    int retval = dc_array_get_cnt(tempArray);
    dc_array_unref(tempArray);
    qDebug() << "DeltaHandler::numberOfAccounts(): Number of accounts is" << retval;

    return retval;
}


QHash<int, QByteArray> DeltaHandler::roleNames() const
{
    QHash<int, QByteArray> roles;

//    roles[AccountIdRole] = "accountId";
//    roles[ChatIdRole] = "chatId";
    roles[ChatlistEntryRole] = "chatlistEntry";
    roles[BasicChatInfoRole] = "basicChatInfo";

    return roles;
}

QVariant DeltaHandler::data(const QModelIndex &index, int role) const
{
    int row = index.row();

    // If row is out of bounds, an empty QVariant is returned
    if(row < 0 || row >= static_cast<int>(m_chatlistVector.size()) || m_chatlistVector.size() == 0) {
        return QVariant();
    }

    uint32_t tempChatID = m_chatlistVector[row];
    
    char* tempText {nullptr};
    
    QByteArray byteArray;
    QJsonDocument jsonDoc;
    QJsonObject jsonObj;
    QString tempString;
    QString paramString;
    QString requestString;

    QVariant retval;

    switch(role) {
//        case DeltaHandler::AccountIdRole:
//            retval = m_currentAccID;
//            break;

//        case DeltaHandler::ChatIdRole:
//            retval = tempChatID;
//            break;

        case DeltaHandler::ChatlistEntryRole:
            tempString.setNum(m_currentAccID);
            paramString.append(tempString);

            paramString.append(", [");

            tempString.setNum(tempChatID);

            paramString.append(tempString);
            paramString.append("]");

            requestString = constructJsonrpcRequestString("get_chatlist_items_by_entries", paramString);

            // the actual object with the chatlist entry is nested in the
            // received json like this:
            // { .....,"result":{"<chatID>":{ <this is the actual entry> }}}
            // so we extract it
            byteArray = sendJsonrpcBlockingCall(requestString).toLocal8Bit();
            jsonDoc = QJsonDocument::fromJson(byteArray);
            jsonObj = jsonDoc.object();
            // value() returns a QJsonValue, which we directly
            // transform back to an object via toObject()
            jsonObj = jsonObj.value("result").toObject();
            // Next layer. tempString contains tempChatID as string
            jsonObj = jsonObj.value(tempString).toObject();

            retval = jsonObj;

            break;

        case DeltaHandler::BasicChatInfoRole:
            tempString.setNum(m_currentAccID);
            paramString.append(tempString);

            paramString.append(", ");

            tempString.setNum(tempChatID);
            paramString.append(tempString);

            requestString = constructJsonrpcRequestString("get_basic_chat_info", paramString);

            tempText = dc_jsonrpc_blocking_call(m_jsonrpcInstance, requestString.toLocal8Bit().constData());
            retval = (QString(tempText));

            break;

        default:
            retval = QString("");

    }

    if (tempText) {
        dc_str_unref(tempText);
        tempText = nullptr;
    }

    return retval;
}

ChatModel* DeltaHandler::chatmodel()
{
    return m_chatmodel;
}


AccountsModel* DeltaHandler::accountsmodel()
{
    return m_accountsmodel;
}


void DeltaHandler::prepareBlockedContactsModel()
{
    // TODO: Adapt the model each time the context
    // changes instead of making it mandatory
    // to call this method before using the model?
    if (!m_blockedcontactsmodel) {
        m_blockedcontactsmodel = new BlockedContactsModel();
    }

    if (!currentContext) {
        qFatal("DeltaHandler::blockedcontactsmodel(): FATAL ERROR: currentContext is not set, exiting.");
    }
    
    m_blockedcontactsmodel->updateContext(currentContext);

    emit blockedcontactsmodelChanged();
}


int DeltaHandler::getDeletionEstimation(QString secondsAsString, int fromServer)
{
    ulong seconds = secondsAsString.toULong();
    return dc_estimate_deletion_cnt(currentContext, fromServer, seconds);
}


void DeltaHandler::importKeys()
{
    QString keysToImportDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    keysToImportDir.append("/keys_to_import");
    dc_imex(currentContext, DC_IMEX_IMPORT_SELF_KEYS, keysToImportDir.toUtf8().constData(), NULL);
}


QString DeltaHandler::prepareExportKeys()
{
    QDateTime timestamp = QDateTime::currentDateTime();
    QString dateAsString = timestamp.toString("yyyyMMdd-hhmmss");

    bool dirAlreadyExisting = true;
    QString keysToExportDir("");
    int i {0};
    
    while (i < 50 && dirAlreadyExisting) {
        keysToExportDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
        keysToExportDir.append("/keys-exported-");
        keysToExportDir.append(dateAsString);
        dirAlreadyExisting = QFile::exists(keysToExportDir);
        ++i;
    }

    QDir tempdir;
    tempdir.mkpath(keysToExportDir);

    return keysToExportDir;
}


void DeltaHandler::startExportKeys(QString dirToExportTo)
{
    dc_imex(currentContext, DC_IMEX_EXPORT_SELF_KEYS, dirToExportTo.toUtf8().constData(), NULL);
}


BlockedContactsModel* DeltaHandler::blockedcontactsmodel()
{
    return m_blockedcontactsmodel;
}


ContactsModel* DeltaHandler::contactsmodel()
{
    return m_contactsmodel;
}


void DeltaHandler::setMomentaryChatIdByIndex(int myindex)
{
    m_momentaryChatId = m_chatlistVector[myindex];
}


void DeltaHandler::setMomentaryChatIdById(uint32_t myId)
{
    m_momentaryChatId = myId;
}


void DeltaHandler::selectChat(int myindex)
{
    currentChatID = m_chatlistVector[myindex];
}


void DeltaHandler::openChat()
{
    // stop the queue timer and process the queue
    if (m_signalQueueTimer->isActive()) {
        m_signalQueueTimer->stop();
        processSignalQueue();
    }


    if (currentChatID == DC_CHAT_ID_ARCHIVED_LINK) {
        // If the archive link has been clicked, reset
        // the model to show the archived chats only.
        m_showArchivedChats = true;

        // only clear the search string when switching to the archive
        // view, but not when opening a normal chat
        if (m_query != "") {
            m_query = "";
            emit clearChatlistQueryRequest();
        }

        dc_chatlist_t* tempChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, NULL, 0);
        resetChatlistVector(tempChatlist);
        dc_chatlist_unref(tempChatlist);

        emit chatlistShowsArchivedOnly(m_showArchivedChats);

    } else {
        // If it's not the archive link, open the corresponding
        // chat.
        dc_chat_t* tempChat = dc_get_chat(currentContext, currentChatID);
        bool contactRequest = dc_chat_is_contact_request(tempChat);
        dc_chat_unref(tempChat);

        std::vector<uint32_t> freshMessagesOfChat;

        for (size_t i = 0; i < freshMsgs.size(); ++i) {
            if (freshMsgs[i][1] == currentChatID) {
                freshMessagesOfChat.push_back(freshMsgs[i][0]);
            }
        }

        m_chatmodel->configure(currentChatID, currentContext, this, freshMessagesOfChat, contactRequest);
        currentChatIsOpened = true;

        emit openChatViewRequest(m_currentAccID, currentChatID);
    }
}


void DeltaHandler::archiveMomentaryChat()
{
    // stop the queue timer and process the queue
    // so the archive action is directly executed
    if (m_signalQueueTimer->isActive()) {
        m_signalQueueTimer->stop();
        processSignalQueue();
    }

    // It is not needed to modify the model/chatlist
    // because changing the visibility will trigger
    // DC_EVENT_MSGS_CHANGED, causing the messagesChanged() slot to reset
    // the model and the chatlist
    dc_set_chat_visibility(currentContext, m_momentaryChatId, DC_CHAT_VISIBILITY_ARCHIVED);
}


void DeltaHandler::unarchiveMomentaryChat()
{
    // stop the queue timer and process the queue
    // so the unarchive action is directly executed
    if (m_signalQueueTimer->isActive()) {
        m_signalQueueTimer->stop();
        processSignalQueue();
    }

    // see comments in archiveMomentaryChat(int)
    dc_set_chat_visibility(currentContext, m_momentaryChatId, DC_CHAT_VISIBILITY_NORMAL);
}


void DeltaHandler::pinUnpinMomentaryChat()
{
    // stop the queue timer and process the queue
    // so the pin/unpin action is directly executed
    if (m_signalQueueTimer->isActive()) {
        m_signalQueueTimer->stop();
        processSignalQueue();
    }

    // see comments in archiveMomentaryChat(int)
    dc_chat_t* tempChat = dc_get_chat(currentContext, m_momentaryChatId);

    if (DC_CHAT_VISIBILITY_PINNED == dc_chat_get_visibility(tempChat)) {
        dc_set_chat_visibility(currentContext, m_momentaryChatId, DC_CHAT_VISIBILITY_NORMAL);
    } else {
        dc_set_chat_visibility(currentContext, m_momentaryChatId, DC_CHAT_VISIBILITY_PINNED);
    }

    dc_chat_unref(tempChat);
}


bool DeltaHandler::momentaryChatIsMuted()
{
    dc_chat_t* tempChat = dc_get_chat(currentContext, m_momentaryChatId);

    // dc_chat_is_muted returns 1 if muted, 0 if not
    bool retbool = dc_chat_is_muted(tempChat) == 1;

    dc_chat_unref(tempChat);

    return retbool;
}


void DeltaHandler::momentaryChatSetMuteDuration(int64_t secondsToMute)
{
    // stop the queue timer and process the queue
    // so the mute action is directly executed
    if (m_signalQueueTimer->isActive()) {
        m_signalQueueTimer->stop();
        processSignalQueue();
    }

    qDebug() << "DeltaHandler::momentaryChatSetMuteDuration(): setting mute duration of " << secondsToMute << " for chat ID: " << m_momentaryChatId;
    int success = dc_set_chat_mute_duration(currentContext, m_momentaryChatId, secondsToMute);

    if (0 == success) {
        qWarning() << "DeltaHandler::chatSetMuteDuration(): Setting the mute duration failed";
    }
}


void DeltaHandler::closeArchive()
{
    m_showArchivedChats = false;

    // clear the query before obtaining a new chatlist
    if (m_query != "") {
        m_query = "";
        emit clearChatlistQueryRequest();
    }

    dc_chatlist_t* tempChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
    resetChatlistVector(tempChatlist);
    dc_chatlist_unref(tempChatlist);

    emit chatlistShowsArchivedOnly(m_showArchivedChats);
}


void DeltaHandler::selectAccount(int myindex)
{
    dc_array_t* contextArray = dc_accounts_get_all(allAccounts);

    if (myindex < 0 || myindex >= dc_array_get_cnt(contextArray)) {
        qDebug() << "DeltaHandler::selectAccount: Error: index out of bounds";
        return;
    }

    uint32_t newAccID = dc_array_get_id(contextArray, myindex);

    if (currentContext && newAccID == m_currentAccID) {
        qDebug() << "DeltaHandler::selectAccount: Selected account already active, doing nothing.";
        return;
    }

    if (m_showArchivedChats) {
        // Leave archive mode if a new account is selected.
        // The in-archive status of the previously selected
        // account is not preserved as it is probably too complex
        // for only a small or no benefit at all.
        closeArchive();
    }

    // stop the queue timer and process the queue
    // as it relates to the soon-to-be-outdated context
    if (m_signalQueueTimer->isActive()) {
        m_signalQueueTimer->stop();
        processSignalQueue();
    }

    if (tempContext) {
        dc_context_unref(tempContext);
    }

    uint32_t previousAccID = m_currentAccID;

    int success = dc_accounts_select_account(allAccounts, newAccID);
    if (0 == success) {
        qDebug() << "DeltaHandler::selectAccount: ERROR: dc_accounts_select_account was unsuccessful";
        return;
    }

    tempContext = dc_accounts_get_selected_account(allAccounts);

    if (!dc_is_configured(tempContext)) {
        qDebug() << "DeltaHandler::selectAccount: trying to select unconfigured account, refusing";
        dc_context_unref(tempContext);
        dc_accounts_select_account(allAccounts, previousAccID);
        return;
    }

    beginResetModel();

    if (currentContext) {
        dc_context_unref(currentContext);
    }

    currentContext = tempContext;
    tempContext = nullptr;
    contextSetupTasks();
    
    if (m_query != "") {
        m_query = "";
        emit clearChatlistQueryRequest();
    }

    currentChatIsOpened = false;

    endResetModel();

    emit accountChanged();
    
    dc_array_unref(contextArray);

    m_notificationHelper->removeSummaryNotification(m_currentAccID);
}


void DeltaHandler::messagesChanged(uint32_t accID, int chatID, int msgID)
{
    if (m_currentAccID == accID) {
        m_signalQueue_refreshChatlist = true;

        m_signalQueue_chatsDataChanged.push(chatID);

        if (currentChatID == chatID && currentChatIsOpened) {
            m_signalQueue_msgs.push(msgID);
        }
    }

    {
        // m_signalQueue_accountsmodelInfo is for m_accountsmodel,
        // make sure to avoid duplicate entries already here
        bool found {false};
        for (size_t i = 0; i < m_signalQueue_accountsmodelInfo.size(); ++i) {
            if (accID == m_signalQueue_accountsmodelInfo[i]) {
                found = true;
            }
        }

        if (!found) {
            m_signalQueue_accountsmodelInfo.push_back(accID);
        }
    }

    if (!m_signalQueueTimer->isActive()) {
        processSignalQueue();
        m_signalQueueTimer->start(queueTimerFreq);
    }
}

void DeltaHandler::processSignalQueueTimerTimeout()
{
    if (isQueueEmpty()) {
        m_signalQueueTimer->stop();
        return;
    } else {
        // if the queue is not empty, process the queue
        // now, but don't stop the timer
        processSignalQueue();
    }
}

void DeltaHandler::processSignalQueue()
{
    bool resetInsteadRefresh = false;

    { // check if the chatlist has to be refreshed / reset

        if (m_signalQueue_refreshChatlist) {
            m_signalQueue_refreshChatlist = false;

            // - a chat may have been deleted (chatID would be 0 then)
            // - a new chat may be present
            // - one or more new messages may have been received, so
            //   the new message counter and the message preview may be
            //   affected.
            dc_chatlist_t* tempChatlist {nullptr};
            
            if (m_showArchivedChats) {

                // If archived chats are not muted, they will be un-archived
                // automatically if a new message is received. For this
                // reason, when the user is looking at the archived chats
                // and a new message is received, it is checked whether the
                // newly gotten chatlist is empty. If so, it means that all
                // chats that were in the archive before have now been
                // un-archived due to new messages. In this case, the
                // archive view is closed automatically and the view
                // switches to the standard, non-archived chats.
                //
                // However, this cannot be done when the user has entered
                // something into the chat search bar because the chatlist
                // might be empty just due to zero search chats matching the
                // entered string. So in case the search string (m_query) is
                // not empty, there's no automatic closure of the archive
                // view. 
                // TODO: maybe there's a better solution?

                if (m_query == "") {
                    tempChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, NULL, 0);
                    if (0 == dc_chatlist_get_cnt(tempChatlist)) {
                        m_showArchivedChats = false;
                        emit chatlistShowsArchivedOnly(m_showArchivedChats);
                        dc_chatlist_unref(tempChatlist);
                        tempChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
                        resetInsteadRefresh = true;
                    }
                } else {
                    tempChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, m_query.toUtf8().constData(), 0);
                }

            } else {
                // we're in the standard (i.e., non-archive) view
                if (m_query == "") {
                    tempChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
                } else {
                    tempChatlist = dc_get_chatlist(currentContext, 0, m_query.toUtf8().constData(), 0);
                }
            }

            if (resetInsteadRefresh) {
                resetChatlistVector(tempChatlist);
            } else {
                refreshChatlistVector(tempChatlist);
            }

            dc_chatlist_unref(tempChatlist);
        }
    }

    {   // Notify the view about all changed chats.
        // Not needed if the chatlist has been reset
        // instead refreshed:
        if (resetInsteadRefresh) {
            // in this case, only m_signalQueue_chatsDataChanged has
            // to be emptied
            while (!m_signalQueue_chatsDataChanged.empty()) {
                m_signalQueue_chatsDataChanged.pop();
            }
        } else {
            // m_signalQueue_chatsDataChanged contains all chat IDs
            // that have to be notified. It's guaranteed that they
            // belong to the currently active context.
            //
            // First transfer m_signalQueue_chatsDataChanged to a vector
            // to eliminate duplicates:
            std::vector<int> chatsToRefresh;
            bool allChatsAffected = false;

            while (!m_signalQueue_chatsDataChanged.empty()) {
                int tempChatID = m_signalQueue_chatsDataChanged.front();
                m_signalQueue_chatsDataChanged.pop();

                if (allChatsAffected) {
                    // Don't abort the loop if all chats are affected
                    // because we have to clear the queue.
                    // No need to take care of the chatsToRefresh vector
                    // as it is only temporary.
                    continue;
                }

                if (0 == tempChatID) {
                    allChatsAffected = true;
                    continue;
                }

                size_t i = 0;
                while (i < chatsToRefresh.size()) {
                    if (tempChatID == chatsToRefresh[i]) {
                        break;
                    }
                    ++i;
                }

                if (i == chatsToRefresh.size()) {
                    // No break in the above for loop, so the chat ID
                    // is not yet in the vector, add it
                    chatsToRefresh.push_back(tempChatID);
                }
            }

            // Then do the actual notification of the model
            for (size_t i = 0; i < m_chatlistVector.size(); ++i) {
                if (allChatsAffected) {
                    emit dataChanged(index(i, 0), index(i, 0));
                } else {
                    for (size_t j = 0; j < chatsToRefresh.size(); ++j) {
                        if (m_chatlistVector[i] == chatsToRefresh[j]) {
                            emit dataChanged(index(i, 0), index(i, 0));
                            break;
                        }
                    }
                }
            }
        }
    }

    { // Emit the msgsChanged signal for all concerned msg IDs.
      // First transfer m_signalQueue_msgs to a vector
      // to eliminate duplicates:
        std::vector<int> msgsToEmit;

        while (!m_signalQueue_msgs.empty()) {
            int tempMsgID = m_signalQueue_msgs.front();
            m_signalQueue_msgs.pop();

            // can't check for 0 == tempMsgID here as 0 affects
            // only a certain chat. TODO: how to deal with this?
            size_t i = 0;
            while (i < msgsToEmit.size()) {
                if (tempMsgID == msgsToEmit[i]) {
                    break;
                }
                ++i;
            }

            if (i == msgsToEmit.size()) {
                // No break in the above for loop, so the chat ID
                // is not yet in the vector, add it
                msgsToEmit.push_back(tempMsgID);
            }
        }

        // Then do the actual notification of the model
        for (size_t i = 0; i < msgsToEmit.size(); ++i) {
            emit msgsChanged(msgsToEmit[i]);
        }
    }

    { // Take care of the MSGS_NOTICED signal
      // 
      // First transfer m_signalQueue_chatsNoticed to a vector
      // to eliminate duplicates:
        std::vector<int> chatsToConsider;

        while (!m_signalQueue_chatsNoticed.empty()) {
            int tempChatID = m_signalQueue_chatsNoticed.front();
            m_signalQueue_chatsNoticed.pop();

            size_t i = 0;
            while (i < chatsToConsider.size()) {
                if (tempChatID == chatsToConsider[i]) {
                    break;
                }
                ++i;
            }

            if (i == chatsToConsider.size()) {
                // No break in the above for loop, so the chat ID
                // is not yet in the vector, add it
                chatsToConsider.push_back(tempChatID);
            }
        }

        // Check all messages in freshMsgs for the concerned chat IDs
        size_t i = 0;
        size_t endpos = freshMsgs.size();
        for (size_t j = 0; j < chatsToConsider.size(); ++j) {
            while (i < endpos) {
                if (freshMsgs[i][1] == chatsToConsider[j]) {
                    dc_msg_t* tempMsg = dc_get_msg(currentContext, freshMsgs[i][0]);

                    // check if the message has actually been seen
                    if (dc_msg_get_state(tempMsg) == DC_STATE_IN_SEEN) {
                        // remove the message from freshMsgs if it has been seen
                        std::vector<std::array<uint32_t, 2>>::iterator it;
                        it = freshMsgs.begin();
                        freshMsgs.erase(it + i);
                        --endpos;
                    } else {
                        // only increase i if no item is removed from freshMsgs
                        ++i;
                    }

                    if (tempMsg) {
                        dc_msg_unref(tempMsg);
                    }
                } else {
                    // only increase i if no item is removed from freshMsgs
                    ++i;
                }
            }
        }
    }

    {
        // Remove notifications. As usual, check for duplicates first.
        std::vector<AccIdAndChatIdStruct> structsToConsider;

        while (!m_signalQueue_notificationsToRemove.empty()) {
            AccIdAndChatIdStruct tempStruct = m_signalQueue_notificationsToRemove.front();
            m_signalQueue_notificationsToRemove.pop();

            size_t i = 0;
            while (i < structsToConsider.size()) {
                AccIdAndChatIdStruct vecTemp = structsToConsider[i];
                if (tempStruct.accID == vecTemp.accID && tempStruct.chatID == vecTemp.chatID) {
                    break;
                }
                ++i;
            }

            if (i == structsToConsider.size()) {
                // No break in the above for loop, so the chat ID
                // is not yet in the vector, add it
                structsToConsider.push_back(tempStruct);
            }
        }

        // call removeActiveNotificationsOfChat for all concerned account/chat combinations
        for (size_t i = 0; i < structsToConsider.size(); ++i) {
            AccIdAndChatIdStruct tempStruct = structsToConsider[i];
            // TODO: need to take care of the fact that in case of Lomiri Postal,
            // when removeActiveNotificationsOfChat returns, the notification has
            // NOT been deleted yet - the actual deletion will happen upon
            // processing a signal triggered by DBus
            m_notificationHelper->removeActiveNotificationsOfChat(tempStruct.accID, tempStruct.chatID);
        }
    }

    {
        // Inform m_accountsmodel about changes.
        m_accountsmodel->updateFreshMsgCountAndContactRequests(m_signalQueue_accountsmodelInfo);
        m_signalQueue_accountsmodelInfo.resize(0);
    }
}


void DeltaHandler::messagesNoticed(uint32_t accID, int chatID)
{
    // DC_EVENT_MSGS_NOTICED will be emitted if messages were marked noticed or seen,
    // also if this was done by other devices. Things to do now are
    // - update new message counter in the chatlist
    // - remove read messages from freshMsgs
    // - remove notifications
    //
    // Note: DC_EVENT_MSGS_NOTICED is only emitted if the server supports
    // the IMAP extension CONDSTORE.

    // Refreshing the counter showing the new messages
    // is only necessary for currentContext, as the
    // chatlist will be reloaded in case of an account switch.
    // Same for the freshMsgs array.
    if (m_currentAccID == accID) {
        // to inform the model about changed data
        m_signalQueue_chatsDataChanged.push(chatID);
        
        // to remove the msgIDs from the vector freshMsgs
        m_signalQueue_chatsNoticed.push(chatID);
    }

    // Notifications have to be removed for all accounts
    m_signalQueue_notificationsToRemove.push(AccIdAndChatIdStruct { accID, chatID });

    if (!m_signalQueueTimer->isActive()) {
        processSignalQueue();
        m_signalQueueTimer->start(queueTimerFreq);
    }
}


void DeltaHandler::chatDataModifiedReceived(uint32_t accID, int chatID)
{
    if (m_currentAccID == accID && currentChatID == chatID && currentChatIsOpened) {
        emit chatDataChanged();
    }

    if (m_currentAccID == accID) {
        // to update the chatlist entry
        m_signalQueue_chatsDataChanged.push(chatID);
    }

    // to update m_accountsmodel
    {
        // m_signalQueue_accountsmodelInfo is for m_accountsmodel,
        // make sure to avoid duplicate entries already here
        bool found {false};
        for (size_t i = 0; i < m_signalQueue_accountsmodelInfo.size(); ++i) {
            if (accID == m_signalQueue_accountsmodelInfo[i]) {
                found = true;
            }
        }

        if (!found) {
            m_signalQueue_accountsmodelInfo.push_back(accID);
        }
    }


    if (!m_signalQueueTimer->isActive()) {
        processSignalQueue();
        m_signalQueueTimer->start(queueTimerFreq);
    }
}


void DeltaHandler::incomingMessage(uint32_t accID, int chatID, int msgID)
{
    if (m_currentAccID == accID) {
        // insert the new message into the vector containing all
        // unread messages of this context
        if (0 != chatID && 0 != msgID) {
            std::array<uint32_t, 2> tempStdArr {msgID, chatID};
            freshMsgs.push_back(tempStdArr);
        }
    }

    messagesChanged(accID, chatID, msgID);

    // notifications are handled via m_notificationHelper which
    // is connected to the incoming message event as well
}


void DeltaHandler::messageReadByRecipient(uint32_t accID, int chatID, int msgID)
{
    if (m_currentAccID == accID && currentChatID == chatID && currentChatIsOpened) {
        emit messageRead(msgID);
    }

    // update the chatlist to display changes in the state of the preview message
    if (m_currentAccID == accID) {
        m_signalQueue_chatsDataChanged.push(chatID);
    }
    
    if (!m_signalQueueTimer->isActive()) {
        processSignalQueue();
        m_signalQueueTimer->start(queueTimerFreq);
    }
}


void DeltaHandler::messageDeliveredToServer(uint32_t accID, int chatID, int msgID)
{
    if (m_currentAccID == accID && currentChatID == chatID && currentChatIsOpened) {
        emit messageDelivered(msgID);
    }
    
    // update the chatlist to display changes in the state of the preview message
    if (m_currentAccID == accID) {
        m_signalQueue_chatsDataChanged.push(chatID);
    }
    
    if (!m_signalQueueTimer->isActive()) {
        processSignalQueue();
        m_signalQueueTimer->start(queueTimerFreq);
    }
}


void DeltaHandler::messageFailedSlot(uint32_t accID, int chatID, int msgID)
{
    if (m_currentAccID == accID && currentChatID == chatID && currentChatIsOpened) {
        emit messageFailed(msgID);
    }

    // update the chatlist to display changes in the state of the preview message
    if (m_currentAccID == accID) {
        m_signalQueue_chatsDataChanged.push(chatID);
    }
    
    if (!m_signalQueueTimer->isActive()) {
        processSignalQueue();
        m_signalQueueTimer->start(queueTimerFreq);
    }
}


void DeltaHandler::msgReactionsChanged(uint32_t accID, int chatID, int msgID)
{
    if (m_currentAccID == accID && currentChatID == chatID && currentChatIsOpened) {
        emit messageReaction(msgID);
    }
}


QString DeltaHandler::chatName()
{
    if (currentChatIsOpened) {
        dc_chat_t* tempChat = dc_get_chat(currentContext, currentChatID);
        char* tempName = dc_chat_get_name(tempChat);
        QString name = tempName;
        dc_str_unref(tempName);
        dc_chat_unref(tempChat);
        return name;
    }
    else return QString();
}


bool DeltaHandler::chatIsVerified()
{
    bool retval = false;
    dc_chat_t* tempChat = dc_get_chat(currentContext, currentChatID);

    if (1 == dc_chat_is_protected(tempChat)) {
        retval = true;
    } 

    dc_chat_unref(tempChat);
    return retval;
}


QString DeltaHandler::getCurrentUsername()
{
    QString retval;
    if (currentContext) {
        char * tempString = dc_get_config(currentContext, "displayname");
        retval = tempString;
        dc_str_unref(tempString);
    }
    else {
        retval = "";
    }
    return retval;
}


QString DeltaHandler::getCurrentEmail()
{
    QString retval;
    if (currentContext) {
        char * tempString = dc_get_config(currentContext, "addr");
        retval = tempString;
        dc_str_unref(tempString);
    }
    else {
        retval = "";
    }
    return retval;
}


QString DeltaHandler::getCurrentProfilePic()
{
    QString retval;
    if (currentContext) {
        char * tempString = dc_get_config(currentContext, "selfavatar");
        retval = tempString;
        dc_str_unref(tempString);
        if (retval.length() >= QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length()) {
            retval.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
        }
        else {
            retval = "";
        }
    }
    else {
        retval = "";
    }
    return retval;
}


QString DeltaHandler::getCurrentConfig(QString key)
{
    // CAVE: if the config is a path, the path will not
    // be trimmed.
    QString retval;
    if (currentContext) {
        char * tempString = dc_get_config(currentContext, key.toUtf8().constData());
        retval = tempString;

//        if ("mail_pw" == key || "send_pw" == key || "socks5_password" == key) {
//            qDebug() << "DeltaHandler::getCurrentConfig() called for " << key << ", returning " << "*****";
//        } else {
//            qDebug() << "DeltaHandler::getCurrentConfig() called for " << key << ", returning " << retval;
//        }

        dc_str_unref(tempString);
    }
    else {
        retval = "";
    }
    return retval;
}


bool DeltaHandler::hasConfiguredAccount()
{
    return m_hasConfiguredAccount;
}


bool DeltaHandler::networkingIsAllowed()
{
    return m_networkingIsAllowed;
}


bool DeltaHandler::networkingIsStarted()
{
    return m_networkingIsStarted;
}


QString DeltaHandler::getMomentaryChatName()
{
    QString tempQString;
    dc_chat_t* tempChat = dc_get_chat(currentContext, m_momentaryChatId);

    if (tempChat) {
        char* tempText = dc_chat_get_name(tempChat);
        tempQString = tempText;

        dc_str_unref(tempText);
        dc_chat_unref(tempChat);
    } else {
        tempQString = "";
    }

    return tempQString;
}


uint32_t DeltaHandler::getChatEphemeralTimer(int myindex)
{
    uint32_t tempChatID;

    if (myindex == -1) {
        tempChatID = currentChatID;
    } else {
        tempChatID = m_chatlistVector[myindex];
    }

    return dc_get_chat_ephemeral_timer(currentContext, tempChatID);
}


void DeltaHandler::setChatEphemeralTimer(int myindex, uint32_t timer)
{
    uint32_t tempChatID;

    if (myindex == -1) {
        tempChatID = currentChatID;
    } else {
        tempChatID = m_chatlistVector[myindex];
    }

    if (timer != getChatEphemeralTimer(myindex)) {
        dc_set_chat_ephemeral_timer(currentContext, tempChatID, timer);
    }
}


void DeltaHandler::deleteMomentaryChat()
{
    // stop the queue timer and process the queue
    // so the chat deletion is directly executed
    if (m_signalQueueTimer->isActive()) {
        m_signalQueueTimer->stop();
        processSignalQueue();
    }

    dc_delete_chat(currentContext, m_momentaryChatId);
}


void DeltaHandler::setCurrentConfig(QString key, QString newValue)
{
    qDebug() << "DeltaHandler::setCurrentConfig() called for key " << key;

    if ("selfavatar" == key) {
        // have to check for the special case where the
        // selfavatar should be deleted
        if ("" == newValue) {
            int success = dc_set_config(currentContext, key.toUtf8().constData(), NULL);

            if (!success) {
                qDebug() << "DeltaHandler::setCurrentConfig: ERROR: Setting key " << key << " to \"\" was not successful.";
            }
 
            emit accountChanged();
            return;
        }
        else {
            // newValue might be prepended by "file://" or "qrc:",
            // remove it
            QString tempQString = newValue;
            if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
                newValue.remove(0, 7);
            }

            tempQString = newValue;
            if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
                newValue.remove(0, 4);
            }
        }
    }

    // sentbox_watch, mvbox_move and only_fetch_mvbox changes require restarting IO
    bool restartIOrequired = false;
    if ("sentbox_watch" == key || "mvbox_move" == key || "only_fetch_mvbox" == key) {
        // TODO: maybe check every key whether newValue is already the current value?
        // Then only restartIOrequired would have to be set here
        char* tempText = dc_get_config(currentContext, key.toUtf8().constData());
        QString tempString = tempText;
        dc_str_unref(tempText);
        if (tempString != newValue) {
            restartIOrequired = true;
        }
    }

    int success = dc_set_config(currentContext, key.toUtf8().constData(), newValue.toUtf8().constData());

    if (!success) {
        qDebug() << "DeltaHandler::setCurrentConfig: ERROR: Setting key " << key << " to " << newValue << " was not successful.";
    }

    // only restart IO if it is actually started
    if (restartIOrequired && m_networkingIsStarted) {
        stop_io();
        start_io();
    }
 
    // TODO: emit only if profile pic or displayname changed?
    emit accountChanged();
//    emit updatedAccountConfig(dc_get_id(currentContext));
}


void DeltaHandler::setTempContext(uint32_t accID)
{
    if (tempContext) {
        qDebug() << "DeltaHandler::configureAccount: ERROR: tempContext is unexpectedly set";
        dc_context_unref(tempContext);
    }
    
    // If the currently active account (i.e., the one of currentContext)
    // is selected for configuration, tempContext will be set to
    // currentContext. Needs to be considered when unsetting
    // tempContext again in
    // - unrefTempContext()
    // - progressEvent()
    if (currentContext) {
        if (accID == m_currentAccID) {
            tempContext = currentContext;
        } else {
            tempContext = dc_accounts_get_account(allAccounts, accID);
        }
    } else {
        tempContext = dc_accounts_get_account(allAccounts, accID);
    }
}


QString DeltaHandler::getTempContextConfig(QString key)
{
    QString retval;

    if (!tempContext) {
        qDebug() << "DeltaHandler::getTempContextConfig: tempContext is not set, returning empty string";
        retval = "";
    }
    else {
        char* tempText = dc_get_config(tempContext, key.toUtf8().constData());
        retval = tempText;
        dc_str_unref(tempText);
    }

    if ("mail_pw" == key || "send_pw" == key || "socks5_password" == key) {
        qDebug() << "DeltaHandler::getTempContextConfig() called for " << key << ", returning " << "*****";
    } else {
        qDebug() << "DeltaHandler::getTempContextConfig() called for " << key << ", returning " << retval;
    }
    return retval;
}


void DeltaHandler::setTempContextConfig(QString key, QString val)
{
    QString origVal = getTempContextConfig(key);
    if (origVal == val) {

        if ("mail_pw" == key || "send_pw" == key || "socks5_password" == key) {
            qDebug() << "DeltaHandler::setTempContextConfig: Not setting key " << key << " to ***** as it has not changed.";
        } else {
            qDebug() << "DeltaHandler::setTempContextConfig: Not setting key " << key << " to " << val << " as it has not changed.";
        }

    } else {
        dc_set_config(tempContext, key.toUtf8().constData(), val.toUtf8().constData());

        if ("mail_pw" == key || "send_pw" == key || "socks5_password" == key) {
            qDebug() << "DeltaHandler::setTempContextConfig: Setting " << key << " to " << "*****";
        } else {
            qDebug() << "DeltaHandler::setTempContextConfig: Setting " << key << " to " << val;
        }
    }
}


void DeltaHandler::deleteTemporaryAccount()
{
    // Detection of whether tempContext
    // really contains a temporary account
    // is done via m_configuringNewAccount
    if (m_configuringNewAccount && tempContext) {
        int tempAccID = dc_get_id(tempContext);
        qDebug() << "DeltaHandler::deleteTemporaryAccount(): deleting account ID " << tempAccID;
        dc_context_unref(tempContext);
        tempContext = nullptr;
        dc_accounts_remove_account(allAccounts, tempAccID);
        m_configuringNewAccount = false;
    } else {
        qDebug() << "DeltaHandler::deleteTemporaryAccount() called, but not deleting anything";
    }
}


void DeltaHandler::prepareTempContextConfig()
{
    // If tempContext is already set, either an existing account has
    // been selected for changing the configuration or the user
    // encountered an error while configuring a new account and is still
    // in the mask to enter addr and password and such, and is
    // presumably correcting these entries, so we will change the
    // configuration of this context.
    //
    // Note that tempContext is set to nullptr
    // - after a successful configuration by the slot progressEvent
    //   of this class
    // - when leaving the addEmailAccount page as this page will
    //   emit the signal "leavingAddEmailPage", which is connected
    //   to the slot unrefTempContext()
    if (!tempContext) {
        uint32_t accID;

        if (m_encryptedDatabase) {
            if (m_databasePassphrase == "") {
                qDebug() << "DeltaHandler::prepareQrBackupImport(): ERROR: No passphrase for database encryption present, cannot create account.";
                return;
            }

            accID = dc_accounts_add_closed_account(allAccounts);
            if (0 == accID) {
                qDebug() << "DeltaHandler::prepareTempContextConfig: Could not create new account.";
                // TODO: emit signal for failure?
                return;
            }
            tempContext = dc_accounts_get_account(allAccounts, accID);
            dc_context_open(tempContext, m_databasePassphrase.toUtf8().constData());

        } else {
            accID = dc_accounts_add_account(allAccounts);
            if (0 == accID) {
                qDebug() << "DeltaHandler::prepareTempContextConfig: Could not create new account.";
                // TODO: emit signal for failure?
                return;
            }
            tempContext = dc_accounts_get_account(allAccounts, accID);
        }

        // Enable verified 1:1 chats on the new account
        dc_set_config(tempContext, "verified_one_on_one_chats", "1");

        m_configuringNewAccount = true;
    } else {
        m_configuringNewAccount = false;
    }
}

void DeltaHandler::configureTempContext()
{
    // "During configuration IO must not be started"
    m_networkingIsAllowed = false;
    emit networkingIsAllowedChanged();

    dc_configure(tempContext);

    // Acc to DC documentation, dc_configure returns
    // immediately, but the configuration process may
    // take a while. So we cannot allow networking here.
    // Instead, it has to be allowed once the configuration process
    // is finished, i.e. in progressEvent()
}


void DeltaHandler::progressEvent(int perMill, QString errorMsg)
{

    emit progressEventReceived(perMill, errorMsg);
    if (perMill == 0) {
        // A newly added account is automatically the selected account
        // as per documentation for dc_accounts_add_account(). But if
        // the new account could not be successfully configured, we
        // shouldn't switch to it. Probably this account should also
        // not be selected then, especially considering that the app
        // will try to choose the unconfigured account upon the next
        // startup. It will find it unconfigured, and will then just
        // select the first configured account. This may be a
        // different one that the one that was previously active for
        // the user. To prevent that, we re-select the currently
        // active (and configured) account.

        if (currentContext) {
            dc_accounts_select_account(allAccounts, m_currentAccID);
        }
        if (m_configuringNewAccount) {
            emit newUnconfiguredAccount(); 

            // If configuration was not successful,
            // AddOrConfigureEmailAccount.qml will still be the current
            // page. To prevent the account from being deleted if the
            // user exits this page via x (i.e., close),
            // m_configuringNewAccount has to be set to false (as it is
            // used to decide whether a potential temporary account has
            // to be deleted when the page is exited via x) Also, upon a
            // second round of configuring, it's not a new account
            // anymore? => TODO check if this is true
            m_configuringNewAccount = false;

            if (m_encryptedDatabase) {
                m_closedAccounts.push_back(dc_get_id(tempContext));
            }
        } else {
            emit updatedAccountConfig(dc_get_id(tempContext));
        }

        // allow networking again, see configureTempContext()
        m_networkingIsAllowed = true;
        emit networkingIsAllowedChanged();

    } else if (perMill == 1000) {
        beginResetModel();

        // If the user has selected the currently active account
        // (= currentContext) for re-configuration, setTempContext() has
        // set tempContext = currentContext. So currentContext
        // must only be unref'd if it is != tempContext.
        if (currentContext && currentContext != tempContext) {
            dc_context_unref(currentContext);
        }

        // checking for the special case where tempContext ==
        // currentContext (see comment above) is not absolutely
        // necessary for the following sequences, so we skip it
        // to avoid making the code unnecessarily complicated - it's
        // too complicated already :-(
        bool restartNetwork = m_networkingIsStarted;
        if (m_networkingIsStarted) {
            stop_io();
        }
        currentContext = tempContext;
        tempContext = nullptr;
        contextSetupTasks();

        if (m_query != "") {
            m_query = "";
            emit clearChatlistQueryRequest();
        }

        currentChatIsOpened = false;

        if (restartNetwork) {
            start_io();
        }

        if (!m_hasConfiguredAccount) {
            m_hasConfiguredAccount = true;
            emit hasConfiguredAccountChanged();
        }
        endResetModel();
        // TODO: correct order of actions in lines above + below?
        if (m_configuringNewAccount) {
            emit newConfiguredAccount();
            if (m_encryptedDatabase) {
                m_closedAccounts.push_back(m_currentAccID);
            }
            emit accountChanged();
            // This should not be needed here as unlike in the case
            // of progress == 0, AddOrConfigureEmailAccount.qml should
            // not be presented to the user anymore, but just to be sure
            // (for more details see same line above)
            m_configuringNewAccount = false;
        } else {
            emit updatedAccountConfig(m_currentAccID);
            emit accountChanged();
        }

        // allow networking again, see configureTempContext()
        m_networkingIsAllowed = true;
        emit networkingIsAllowedChanged();
    }
}


void DeltaHandler::imexBackupImportProgressReceiver(int perMill)
{
    emit imexEventReceived(perMill);
    if (perMill == 0) {
        // If the backup import was not successful, re-select the
        // currently active (and configured) account and delete the
        // new account that has been prepared for the importing
        // process.
        if (currentContext) {
            dc_accounts_select_account(allAccounts, m_currentAccID);
        }
        
        if (tempContext) {
            int tempAccID = dc_get_id(tempContext);
            dc_context_unref(tempContext);
            tempContext = nullptr;
            dc_accounts_remove_account(allAccounts, tempAccID);
        }
        m_networkingIsAllowed = true;
        emit networkingIsAllowedChanged();
    } else if (perMill == 1000) {
        // Enable verified 1:1 chats on the new account
        dc_set_config(tempContext, "verified_one_on_one_chats", "1");

        beginResetModel();

        if (currentContext) {
            dc_context_unref(currentContext);
        }

        bool restartNetwork = m_networkingIsStarted;
        if (m_networkingIsStarted) {
            stop_io();
        }
        currentContext = tempContext;
        tempContext = nullptr;
        contextSetupTasks();

        if (m_query != "") {
            m_query = "";
            emit clearChatlistQueryRequest();
        }

        if (restartNetwork) {
            start_io();
        }

        currentChatIsOpened = false;

        if (!m_hasConfiguredAccount) {
            m_hasConfiguredAccount = true;
            emit hasConfiguredAccountChanged();
        }
        endResetModel();

        emit newConfiguredAccount();
        if (m_encryptedDatabase) {
            m_closedAccounts.push_back(m_currentAccID);
        }
        emit accountChanged();
        m_networkingIsAllowed = true;
        emit networkingIsAllowedChanged();
    }
}


void DeltaHandler::imexBackupExportProgressReceiver(int perMill)
{
    emit imexEventReceived(perMill);
}


void DeltaHandler::imexFileReceiver(QString filepath)
{
    // no further files are expected to be written,
    // so the signal is disconnected
    disconnect(eventThread, SIGNAL(imexFileWritten(QString)), this, SLOT(imexFileReceiver(QString)));

    m_tempExportPath = filepath;
    m_tempExportPath.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length() + 1);

    emit backupFileWritten();
}


void DeltaHandler::chatCreationReceiver(uint32_t chatID)
{
    // Resetting model, re-loading the chatlist not
    // needed because the emitter emits the signal
    // newMsg which is connected to the slot incomingMessage.
    // The slot will take care of adding the new
    // chat to the chatlist.
     
    // NOT calling selectChat(int) as the parameter of
    // this method is the array index, not the chatID
    currentChatID = chatID; 
    openChat();
}


void DeltaHandler::appIsActiveAgainActions()
{
    if (!currentChatIsOpened) {
        m_notificationHelper->removeSummaryNotification(m_currentAccID);
    }
}


void DeltaHandler::unrefTempContext()
{
    if (tempContext != currentContext) {
        if (tempContext) {
            dc_context_unref(tempContext);
            tempContext = nullptr;
        }
    } else {
        tempContext = nullptr;
    }
}


void DeltaHandler::unselectAccount(uint32_t accIDtoUnselect)
{
    if (m_currentAccID != accIDtoUnselect) {
        qDebug() << "DeltaHandler::unselectAccount: Being called to unselect account id " << accIDtoUnselect << ", but it is already not the selected account.";
        return;
    }

    beginResetModel();
    
    dc_array_t* tempArray = dc_accounts_get_all(allAccounts);
    size_t noOfAccounts = m_accountsmodel->rowCount(QModelIndex());

    if (1 == noOfAccounts) {
        dc_context_unref(currentContext);
        currentContext = nullptr;
        m_currentAccID = 0;
        m_notificationHelper->setCurrentAccId(m_currentAccID);
        m_chatlistVector.resize(0);
        if (m_hasConfiguredAccount) {
            m_hasConfiguredAccount = false;
            emit hasConfiguredAccountChanged();
        }
    }
    else { // more accounts than one are present
        if (tempContext) {
            qDebug() << "DeltaHandler::unselectAccount: tempContext was set, will now be unref'd.";
            dc_context_unref(tempContext);
            tempContext = nullptr;
        }

        bool foundConfiguredAccount {false};
        uint32_t accountToSwitchTo {0};

        for (size_t i = 0; i < noOfAccounts; ++i) {
            uint32_t tempAccID = dc_array_get_id(tempArray, i);
            // cannot choose the account that is to be unselected
            if (accIDtoUnselect == tempAccID) {
                continue;
            }

            accountToSwitchTo = tempAccID;
            tempContext = dc_accounts_get_account(allAccounts, tempAccID);

            if (dc_is_configured(tempContext)) {
                // The first configured account is chosen. tempContext
                // remains set in this case.
                foundConfiguredAccount = true;
                break;
            }

            dc_context_unref(tempContext);
        } // for

        // TODO check return value
        dc_accounts_select_account(allAccounts, accountToSwitchTo);

        if (foundConfiguredAccount) {
            qDebug() << "DeltaHandler::unselectAccount: Choosing configured account " << accountToSwitchTo << "as new selected account.";
            dc_context_unref(currentContext);

            bool restartNetwork = m_networkingIsStarted;
            if (m_networkingIsStarted) {
                stop_io();
            }
            currentContext = tempContext;
            // Not setting tempContext to nullptr here, will be done further below
            //tempContext = nullptr;
            contextSetupTasks();

            if (m_query != "") {
                m_query = "";
                emit clearChatlistQueryRequest();
            }

            if (restartNetwork) {
                start_io();
            }

        }
        else {
            qDebug() << "DeltaHandler::unselectAccount: No configured account available. Choosing unconfigured account " << accountToSwitchTo << "as new selected account.";
            // If no configured account was found, tempContext is already unref'd
            dc_context_unref(currentContext);

            bool restartNetwork = m_networkingIsStarted;
            if (m_networkingIsStarted) {
                stop_io();
            }
            currentContext = dc_accounts_get_account(allAccounts, accountToSwitchTo);
            // not calling contextSetupTasks() here as the context is not configured
            m_currentAccID = dc_get_id(currentContext);
            m_notificationHelper->setCurrentAccId(m_currentAccID);

            // TODO restarting network in this case makes no sense
            if (restartNetwork) {
                start_io();
            }
        }

        // setting tempContext to nullptr here to avoid having to do
        // so in the loop above.
        tempContext = nullptr;

        if (foundConfiguredAccount != m_hasConfiguredAccount) {
            m_hasConfiguredAccount = !m_hasConfiguredAccount;
            emit hasConfiguredAccountChanged();
        }
            //currentChatIsOpened = false; // should be set by the
            //chatview page, see comment on introduction of this
            //variable

    } // else if (1 == noOfAccounts)

    dc_array_unref(tempArray);
        
    endResetModel();
    emit accountChanged();
}


void DeltaHandler::start_io()
{
    if (!m_networkingIsStarted) {
        dc_accounts_start_io(allAccounts);
        m_networkingIsStarted = true;
    }
    else {
        qDebug() << "DeltaHandler::start_io(): ERROR: start_io() called, but m_networkingIsStarted is true";
    }
}


void DeltaHandler::stop_io()
{
    if (m_networkingIsStarted) {
        dc_accounts_stop_io(allAccounts);
        m_networkingIsStarted = false;
    }
    else {
        qDebug() << "DeltaHandler::stop_io(): ERROR: stop_io() called, but m_networkingIsStarted is false";
    }
}


bool DeltaHandler::isValidAddr(QString address)
{
    if (1 == dc_may_be_valid_addr(address.toUtf8().constData())) {
        return true;
    } else {
        return false;
    }
}


bool DeltaHandler::isBackupFile(QString filePath)
{
    // filePath might be prepended by "file://" or "qrc:", remove it
    QString tempQString = filePath;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        filePath.remove(0, 7);
    }

    tempQString = filePath;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        filePath.remove(0, 4);
    }

    // filename, filePath, purePath, origFile refer to the actual location
    // of the (potential) backup file
    QString fileName = filePath.section('/', -1);
    QString purePath = filePath;
    purePath.resize(filePath.length() - fileName.length());

    QFile origFile(filePath);

    // dc_imex_has_backup expects a directory as parameter,
    // not a file, so to avoid that the core checks the wrong file,
    // a dedicated directory in the cache dir is created.
    // This directory must only contain one single file/link.
    // Just delete the dir, if it exists, and re-create it - it
    // should never contain anything else than a link to a
    // potential backup file
    QString linkdirString(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/backupfile-testdir/");
    QDir linkDir(linkdirString);
    linkDir.removeRecursively();
    linkDir.mkpath(linkdirString);
    
    QString linkname(linkdirString + fileName);

    bool success = origFile.link(linkname);
    if (!success) {
        qDebug() << "DeltaHandler::isBackupFile(): Could not create the link to the backup file, function will return false, backup will not succeed";
    }
    
    if (tempContext) {
        qDebug() << "DeltaHandler::isBackupFile: tempContext is unexpectedly set, will now be unref'd";
        dc_context_unref(tempContext);
        tempContext = nullptr;
    }

    uint32_t accID;

    if (m_encryptedDatabase) {
        if (m_databasePassphrase == "") {
            qDebug() << "DeltaHandler::prepareQrBackupImport(): ERROR: Plaintext key for database encryption is not present, cannot create account.";
            return false;
        }

        accID = dc_accounts_add_closed_account(allAccounts);
        if (0 == accID) {
            qDebug() << "DeltaHandler::isBackupFile: Could not create new account.";
            return false;
        }
        tempContext = dc_accounts_get_account(allAccounts, accID);
        dc_context_open(tempContext, m_databasePassphrase.toUtf8().constData());

    } else {
        accID = dc_accounts_add_account(allAccounts);
        if (0 == accID) {
            qDebug() << "DeltaHandler::isBackupFile: Could not create new account.";
            return false;
        }
        tempContext = dc_accounts_get_account(allAccounts, accID);
    }

    char* tempText = dc_imex_has_backup(tempContext, linkdirString.toUtf8().constData());
    QString tempFile = tempText;
    
    bool isBackup;

    if (tempFile == linkname) {
        isBackup = true;

        qDebug() << "DeltaHandler::isBackupFile: yes, it is a backup file";

    } else {
        isBackup = false;
        dc_context_unref(tempContext);
        tempContext = nullptr;
        dc_accounts_remove_account(allAccounts, accID);
        qDebug() << "DeltaHandler::isBackupFile: no, it is not a backup file";
    }

    dc_str_unref(tempText);

    return isBackup;
}


void DeltaHandler::importBackupFromFile(QString filePath)
{
    // imexProgress may be connected to imexBackupExportProgressReceiver or imexBackupProviderProgressReceiver
    // disconnect it. Also disconnect it from imexBackupImportProgressReceiver, too, to avoid being
    // connected twice.
    //
    // TODO check return values?
    bool disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));
    disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupProviderProgressReceiver(int)));
    disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
    
    // ... and connect it to imexBackupImportProgressReceiver
    bool connectSuccess = connect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal imexProgress to slot imexBackupImportProgressReceiver");
    }

    // filePath might be prepended by "file://" or "qrc:",
    // remove it
    QString tempQString = filePath;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        filePath.remove(0, 7);
    }

    tempQString = filePath;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        filePath.remove(0, 4);
    }

    qDebug() << "DeltaHandler::importBackupFromFile: path to backup file is: " << filePath;
    m_networkingIsAllowed = false;
    // not emitting signal, but stopping io directly
    stop_io();
    // TODO: implement password for importing backup
    dc_imex(tempContext, DC_IMEX_IMPORT_BACKUP, filePath.toUtf8().constData(), NULL);
}


void DeltaHandler::chatAccept()
{
    // need to check whether it's really a contact request
    // because dc_accept_chat is also used for protected
    // chats (to continue if the partner has not used its key)
    dc_chat_t* tempChat = dc_get_chat(currentContext, currentChatID);
    bool isContactRequest = dc_chat_is_contact_request(tempChat);
    dc_chat_unref(tempChat);

    dc_accept_chat(currentContext, currentChatID);
    m_chatmodel->acceptChat();

    if (isContactRequest) {
        emit chatIsNotContactRequestAnymore(m_currentAccID, currentChatID);
    }
}


void DeltaHandler::chatDeleteContactRequest()
{
    // probably not needed to check if it's really 
    // a contact request, but done anyway
    dc_chat_t* tempChat = dc_get_chat(currentContext, currentChatID);
    bool isContactRequest = dc_chat_is_contact_request(tempChat);
    dc_chat_unref(tempChat);

    dc_delete_chat(currentContext, currentChatID);

    if (isContactRequest) {
        emit chatIsNotContactRequestAnymore(m_currentAccID, currentChatID);
    }
}


void DeltaHandler::chatBlockContactRequest()
{
    // probably not needed to check if it's really 
    // a contact request, but done anyway
    dc_chat_t* tempChat = dc_get_chat(currentContext, currentChatID);
    bool isContactRequest = dc_chat_is_contact_request(tempChat);
    dc_chat_unref(tempChat);

    dc_block_chat(currentContext, currentChatID);

    if (isContactRequest) {
        emit chatIsNotContactRequestAnymore(m_currentAccID, currentChatID);
    }
}


void DeltaHandler::exportBackup()
{
    if (!currentContext) return;

    // imexProgress may be connected to imexBackupImportProgressReceiver or imexBackupProviderProgressReceiver,
    // disconnect it...
    // TODO: imexBackupExportProgressReceiver is disconnected, too, because
    // it might cause problems if it's connected twice, is this true?
    // TODO check return values?
    bool disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
    disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupProviderProgressReceiver(int)));
    disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));
    
    // ... and connect it to imexBackupExportProgressReceiver instead
    bool connectSuccess = connect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal imexProgress to slot imexBackupExportProgressReceiver");
    }

    connectSuccess = connect(eventThread, SIGNAL(imexFileWritten(QString)), this, SLOT(imexFileReceiver(QString)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::DeltaHandler: Could not connect signal imexFileWritten to slot imexFileReceiver");
    }

    QString cacheDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));

    dc_imex(currentContext, DC_IMEX_EXPORT_BACKUP, cacheDir.toUtf8().constData(), NULL);
}


QString DeltaHandler::saveBackupFile(QString destinationFolder)
{
    QString tempQString = destinationFolder;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        destinationFolder.remove(0, 7);
    }

    tempQString = destinationFolder;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        destinationFolder.remove(0, 4);
    }

    QString sourceFileName = m_tempExportPath.section('/', -1);

    QString destinationFile = destinationFolder + "/" + sourceFileName;

    unsigned int counter {1};

    while (QFile::exists(destinationFile)) {
        QString basename = sourceFileName;
        QString suffix = basename.section('.', -1);
        basename.remove(basename.length() - 4, 4);
        QString tempNumber;
        tempNumber.setNum(counter);
        basename.append("_");
        basename.append(tempNumber);
        basename.append(".");
        basename.append(suffix);
        destinationFile = destinationFolder + "/" + basename;

        ++counter;
    }

    QString sourceFile(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/" + m_tempExportPath);
    bool success = QFile::copy(sourceFile, destinationFile);

    if (success) {
        return destinationFile;
    } else {
        qDebug() << "DeltaHandler::saveBackupFile(): ERROR: Could not save the backup to " << destinationFile;
        // Do not emit errorEvent, but return empty string
        // and let the GUI handle it
        //emit errorEvent(C::gettext("Could not save the backup file"));
        return "";
    }
}


QString DeltaHandler::getUrlToExport()
{
    return m_tempExportPath;
}


void DeltaHandler::removeTempExportFile()
{
    QString fileToRemove(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/" + m_tempExportPath);
    bool success = QFile::remove(fileToRemove);

    if (success) {
        // In case of account backups, the core appends a sequential
        // number to the files to make sure that each backup has a
        // unique file name. For each new backup, the already present
        // files are used to determine the number. As the backup files
        // are deleted right after exporting via ContentHub, the core
        // would choose the same number and thus file name for each
        // backup file. To avoid this, a dummy file is created with the
        // same file name as the backup file that has just been removed.
        //
        // TODO: This only works if the app is not closed at some time
        // because closing removes the cache dir.
        //
        // If the app is closed, the backup file in the cache will
        // have the same name as a previously exported one, but 
        // in the folder chosen by the user the file will then be
        // named ....._1.tar

        QFile dummyFile(fileToRemove);
        if (!dummyFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            qDebug() << "DeltaHandler::removeTempExportFile(): Could not open dummy file to represent the removed backup file";
        } else {
            QTextStream out(&dummyFile);
            out << "dummy file" << '\n';
            dummyFile.flush();
            dummyFile.close();
        }
    } else {
        qDebug() << "DeltaHandler::removeTempExportFile(): Error: Could not remove backup file " << fileToRemove;
        emit errorEvent(C::gettext("Failed to remove the temporary copy of the backup export in the cache directory"));
    }
}


bool DeltaHandler::isExistingChat(uint32_t chatID)
{
    for (size_t i = 0; i < m_chatlistVector.size(); ++i) {
        if (m_chatlistVector[i] == chatID) {
           return true; 
        }
    }
    return false;
}


bool DeltaHandler::chatIsContactRequest()
{
    return m_chatmodel->chatIsContactRequest();
}

/* ========================================================
* =================== Profile editing ====================
* ======================================================== */

QString DeltaHandler::getCurrentSignature()
{
    char* tempText = dc_get_config(currentContext, "selfstatus");
    QString tempQString = tempText;
    dc_str_unref(tempText);
    return tempQString;
}


void DeltaHandler::startProfileEdit()
{
    m_changedProfileValues.clear();
}


void DeltaHandler::setProfileValue(QString key, QString newValue)
{
    m_changedProfileValues[key] = newValue;
    if ("selfavatar" == key && newValue != "") {
        // newValue might be prepended by "file://" or "qrc:",
        // remove it
        QString tempQString = newValue;
        if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
            newValue.remove(0, 7);
        }

        tempQString = newValue;
        if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
            newValue.remove(0, 4);
        }

        newValue.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length());
        emit newTempProfilePic(newValue);
    }
}


void DeltaHandler::finalizeProfileEdit()
{
    QHashIterator<QString, QString> i(m_changedProfileValues);

    while (i.hasNext()) {
        i.next();
        setCurrentConfig(i.key(), i.value());
    }
}
/* ================ End Profile editing ================== */


/* ========================================================
 * ============== Other Profile editing ===================
 * ======================================================== */

QString DeltaHandler::getOtherDisplayname(uint32_t userID)
{
    dc_contact_t* tempContact = dc_get_contact(currentContext, userID);
    QString retval {""};
    char* tempText {nullptr};

    if (tempContact) {
        tempText = dc_contact_get_display_name(tempContact);
        retval = tempText;
        dc_contact_unref(tempContact);
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    return retval;
}

QString DeltaHandler::getOtherProfilePic(uint32_t userID)
{
    dc_contact_t* tempContact = dc_get_contact(currentContext, userID);
    QString retval {""};
    char* tempText {nullptr};

    if (tempContact) {
        tempText = dc_contact_get_profile_image(tempContact);

        if (tempText) {
            retval = tempText;
            
            // For some reason, the QML part doesn't like the path
            // as given by dc_contact_get_profile_image.
            // The file is located in the config dir, so we remove the
            // top level of the config dir part and put it back
            // together in QML again.
            // No idea what the difference is - should be exactly the same.
            retval.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
            dc_str_unref(tempText);
        }
        dc_contact_unref(tempContact);
    }

    return retval;
}


QString DeltaHandler::getOtherInitial(uint32_t userID)
{
    dc_contact_t* tempContact = dc_get_contact(currentContext, userID);
    QString retval {""};

    if (tempContact) {
        char* tempText = dc_contact_get_display_name(tempContact);

        if (tempText) {
            retval = tempText;
            dc_str_unref(tempText);
        }
        dc_contact_unref(tempContact);
    }

    if (retval == "") {
        retval = "#";
    } else {
        retval = QString(retval.at(0)).toUpper();
    }

    return retval;
}


bool DeltaHandler::showContactCheckmark(uint32_t userID)
{
    uint32_t tmpChatID = dc_get_chat_id_by_contact_id(currentContext, userID);
    bool retval {false};

    if (tmpChatID != 0) {
        dc_chat_t* tmpChat = dc_get_chat(currentContext, tmpChatID);
        retval = (1 == dc_chat_is_protected(tmpChat));
        dc_chat_unref(tmpChat);
        
    } else {
        dc_contact_t* tmpContact = dc_get_contact(currentContext, userID);
        retval = (2 == dc_contact_is_verified(tmpContact));
        dc_contact_unref(tmpContact);
    }

    return retval;
}


QString DeltaHandler::getOtherColor(uint32_t userID)
{
    uint32_t tempColor {0};
    QColor tempQColor;
    QString retval {""};
    dc_contact_t* tempContact = dc_get_contact(currentContext, userID);

    if (tempContact) {
        tempColor = dc_contact_get_color(tempContact);
        tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
        retval = QString(tempQColor.name());
        dc_contact_unref(tempContact);
    }

    return retval;
}


QString DeltaHandler::getOtherAddress(uint32_t userID)
{
    dc_contact_t* tempContact = dc_get_contact(currentContext, userID);
    QString retval {""};
    char* tempText {nullptr};

    if (tempContact) {
        tempText = dc_contact_get_addr(tempContact);
        retval = tempText;
        dc_contact_unref(tempContact);
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    return retval;
}


QString DeltaHandler::getOtherStatus(uint32_t userID)
{
    dc_contact_t* tempContact = dc_get_contact(currentContext, userID);
    QString retval {""};
    char* tempText {nullptr};

    if (tempContact) {
        tempText = dc_contact_get_status(tempContact);
        retval = tempText;
        dc_contact_unref(tempContact);
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    return retval;
}


QString DeltaHandler::getOtherVerifiedBy(uint32_t userID)
{
    dc_contact_t* tempContact = dc_get_contact(currentContext, userID);
    QString retval {""};
    char* tempText {nullptr};

    if (tempContact) {
        uint32_t contactID = dc_contact_get_verifier_id(tempContact);

        if (DC_CONTACT_ID_SELF == contactID) {
            retval = "me"; 
        } else if (0 != contactID) {
            dc_contact_t* verifierContact = dc_get_contact(currentContext, contactID);

            if (verifierContact) {
                tempText = dc_contact_get_name_n_addr(verifierContact);
                retval = tempText;
                dc_contact_unref(verifierContact);
            }
        }

        dc_contact_unref(tempContact);
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    return retval;
}


QString DeltaHandler::getOtherLastSeen(uint32_t userID)
{
    dc_contact_t* tempContact = dc_get_contact(currentContext, userID);
    QString retval {""};
    uint64_t timestampSecs {0};

    if (tempContact) {
        timestampSecs = dc_contact_get_last_seen(tempContact);
        dc_contact_unref(tempContact);
        
        retval = timeToString(timestampSecs);
    }

    return retval;
}


bool DeltaHandler::otherContactIsDevice(uint32_t userID)
{
    return userID == DC_CONTACT_ID_DEVICE;
}


// Sets the username to newName and returns it.
// Passing empty string will reset the username back to the
// one received by the network and returns it, if it exists.
QString DeltaHandler::setOtherUsername(uint32_t userID, QString newName)
{
    uint32_t tempID;
    QString retval;

    if (newName != "") {
        tempID = dc_create_contact(currentContext, newName.toUtf8().constData(), getOtherAddress(userID).toUtf8().constData());
        retval = newName;
    } else {
        tempID = dc_create_contact(currentContext, NULL, getOtherAddress(userID).toUtf8().constData());
        
        dc_contact_t* tempContact = dc_get_contact(currentContext, userID);
        char* tempText {nullptr};

        if (tempContact) {
            tempText = dc_contact_get_auth_name(tempContact);
            retval = tempText;
            dc_contact_unref(tempContact);
        }

        if (tempText) {
            dc_str_unref(tempText);
        }
    }

    emit chatDataChanged();

    return retval;
}

/* ============== End Other Profile editing =============== */

/* ========================================================
 * ============== New Group / Editing Group ===============
 * ======================================================== */


void DeltaHandler::startCreateGroup()
{
    creatingNewGroup = true;
    editingVerifiedGroup = false;

    m_groupmembermodel = new GroupMemberModel();
    m_groupmembermodel->setConfig(currentContext, true);

    m_contactsmodel->setVerifiedOnly(false);
    m_contactsmodel->resetNewMemberList();
    m_contactsmodel->setMembersAlreadyInGroup(m_groupmembermodel->getMembersAlreadyInGroup());
    
    bool connectSuccess = connect(m_contactsmodel, SIGNAL(addContactToGroup(uint32_t)), m_groupmembermodel, SLOT(addMember(uint32_t)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::startCreateGroup(): Could not connect signal addContactToGroup to slot addMember");
    }
}


void DeltaHandler::startEditGroup(int myindex)
{
    creatingNewGroup = false;

    // will set up the currently active chat
    // (i.e., the one in currentChatID) if -1 is
    // passed
    if (-1 == myindex) {
        m_tempGroupChatID = currentChatID;
    } else {
        m_tempGroupChatID = m_chatlistVector[myindex];
    }

    m_groupmembermodel = new GroupMemberModel();
    m_groupmembermodel->setConfig(currentContext, false, m_tempGroupChatID);

    dc_chat_t* tempChat = dc_get_chat(currentContext, m_tempGroupChatID);
    if (1 == dc_chat_is_protected(tempChat)) {
        m_contactsmodel->setVerifiedOnly(true);
        editingVerifiedGroup = true;
    } else {
        m_contactsmodel->setVerifiedOnly(false);
        editingVerifiedGroup = false;
    }
    dc_chat_unref(tempChat);

    m_contactsmodel->resetNewMemberList();
    m_contactsmodel->setMembersAlreadyInGroup(m_groupmembermodel->getMembersAlreadyInGroup());
    
    bool connectSuccess = connect(m_contactsmodel, SIGNAL(addContactToGroup(uint32_t)), m_groupmembermodel, SLOT(addMember(uint32_t)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::startCreateGroup(): Could not connect signal addContactToGroup to slot addMember");
    }
}


void DeltaHandler::momentaryChatStartEditGroup()
{
    creatingNewGroup = false;

    m_tempGroupChatID = m_momentaryChatId;

    m_groupmembermodel = new GroupMemberModel();
    m_groupmembermodel->setConfig(currentContext, false, m_tempGroupChatID);

    dc_chat_t* tempChat = dc_get_chat(currentContext, m_tempGroupChatID);
    if (1 == dc_chat_is_protected(tempChat)) {
        m_contactsmodel->setVerifiedOnly(true);
        editingVerifiedGroup = true;
    } else {
        m_contactsmodel->setVerifiedOnly(false);
        editingVerifiedGroup = false;
    }
    dc_chat_unref(tempChat);

    m_contactsmodel->resetNewMemberList();
    m_contactsmodel->setMembersAlreadyInGroup(m_groupmembermodel->getMembersAlreadyInGroup());
    
    bool connectSuccess = connect(m_contactsmodel, SIGNAL(addContactToGroup(uint32_t)), m_groupmembermodel, SLOT(addMember(uint32_t)));
    if (!connectSuccess) {
        qFatal("DeltaHandler::startCreateGroup(): Could not connect signal addContactToGroup to slot addMember");
    }
}


QString DeltaHandler::getTempGroupPic()
{
    if (creatingNewGroup) {
        return QString();
    }

    dc_chat_t* tempChat = dc_get_chat(currentContext, m_tempGroupChatID);
    
    char* tempText = dc_chat_get_profile_image(tempChat);

    QString tempQString = tempText;
    tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length() + 1);

    dc_str_unref(tempText);
    dc_chat_unref(tempChat);

    return tempQString;
}


QString DeltaHandler::getTempGroupName()
{
    if (creatingNewGroup) {
        return QString();
    }

    dc_chat_t* tempChat = dc_get_chat(currentContext, m_tempGroupChatID);
    
    char* tempText = dc_chat_get_name(tempChat);

    QString tempQString = tempText;

    dc_str_unref(tempText);
    dc_chat_unref(tempChat);

    return tempQString;
}


bool DeltaHandler::tempGroupIsVerified()
{
    return editingVerifiedGroup;
}


void DeltaHandler::setGroupPic(QString filepath)
{
    // filePath might be prepended by "file://" or "qrc:",
    // remove it
    QString tempQString = filepath;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        filepath.remove(0, 7);
    }

    tempQString = filepath;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        filepath.remove(0, 4);
    }

    filepath.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length() + 1);
    emit newChatPic(filepath);
}


QString DeltaHandler::getTempGroupQrSvg()
{
    QString retval(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/qrGroupInvite.svg");
    std::ofstream outfile(retval.toStdString());
    char* tempImage = dc_get_securejoin_qr_svg(currentContext, m_tempGroupChatID);
    outfile << tempImage;
    outfile.close();
    dc_str_unref(tempImage);

    retval.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length());
    return retval;
}


void DeltaHandler::prepareBackupProvider()
{
    if (m_backupProvider) {
        qDebug() << "DeltaHandler::prepareBackupProvider(): m_backupProvider is unexpectedly set, deleting it";
        dc_backup_provider_unref(m_backupProvider);
    }

    m_backupProvider = dc_backup_provider_new(currentContext);

    if (m_backupProvider) {
        emit backupProviderCreationSuccess();

        // imexProgress should already be at 400 (it starts with dc_backup_provider_new()), but 
        // we connect only now because due to the blocking nature of dc_backup_provider_new(),
        // we won't receive any signals in time anyway. TODO: call it in a separate thread
        //
        // imexProgress may be connected to imexBackupExportProgressReceiver or imexBackupImportProgressReceiver
        // disconnect it. Also disconnect it from imexBackupProviderProgressReceiver, too, to avoid being
        // connected twice.
        //
        // TODO check return values?
        // TODO disconnect the slots directly after completion of the corresponding actions
        bool disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));
        disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
        disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupProviderProgressReceiver(int)));

        bool connectSuccess = connect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupProviderProgressReceiver(int)));

        return;
    } else {
        // creating the backup provider failed
        char* tempText = dc_get_last_error(currentContext);
        QString tempQString = tempText;
        dc_str_unref(tempText);
        emit backupProviderCreationFailed(tempQString);
        return;
    }
}


QString DeltaHandler::getBackupProviderSvg()
{
    QString retval(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/qrBackup.svg");
    std::ofstream outfile(retval.toStdString());
    char* tempImage = dc_backup_provider_get_qr_svg(m_backupProvider);
    outfile << tempImage;
    outfile.close();
    dc_str_unref(tempImage);

    retval.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length());
    return retval;
}


QString DeltaHandler::getBackupProviderTxt()
{
    if (!m_backupProvider) {
        return QString();
    }

    char* tempText = dc_backup_provider_get_qr(m_backupProvider);
    QString retval(tempText);
    dc_str_unref(tempText);
    return retval;
}


void DeltaHandler::imexBackupProviderProgressReceiver(int perMill)
{
    emit imexEventReceived(perMill);
    if (perMill == 0 || perMill == 1000) {
        dc_backup_provider_unref(m_backupProvider);
        m_backupProvider = nullptr;
        bool disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupProviderProgressReceiver(int)));
    }
}


void DeltaHandler::cancelBackupProvider()
{
    // Do not remove this disconnect, and keep it at the
    // first line here. Otherwise, dc_stop_ongoing_process() will
    // start a signal cascade (via perMill == 0) that will
    // trigger an unwanted popup in the UI
    bool disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupProviderProgressReceiver(int)));
    dc_stop_ongoing_process(currentContext);
    if (m_backupProvider) {
        dc_backup_provider_unref(m_backupProvider);
        m_backupProvider = nullptr;
    }
}


void DeltaHandler::finalizeGroupEdit(QString groupName, QString imagePath)
{

    if (creatingNewGroup) {
        if (m_groupmembermodel->allContactsAreVerified()) {
            m_tempGroupChatID = dc_create_group_chat(currentContext, 1, groupName.toUtf8().constData());
        } else {
            m_tempGroupChatID = dc_create_group_chat(currentContext, 0, groupName.toUtf8().constData());
        }

        if ("" != imagePath) {
            imagePath.remove(0, 7);
            dc_set_chat_profile_image(currentContext, m_tempGroupChatID, imagePath.toUtf8().constData());
        }
    } else {
        QString tempQString = getTempGroupName();
        if (groupName != tempQString) {
            dc_set_chat_name(currentContext, m_tempGroupChatID, groupName.toUtf8().constData());
            emit chatDataChanged();
        }

        // if the group image has been modified, imagePath will be
        // located in the CacheLocation, whereas it will be in the
        // AppConfigLocation when unmodified. Only set it if it has been
        // modified. Check by assuming AppConfigLocation and compare it
        // to the existing group image
        tempQString = imagePath;
        tempQString.remove(0, 7);
        tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length() + 1);

        if (tempQString != getTempGroupPic()) {
            if ("" == imagePath) {
                dc_set_chat_profile_image(currentContext, m_tempGroupChatID, NULL);
            } else {
                imagePath.remove(0, 7);
                dc_set_chat_profile_image(currentContext, m_tempGroupChatID, imagePath.toUtf8().constData());
            }
        }
    }


    dc_array_t* tempContactsArray = dc_get_chat_contacts(currentContext, m_tempGroupChatID);
    size_t numberOfPresentContacts = dc_array_get_cnt(tempContactsArray);

    std::vector<uint32_t> finalMemberList = m_groupmembermodel->getMembersAlreadyInGroup();

    // adding all contactIDs to the group that are in the list
    // from m_groupmembermodel, but not in the array received
    // from currentContext
    for (size_t i = 0; i < finalMemberList.size(); ++i) {
        bool hasToBeAdded = true;
        for (size_t j = 0; j < numberOfPresentContacts; ++j) {
            if (finalMemberList[i] == dc_array_get_id(tempContactsArray, j)) {
                hasToBeAdded = false;
                break;
            }
        }
        if (hasToBeAdded) {
            dc_add_contact_to_chat(currentContext, m_tempGroupChatID, finalMemberList[i]);
        }
    }

    // removing all contactIDs from the group that are in
    // the array received from currentContext, but not
    // in the list from m_groupmembermodel
    for (size_t i = 0; i < numberOfPresentContacts; ++i) {
        bool hasToBeRemoved = true;
        for (size_t j = 0; j < finalMemberList.size(); ++j) {
            if (dc_array_get_id(tempContactsArray, i) == finalMemberList[j]) {
                hasToBeRemoved = false;
                break;
            }
        }
        if (hasToBeRemoved) {
            dc_remove_contact_from_chat(currentContext, m_tempGroupChatID, dc_array_get_id(tempContactsArray, i));
        }
    }

    dc_array_unref(tempContactsArray);
    delete m_groupmembermodel;
    m_contactsmodel->setVerifiedOnly(false);
}


void DeltaHandler::momentaryChatLeaveGroup()
{
    dc_remove_contact_from_chat(currentContext, m_momentaryChatId, DC_CONTACT_ID_SELF);
}


void DeltaHandler::stopCreateOrEditGroup()
{
    delete m_groupmembermodel;
    m_contactsmodel->setVerifiedOnly(false);
}


void DeltaHandler::prepareContactsmodelForGroupMemberAddition()
{
    m_contactsmodel->setMembersAlreadyInGroup(m_groupmembermodel->getMembersAlreadyInGroup());
}


void DeltaHandler::continueQrCodeAction()
{
    switch (m_qrTempState) {
        case DT_QR_ASK_VERIFYCONTACT:
            currentChatID = dc_join_securejoin(currentContext, m_qrTempText.toUtf8().constData());
            // dc_join_securejoin() returns 0 on error, so don't call
            // openChat() in this case
            if (currentChatID != 0) {
                openChat();
            }
            break;
        case DT_QR_ASK_VERIFYGROUP:
            currentChatID = dc_join_securejoin(currentContext, m_qrTempText.toUtf8().constData());
            // dc_join_securejoin() returns 0 on error, so don't call
            // openChat() in this case
            if (currentChatID != 0) {
                openChat();
            }
            break;
        case DT_QR_FPR_OK:
            // TODO: what to do here?
            // => nothing for the moment because no translated strings exist
            // for the action suggested in the documentation
            //currentChatID = dc_create_chat_by_contact_id(currentContext, m_qrTempContactID);
            //openChat();
            break;
        case DT_QR_FPR_MISMATCH:
            // nothing to do here
            break;
        case DT_QR_FPR_WITHOUT_ADDR:
            // nothing to do here
            break;
        case DT_QR_ACCOUNT:
            prepareTempContextConfig();
            if (1 == dc_set_config_from_qr(tempContext, m_qrTempText.toUtf8().constData())) {
                emit finishedSetConfigFromQr(true);
            } else {
                // dc_set_config_from_qr() exited with an error
                // TODO: what now? should the account that was created
                // via prepareTempContextConfig() been deleted? Currently,
                // it will stay. See also the comment in QrShowScan.qml:
                // If dc_set_config_from_qr() succeeds, but login fails, it's
                // the same.
                emit finishedSetConfigFromQr(false);
            }
            break;
        case DT_QR_BACKUP:
            prepareQrBackupImport();
            break;
        case DT_QR_WEBRTC_INSTANCE:
            // TODO not implemented yet
            break;
        case DT_QR_ADDR:
            // TODO
            break;
        case DT_QR_TEXT:
            // nothing to do here
            break;
        case DT_QR_URL:
            // nothing to do here
            break;
        case DT_QR_ERROR:
            // nothing to do here
            break;
        case DT_QR_WITHDRAW_VERIFYCONTACT:
            dc_set_config_from_qr(currentContext, m_qrTempText.toUtf8().constData());
            break;
        case DT_QR_WITHDRAW_VERIFYGROUP:
            dc_set_config_from_qr(currentContext, m_qrTempText.toUtf8().constData());
            break;
        case DT_QR_REVIVE_VERIFYCONTACT:
            dc_set_config_from_qr(currentContext, m_qrTempText.toUtf8().constData());
            break;
        case DT_QR_REVIVE_VERIFYGROUP:
            dc_set_config_from_qr(currentContext, m_qrTempText.toUtf8().constData());
            break;
        case DT_QR_LOGIN:
            prepareTempContextConfig();
            if (1 == dc_set_config_from_qr(tempContext, m_qrTempText.toUtf8().constData())) {
                emit finishedSetConfigFromQr(true);
            } else {
                // dc_set_config_from_qr() exited with an error
                // TODO: what now? should the account that was created
                // via prepareTempContextConfig() been deleted? Currently,
                // it will stay. See also the comment in QrShowScan.qml:
                // If dc_set_config_from_qr() succeeds, but login fails, it's
                // the same.
                emit finishedSetConfigFromQr(false);
            }
            break;
        default:
            // nothing to do
            break;
    }
}


QString DeltaHandler::getQrInviteSvg()
{
    QString retval(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/qrInvite.svg");
    std::ofstream outfile(retval.toStdString());
    char* tempImage = dc_get_securejoin_qr_svg(currentContext, 0);
    outfile << tempImage;
    outfile.close();
    dc_str_unref(tempImage);

    retval.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length());
    return retval;
}


QString DeltaHandler::getQrInviteTxt()
{
    char* tempText = dc_get_securejoin_qr(currentContext, 0);
    QString retval(tempText);
    dc_str_unref(tempText);
    return retval;
}


QString DeltaHandler::getQrInviteLink()
{
    QString qrstring = getQrInviteTxt();
    // qrstring is now something like OPENPGP4FPR:..., remove the
    // beginning until and including the ":"
    qrstring.remove(0, qrstring.indexOf(":") + 1);

    // remove the first occurrence of "#" by "&"
    qrstring.replace(qrstring.indexOf("#"), 1, "&");

    QString retval = "http://i.delta.chat/#" + qrstring;
    return retval;
}


QString DeltaHandler::getQrContactEmail()
{
    dc_contact_t* tempContact = dc_get_contact(currentContext, m_qrTempContactID);
    QString retval;
    if (tempContact) {
        char* tempText = dc_contact_get_addr(tempContact);
        retval = tempText;
        if (tempText) {
            dc_str_unref(tempText);
        }
        dc_contact_unref(tempContact);
    } else {
        retval = "";
    }

    return retval;
}


QString DeltaHandler::getQrTextOne()
{
    return m_qrTempLotTextOne;
}


int DeltaHandler::evaluateQrCode(QString clipboardData)
{
    m_qrTempText = clipboardData;

    dc_lot_t* tempLot;
    uint32_t accID;

    // Needed if there's no account yet, as dc_check_qr requires
    // a context to be passed.
    dc_context_t* helperContext {nullptr};

    if (currentContext) {
        tempLot = dc_check_qr(currentContext, m_qrTempText.toUtf8().constData());
    } else {
        accID = dc_accounts_add_account(allAccounts);
        // The created account will be removed at the end of the function.
        // TODO: check whether this situation can be handled via tempContext
        // (currently probably not because the logic from previous versions of
        // DeltaTouch assumes that if tempContext is set, we're in the middle
        // of configuring an account by manually setting username, password etc.,
        // see prepareTempContextConfig())
        helperContext = dc_accounts_get_account(allAccounts, accID);
        tempLot = dc_check_qr(helperContext, m_qrTempText.toUtf8().constData());
    }

    int lotState = dc_lot_get_state(tempLot);

    switch (lotState) {
        case DC_QR_ASK_VERIFYCONTACT:
            m_qrTempState = QrState::DT_QR_ASK_VERIFYCONTACT;
            break;
        case DC_QR_ASK_VERIFYGROUP:
            m_qrTempState = QrState::DT_QR_ASK_VERIFYGROUP;
            break;
        case DC_QR_FPR_OK:
            m_qrTempState = QrState::DT_QR_FPR_OK;
            break;
        case DC_QR_FPR_MISMATCH:
            m_qrTempState = QrState::DT_QR_FPR_MISMATCH;
            break;
        case DC_QR_FPR_WITHOUT_ADDR:
            m_qrTempState = QrState::DT_QR_FPR_WITHOUT_ADDR;
            break;
        case DC_QR_ACCOUNT:
            m_qrTempState = QrState::DT_QR_ACCOUNT;
            break;
        case DC_QR_BACKUP:
            m_qrTempState = QrState::DT_QR_BACKUP;
            break;
        case DC_QR_WEBRTC_INSTANCE:
            m_qrTempState = QrState::DT_QR_WEBRTC_INSTANCE;
            break;
        case DC_QR_ADDR:
            m_qrTempState = QrState::DT_QR_ADDR;
            break;
        case DC_QR_TEXT:
            m_qrTempState = QrState::DT_QR_TEXT;
            break;
        case DC_QR_URL:
            m_qrTempState = QrState::DT_QR_URL;
            break;
        case DC_QR_ERROR:
            m_qrTempState = QrState::DT_QR_ERROR;
            break;
        case DC_QR_WITHDRAW_VERIFYCONTACT:
            m_qrTempState = QrState::DT_QR_WITHDRAW_VERIFYCONTACT;
            break;
        case DC_QR_WITHDRAW_VERIFYGROUP:
            m_qrTempState = QrState::DT_QR_WITHDRAW_VERIFYGROUP;
            break;
        case DC_QR_REVIVE_VERIFYCONTACT:
            m_qrTempState = QrState::DT_QR_REVIVE_VERIFYCONTACT;
            break;
        case DC_QR_REVIVE_VERIFYGROUP:
            m_qrTempState = QrState::DT_QR_REVIVE_VERIFYGROUP;
            break;
        case DC_QR_LOGIN:
            m_qrTempState = QrState::DT_QR_LOGIN;
            break;
        default:
            m_qrTempState = QrState::DT_UNKNOWN;
    }

    char* tempText = dc_lot_get_text1(tempLot);
    if (tempText) {
        m_qrTempLotTextOne = tempText;
        dc_str_unref(tempText);
    }

    m_qrTempContactID = dc_lot_get_id(tempLot);
    
    dc_lot_unref(tempLot);

    if (helperContext) {
        dc_context_unref(helperContext);
        dc_accounts_remove_account(allAccounts, accID);
    }

    return m_qrTempState;
}


void DeltaHandler::prepareQrBackupImport()
{
    if (tempContext) {
        qDebug() << "DeltaHandler::prepareQrBackupImport: tempContext is unexpectedly set, will now be unref'd";
        dc_context_unref(tempContext);
        tempContext = nullptr;
    }

    uint32_t accID;

    if (m_encryptedDatabase) {
        if (m_databasePassphrase == "") {
            qDebug() << "DeltaHandler::prepareQrBackupImport(): ERROR: Plaintext key for database encryption is not present, cannot create account.";
            return;
        }

        accID = dc_accounts_add_closed_account(allAccounts);
        if (0 == accID) {
            qDebug() << "DeltaHandler::prepareQrBackupImport: Could not create new account.";
            // TODO: add boolean parameter to readyForQrBackupImport(), emit the signal
            // here with false and handle it accordingly in the GUI?
            return;
        }
        tempContext = dc_accounts_get_account(allAccounts, accID);
        dc_context_open(tempContext, m_databasePassphrase.toUtf8().constData());

    } else {
        accID = dc_accounts_add_account(allAccounts);
        if (0 == accID) {
            qDebug() << "DeltaHandler::prepareQrBackupImport: Could not create new account.";
            // TODO: add boolean parameter to readyForQrBackupImport(), emit the signal
            // here with false and handle it accordingly in the GUI?
            return;
        }
        tempContext = dc_accounts_get_account(allAccounts, accID);
    }
    
    emit readyForQrBackupImport();
}


void DeltaHandler::startQrBackupImport()
{
    // imexProgress may be connected to imexBackupExportProgressReceiver or imexBackupProviderProgressReceiver
    // disconnect it. Also disconnect it from imexBackupImportProgressReceiver, too, to avoid being
    // connected twice.
    //
    // TODO check return values?
    bool disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));
    disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupProviderProgressReceiver(int)));
    disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
 
    // ... and connect it to imexBackupImportProgressReceiver
    connect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));

    m_networkingIsAllowed = false;
    // not emitting signal, but stopping io directly
    stop_io();

    // Construct the request string:
    // first the parameter part
    QString paramString;
    paramString.setNum(dc_get_id(tempContext));

    paramString.append(", \"");

    paramString.append(m_qrTempText.toUtf8().constData());

    paramString.append("\"");

    // then the complete request
    QString requestString = constructJsonrpcRequestString("get_backup", paramString);

    sendJsonrpcRequest(requestString);
}


void DeltaHandler::cancelQrImport()
{
    dc_stop_ongoing_process(tempContext);
    // TODO: check whether this is enough - this would be
    // the case if an imex progress event will be sent with
    // progress = 0, then imexBackupImportProgressReceiver will
    // take care of unreffing tempContext and deleting the account.
    // Otherwise, this would have to be done here.
}


bool DeltaHandler::prepareQrDecoder()
{
    if (m_qr) {
        quirc_destroy(m_qr);
    }

    m_qr = quirc_new();
    if (!m_qr) {
        qDebug() << "DeltaHandler:: ERROR: Failed to allocate memory for quirc_new()";
        return false;
    }

    return true;
}


void DeltaHandler::evaluateQrImage(QImage image, bool emitFailureSignal)
{

    if (!m_qr) {
        qDebug() << "DeltaHandler::evaluateQrImage: m_qr is unexpectedly null";
        if (emitFailureSignal) {
            emit qrDecodingFailed(QString(C::gettext("Error")));
        }
        return;
    }

    QImage tempImage = image.convertToFormat(QImage::Format_Grayscale8);

    int iwidth = tempImage.width();
    int iheight = tempImage.height();

    // Usage of libquirc mostly according to the README in the
    // quirc repo
    if (quirc_resize(m_qr, iwidth, iheight) < 0) {
        qDebug() << "DeltaHandler::evaluateQrImage: ERROR: Failed to allocate video memory for quirc_resize()";
        if (emitFailureSignal) {
            emit qrDecodingFailed(QString("Failed to allocate video memory"));
        }
        return;
    }

    uint8_t *imbuffer;
    int w, h;

    imbuffer = quirc_begin(m_qr, &w, &h);

    uint8_t* idatapointer;

    for (int i = 0; i < h; ++i) {
        // better to use scanLine() than bits()
        idatapointer = tempImage.scanLine(i);

        for (int j = 0; j < w; ++j) {
            *imbuffer = *(idatapointer + j);
            ++imbuffer;
        }
    }

    quirc_end(m_qr);

    int num_codes;

    num_codes = quirc_count(m_qr);

    if (num_codes > 0) {
        if (num_codes > 1) {
            qDebug() << "DeltaHandler::evaluateQrImage: Multiple QR codes found, using the first one";
        }

        struct quirc_code code;
        struct quirc_data data;
        quirc_decode_error_t err;

        quirc_extract(m_qr, 0, &code);

        /* Decoding stage */
        err = quirc_decode(&code, &data);
        if (err) {
            printf("DeltaHandler::evaluateQrImage: DECODE FAILED: %s\n", quirc_strerror(err));
            if (emitFailureSignal) {
                emit qrDecodingFailed(QString("Decode failed: ") + quirc_strerror(err));
            }
        }
        else {
            printf("DeltaHandler::evaluateQrImage: Data: %s\n", data.payload);
            QString tempQString{""};
            // adding it char by char as I couldn't figure out how to
            // pass data.payload as argument to a QString constructor
            // as it is not const. Embarassing, I know. If you know how
            // this should be done, please let me know.
            for (int k = 0; k < data.payload_len; ++k) {
                tempQString += data.payload[k];
            }
            emit qrDecoded(tempQString);
        }
    }
    
    if (num_codes == 0) {
        qDebug() << "DeltaHandler::evaluateQrImage: no QR code found";
        if (emitFailureSignal) {
            emit qrDecodingFailed(QString(C::gettext("QR code could not be decoded")));
        }
    }
}


void DeltaHandler::loadQrImage(QString filepath)
{
    // filepath might be prepended by "file://" or "qrc:",
    // remove it
    QString tempQString = filepath;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        filepath.remove(0, 7);
    }

    tempQString = filepath;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        filepath.remove(0, 4);
    }

    QImage image(filepath);

    if (image.isNull()) {
        emit qrDecodingFailed(QString(C::gettext("QR code could not be decoded")));
        return;
    }
    evaluateQrImage(image, true);
}


void DeltaHandler::deleteQrDecoder()
{
    if (m_qr) {
        quirc_destroy(m_qr);
        m_qr = nullptr;
    }
}


bool DeltaHandler::startAudioRecording(int recordingQuality)
{
    m_audioRecorder = new QAudioRecorder;
    QAudioEncoderSettings audioSettings;

//    // To see the list of supported codecs and containers
//    QStringList codeclist = m_audioRecorder->supportedAudioCodecs();
//    for (int i = 0; i < codeclist.size(); ++i) {
//        qDebug() << "codec " << i << ": " << codeclist.at(i);
//    }
//
//    QStringList containerlist = m_audioRecorder->supportedContainers();
//    for (int i = 0; i < containerlist.size(); ++i) {
//        qDebug() << "container " << i << ": " << containerlist.at(i);
//    }

    audioSettings.setCodec("audio/x-opus");
    audioSettings.setEncodingMode(QMultimedia::AverageBitRateEncoding);
    switch (recordingQuality) {
        case VoiceMessageQuality::LowRecordingQuality:
            audioSettings.setBitRate(8000);
            break;
        case VoiceMessageQuality::BalancedRecordingQuality:
            audioSettings.setBitRate(20000);
            break;
        case VoiceMessageQuality::HighRecordingQuality:
            audioSettings.setBitRate(40000);
            break;
        default:
            audioSettings.setBitRate(20000);
            break;
    }
    
    m_audioRecorder->setEncodingSettings(audioSettings);
    m_audioRecorder->setContainerFormat("audio/ogg");

    QString outfile("/voice_message.opus");
    outfile.prepend(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    m_audioRecorder->setOutputLocation(QUrl(outfile));

    m_audioRecorder->record();
    return true;
}


void DeltaHandler::stopAudioRecording()
{
    m_audioRecorder->stop();

    QString voicefile("/voice_message.opus");
    voicefile.prepend(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));

    m_chatmodel->setAttachment(voicefile, MsgViewType::VoiceType);
}


void DeltaHandler::dismissAudioRecording()
{
    if (m_audioRecorder) {
        delete m_audioRecorder;
        m_audioRecorder = nullptr;
    }
    // delete the recording
    QString voicefile("/voice_message.opus");
    voicefile.prepend(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    if (QFile::exists(voicefile)) {
        QFile::remove(voicefile);
    }
}


GroupMemberModel* DeltaHandler::groupmembermodel()
{
    return m_groupmembermodel;
}

/* ============ End New Group / Editing Group ============= */


EmitterThread* DeltaHandler::emitterthread()
{
    return eventThread;
}


NotificationHelper* DeltaHandler::notificationHelper()
{
    return m_notificationHelper;
}



WorkflowDbToEncrypted* DeltaHandler::workflowdbencryption()
{
    if (m_workflowDbEncryption) {
        return m_workflowDbEncryption;
    } else {
        qDebug() << "DeltaHandler::workflowdbencryption(): ERROR: m_workflowDbEncryption is null";
        return nullptr;
    }
}


WorkflowDbToUnencrypted* DeltaHandler::workflowdbdecryption()
{
    if (m_workflowDbDecryption) {
        return m_workflowDbDecryption;
    } else {
        qDebug() << "DeltaHandler::workflowdbdecryption(): ERROR: m_workflowDbDecryption is null";
        return nullptr;
    }
}


void DeltaHandler::updateCurrentChatMessageCount()
{
    for (size_t i = 0; i < m_chatlistVector.size(); ++i) {
        if (m_chatlistVector[i] == currentChatID) {
            QAbstractItemModel::dataChanged(index(i, 0), index(i, 0));
        }
    }
}


void DeltaHandler::chatViewIsClosed(bool gotoQrScanPage)
{
    // stop the queue timer and process the queue as it was
    // created with the opened chat in mind
    if (m_signalQueueTimer->isActive()) {
        m_signalQueueTimer->stop();
        processSignalQueue();
    }

    currentChatIsOpened = false;
    emit chatViewClosed(gotoQrScanPage);
    m_notificationHelper->removeSummaryNotification(m_currentAccID);
}


QString DeltaHandler::getMomentaryChatEncInfo()
{
    char* tempText;
    QString retval;

    dc_array_t* contactsArray = dc_get_chat_contacts(currentContext, m_momentaryChatId);

    uint32_t contactID {0};

    for (size_t i = 0; i < dc_array_get_cnt(contactsArray); ++i) {
        contactID = dc_array_get_id(contactsArray, i);
        if (DC_CONTACT_ID_SELF == contactID) {
            continue;
        }
        tempText = dc_get_contact_encrinfo(currentContext, contactID);
        retval += "\n\n";
        retval += tempText;
        if (tempText) {
            dc_str_unref(tempText);
            tempText = nullptr;
        }
    }
    
    if (contactsArray) {
        dc_array_unref(contactsArray);
    }

    return retval;
}


bool DeltaHandler::momentaryChatIsDeviceTalk()
{
    dc_chat_t* tempChat = dc_get_chat(currentContext, m_momentaryChatId);
    
    bool retval = dc_chat_is_device_talk(tempChat);

    if (tempChat) {
        dc_chat_unref(tempChat);
    }

    return retval;
}


bool DeltaHandler::momentaryChatIsSelfTalk()
{
    dc_chat_t* tempChat = dc_get_chat(currentContext, m_momentaryChatId);
    
    bool retval = dc_chat_is_self_talk(tempChat);

    if (tempChat) {
        dc_chat_unref(tempChat);
    }

    return retval;
}


bool DeltaHandler::chatIsGroup(int myindex)
{
    uint32_t chatID {0};

    // will check for the currently active chat
    // (i.e., the one in currentChatID) if -1 is
    // passed
    if (-1 == myindex) {
        chatID = currentChatID;
    } else {
        chatID = m_chatlistVector[myindex];
    }

    dc_chat_t* tempChat = dc_get_chat(currentContext, chatID);

    bool retval = (dc_chat_get_type(tempChat) == DC_CHAT_TYPE_GROUP);

    if (tempChat) {
        dc_chat_unref(tempChat);
    }

    return retval;
}


bool DeltaHandler::momentaryChatIsGroup()
{
    dc_chat_t* tempChat = dc_get_chat(currentContext, m_momentaryChatId);

    bool retval = (dc_chat_get_type(tempChat) == DC_CHAT_TYPE_GROUP);

    if (tempChat) {
        dc_chat_unref(tempChat);
    }

    return retval;
}


bool DeltaHandler::selfIsInGroup(int myindex)
{
    uint32_t chatID {0};

    // will check for the currently active chat
    // (i.e., the one in currentChatID) if -1 is
    // passed
    if (-1 == myindex) {
        chatID = currentChatID;
    } else {
        chatID = m_chatlistVector[myindex];
    }

    dc_array_t* tempContactsArray = dc_get_chat_contacts(currentContext, chatID);
    
    bool isInGroup = false;

    for (size_t i = 0; i < dc_array_get_cnt(tempContactsArray); ++i) {
        if (DC_CONTACT_ID_SELF == dc_array_get_id(tempContactsArray, i)) {
            isInGroup = true;
            break;
        }
    }

    dc_array_unref(tempContactsArray);

    return isInGroup;
}


bool DeltaHandler::momentaryChatSelfIsInGroup()
{
    dc_array_t* tempContactsArray = dc_get_chat_contacts(currentContext, m_momentaryChatId);
    
    bool isInGroup = false;

    for (size_t i = 0; i < dc_array_get_cnt(tempContactsArray); ++i) {
        if (DC_CONTACT_ID_SELF == dc_array_get_id(tempContactsArray, i)) {
            isInGroup = true;
            break;
        }
    }

    dc_array_unref(tempContactsArray);

    return isInGroup;
}


void DeltaHandler::momentaryChatBlockContact()
{
    dc_block_chat(currentContext, m_momentaryChatId);
    emit chatBlockContactDone();
}


void DeltaHandler::setCoreTranslations()
{
    if (m_coreTranslationsAlreadySet) {
        return;
    }

    // e.g., "de_DE"
    QString langAndCountry = QLocale::system().name();
    qDebug() << "DeltaHandler::setCoreTranslations(): checking locale, found: " << langAndCountry;
    // e.g., "de"
    QString langOnly = langAndCountry;
    langOnly.remove(langOnly.indexOf("_"), langOnly.length() - langOnly.indexOf("_"));


    // e.g., "de_DE.txt" as probably present in assets/coreTranslations
    langAndCountry.append(".txt");
    // if lang_COUNTRY is not present, maybe only lang?
    langOnly.append(".txt");

    langAndCountry.prepend(":assets/coreTranslations/");
    langOnly.prepend(":assets/coreTranslations/");

    QFile coreLangFile;

    // try with lang_COUNTRY first; if not found, try lang
    if (QFile::exists(langAndCountry)) {
        coreLangFile.setFileName(langAndCountry);
        qDebug() << "DeltaHandler::setCoreTranslations(): Found core translation file " << langAndCountry;
    } else if (QFile::exists(langOnly)){
        coreLangFile.setFileName(langOnly);
        qDebug() << "DeltaHandler::setCoreTranslations(): Found core translation file " << langAndCountry;
    } else {
        // no core translation file found, do nothing
        qDebug() << "DeltaHandler::setCoreTranslations(): No file " << langAndCountry << " or " << langOnly << " found, no core translations available";
        return;
    }

    bool mustUnrefCurrentContext {false};

    uint32_t tempAccId;

    if (!currentContext) {
        mustUnrefCurrentContext = true;
        tempAccId = dc_accounts_add_account(allAccounts);
        currentContext = dc_accounts_get_account(allAccounts, tempAccId);
    }

    if (coreLangFile.open(QIODevice::ReadOnly)) {
        QTextStream stream(&coreLangFile);
        QString line;
        QString endOfFile("@end");
        QString lineStart("@line");
        bool firstline {true};

        QString stringName;
        QString stringText;

        // the format of the files containing the core translations
        // is specific to DeltaTouch. An entry starts with @line,
        // followed directly by the string name, followed by a blank,
        // followed by the string text. The string text can consist
        // of several lines; if so, any additional line will just
        // contain the continuation of the string text. Line breaks will
        // be included into the string text. Example for a one-line
        // entry:
        // @linesaved_messages Mensajes guardados
        //
        // Example of a multi-line entry:
        // @linesystemmsg_cannot_decrypt Diese Nachricht kann nicht entschlüsselt werden.
        // 
        // • Es könnte bereits helfen, einfach auf diese Nachricht zu antworten und die/den AbsenderIn zu bitten, die Nachricht erneut zu senden.
        //
        // • Falls Delta Chat oder ein anderes E-Mail-Programm auf diesem oder einem anderen Gerät neu installiert wurde, kann von dort aus eine Autocrypt Setup-Nachricht gesendet werden.
        // @line[...]
        //
        // The last line of the file just contains @end like this:
        // @end

        while (stream.readLineInto(&line)) {
            if (line == endOfFile) {
                // end of file detected
                if (!firstline) {
                    // Before the loop is broken, write out the current line
                    // as stored in stringName and stringText
                    //
                    // The actual call of dc_set_stock_translation() requires
                    // correlation between the DC_STR constants and the string
                    // names (as given in stringsxml_[lang].xml). The code for
                    // this is autogenerated and included via a separate file.
                    // The file contains around 100 if statements like these:
                    //
                    // if (stringName == "chat_no_messages") {
                    //     dc_set_stock_translation(currentContext, DC_STR_NOMESSAGES, stringText.toUtf8().constData());
                    // } else if (stringName == "self") {
                    //     dc_set_stock_translation(currentContext, DC_STR_SELF, stringText.toUtf8().constData());
                    // }
                    // etc.
#include "ifElseSetCoreTranslation.cpp"
                }
                break;
            }
            
            if (line.left(5) == lineStart) {
                if (!firstline) {
                    // write out the previous line first
                    //
                    // for further explanation regarding the import, see
                    // above
#include "ifElseSetCoreTranslation.cpp"
                }
                firstline = false;
                stringName = line;
                stringText = line;
                // construct the string name by removing the text...
                stringName.remove(stringName.indexOf(" "), stringName.length());
                // ..and the "@line"
                stringName.remove(0, 5);
                // constructing the string text by removing "@line" and the string name
                stringText.remove(0, stringText.indexOf(" ") + 1);
            } else {
                // it's not a new entry, but the string text is spread
                // across several lines. Extend stringText by the
                // additional line.
                stringText += "\n";
                stringText += line;
            }
        }
    } else {
        qDebug() << "DeltaHandler::setCoreTranslations(): ERROR: could not open translation file";
    }

    if (mustUnrefCurrentContext) {
        dc_context_unref(currentContext);
        currentContext = nullptr;
        dc_accounts_remove_account(allAccounts, tempAccId);
    }
    m_coreTranslationsAlreadySet = true;
}


void DeltaHandler::openOskViaDbus()
{
    // Wait for 50 millisecs with the execution of
    // the DBus call to show the on-screen keyboard
    // to make sure that the open call will be
    // later than a potential close call (if the
    // focus switched from one TextField to another
    // one, the one that loses focus will call close,
    // while the one that gains focus will call open
    // => open has to come last)
    QTimer::singleShot(50, this, SLOT(internalOpenOskViaDbus()));
}


void DeltaHandler::internalOpenOskViaDbus()
{
    qDebug() << "DeltaHandler::openOskViaDbus()";
    bool param1 = true;
    QDBusMessage message = QDBusMessage::createMethodCall("sm.puri.OSK0", "/sm/puri/OSK0", "sm.puri.OSK0", "SetVisible");
    message << param1;
    m_bus.send(message);
}


void DeltaHandler::closeOskViaDbus()
{
    qDebug() << "DeltaHandler::close()";
    bool param1 = false;
    QDBusMessage message = QDBusMessage::createMethodCall("sm.puri.OSK0", "/sm/puri/OSK0", "sm.puri.OSK0", "SetVisible");
    message << param1;
    m_bus.send(message);
}


int DeltaHandler::getConnectivitySimple()
{
    int retval {-1};

    if (currentContext) {
        retval = dc_get_connectivity(currentContext);
    } 

    // will return -1 if currentContext is nullptr
    return retval;
}


QString DeltaHandler::getConnectivityHtml()
{
    QString retval(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/connectivity.html");
    std::ofstream outfile(retval.toStdString());
    char* tempText = dc_get_connectivity_html(currentContext);
    outfile << tempText;
    outfile.close();

    if (tempText) {
        dc_str_unref(tempText);
    }

    retval.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length() + 1);
    return retval;
}


QString DeltaHandler::saveLog(QString logtext, QString datetime)
{
    // Takes the content of the TextEdit containing the log
    // as taken at datetime, puts it into a file in the cache
    // dir and returns the filename.
    QString snapshotname("/deltatouch-log-");
    snapshotname.append(datetime);
    snapshotname.append(".txt");
    snapshotname.prepend(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));

    QFile logSnapshot(snapshotname);
    if (!logSnapshot.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qDebug() << "DeltaHandler::saveLog(): Could not save current log excerpt to " << snapshotname;
    } else {
        QTextStream out(&logSnapshot);
        out << logtext;
        logSnapshot.flush();
        logSnapshot.close();
    }

    // have to remove the trailing stuff
    snapshotname.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length() + 1);
    return snapshotname;
}


void DeltaHandler::contextSetupTasks()
{
    dc_chatlist_t* tempChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);

    // can't call resetChatlistVector() because in this
    // method, beginResetModel() / endResetModel() are called
    //resetChatlistVector(tempChatlist);
    //
    // Do the reset here:

    size_t count = dc_chatlist_get_cnt(tempChatlist);
    m_chatlistVector.resize(count);

    for (size_t i = 0; i < count ; ++i) {
        m_chatlistVector[i] = dc_chatlist_get_chat_id(tempChatlist, i);
    }

    dc_chatlist_unref(tempChatlist);

    m_currentAccID = dc_get_id(currentContext);
    m_notificationHelper->setCurrentAccId(m_currentAccID);

    m_contactsmodel->updateContext(currentContext);

    dc_array_t* tempArray = dc_get_fresh_msgs(currentContext);

    freshMsgs.resize(dc_array_get_cnt(tempArray));

    for (size_t i = 0; i < freshMsgs.size(); ++i) {
        uint32_t tempMsgID = dc_array_get_id(tempArray, i);
        dc_msg_t* tempMsg = dc_get_msg(currentContext, tempMsgID);
        if (tempMsg) {
            uint32_t tempChatID = dc_msg_get_chat_id(tempMsg);
            std::array<uint32_t, 2> tempStdArr {tempMsgID, tempChatID};
            freshMsgs[i] = tempStdArr;
            dc_msg_unref(tempMsg);
        } else {
            qDebug() << "DeltaHandler::contextSetupTasks(): ERROR obtaining the chat ID for the unread msg ID " << tempMsgID;
            std::array<uint32_t, 2> tempStdArr {tempMsgID, 0};
            freshMsgs[i] = tempStdArr;
        }
    }

    dc_array_unref(tempArray);
}


void DeltaHandler::periodicTimerActions()
{
    // currently the only periodically triggered
    // action is to check for changes in ChatIsMutedRole
    if (m_hasConfiguredAccount) {

        //QVector<int> roleVector;
        //roleVector.append(DeltaHandler::ChatIsMutedRole);

        for (size_t i = 0; i < m_chatlistVector.size(); ++i) {
            //emit dataChanged(index(i, 0), index(i, 0), roleVector);
            emit dataChanged(index(i, 0), index(i, 0));
        }
    }
}


void DeltaHandler::updateChatlistQueryText(QString query)
{
    // need to check if something has changed and exit, if not.
    // Otherwise the app will crash because a click on an item in the
    // list will trigger onDisplayTextChanged, which is connected to
    // this method. At the same time, the click on the item will try
    // to access the index of the list via onClicked, but the list is
    // just about to reset by this method here.
    if (query == m_query) {
        return;
    }

    m_query = query;

    if (m_hasConfiguredAccount) {
        dc_chatlist_t* tempChatlist {nullptr};

        // if the query is empty, need to pass NULL instead of empty string
        if (m_query == "") {
            if (currentChatID == DC_CHAT_ID_ARCHIVED_LINK) {
                tempChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, NULL, 0);
            } else {
                tempChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
            }
        } else {
            if (currentChatID == DC_CHAT_ID_ARCHIVED_LINK) {
                tempChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, m_query.toUtf8().constData(), 0);
            } else {
                tempChatlist = dc_get_chatlist(currentContext, 0, m_query.toUtf8().constData(), 0);
            }
        }

        refreshChatlistVector(tempChatlist);
        dc_chatlist_unref(tempChatlist);
        emit chatlistShowsArchivedOnly(m_showArchivedChats);
    }
}


void DeltaHandler::resetCurrentChatMessageCount()
{
    // removing notifications and removing the msgIDs from
    // the vector freshMsgs
    size_t i = 0;
    size_t endpos = freshMsgs.size();
    while (i < endpos) {
        if (freshMsgs[i][1] == currentChatID) {
            // assemble the tag of the message (see sendDetailedNotification())
            QString accNumberString;
            accNumberString.setNum(m_currentAccID);

            QString chatNumberString;
            chatNumberString.setNum(currentChatID);

            QString msgNumberString;
            msgNumberString.setNum(freshMsgs[i][0]);
            m_notificationHelper->removeNotification(accNumberString + "_" + chatNumberString + "_" + msgNumberString);

            // remove the message from freshMsgs
            std::vector<std::array<uint32_t, 2>>::iterator it;
            it = freshMsgs.begin();
            freshMsgs.erase(it + i);
            --endpos;

        } else {
            // only increase i if no item is removed from freshMsgs
            ++i;
        }
    }

    // If dc_get_fresh_msg_cnt is not 0, then there are messages that
    // are not marked as seen, but were not present in freshMsgs. To find
    // those, the list of messages has to be parsed. Reason for them to
    // not be part of freshMsgs according to DC documentation (seems as if
    // some messages are not returned by dc_get_fresh_msgs(), but are counted
    // into dc_get_fresh_msg_cnt()):
    //
    // >> Messages belonging to muted chats or to the contact requests are not
    // >> returned; these messages should not be notified and also badge counters
    // >> should not include these messages.

    int freshMsgCount = dc_get_fresh_msg_cnt(currentContext, currentChatID);
    if (freshMsgCount != 0) {
        dc_array_t* tempArray = dc_get_chat_msgs(currentContext, currentChatID, 0, 0);

        // start with the newest message, stop the loop if the end of the array
        // has been reached OR if the number of unseen messages given by
        // freshMsgCount has been found
        //
        // It's not possible to start with i = dc_array_get_cnt and set i >= 0
        // as abort condition because i is unsigned. Therefore, i is counted
        // from 0 up to the array size, but the access is inverted.
        size_t arraySize = dc_array_get_cnt(tempArray);
        for (size_t i = 0; i < arraySize && freshMsgCount > 0; ++i) {
            uint32_t tempMsgID = dc_array_get_id(tempArray, arraySize - (i+1));
            dc_msg_t* tempMsg = dc_get_msg(currentContext, tempMsgID);
            if (dc_msg_get_state(tempMsg) != DC_STATE_IN_SEEN && !(dc_msg_get_from_id(tempMsg) == DC_CONTACT_ID_SELF)) {
                --freshMsgCount;
                // mark as seen
                dc_markseen_msgs(currentContext, &tempMsgID, 1);

                // remove notification that might be present, for that
                // assemble the tag of the message (see sendDetailedNotification())
                QString accNumberString;
                accNumberString.setNum(m_currentAccID);

                QString chatNumberString;
                chatNumberString.setNum(currentChatID);

                QString msgNumberString;
                msgNumberString.setNum(tempMsgID);
                m_notificationHelper->removeNotification(accNumberString + "_" + chatNumberString + "_" + msgNumberString);
            }
            dc_msg_unref(tempMsg);
        }
        dc_array_unref(tempArray);
    }
    // notify the view about changes in the model
    updateCurrentChatMessageCount();
}


void DeltaHandler::triggerProviderHintSignal(QString emailAddress)
{
    if (0 == dc_may_be_valid_addr(emailAddress.toUtf8().constData())) {

        // Need to emit the signal with an empty string if it is not a
        // valid email address because the provider hint may already be
        // shown and needs to be unset now.
        emit providerHint(QString(""));
        emit providerInfoUrl(QString(""));
        return;
    }

    if (!tempContext) {
        // A context is needed to proceed. This method is called
        // from AddOrConfigureEmailAccount.qml, so tempContext should be
        // set, but check it to be safe
        qDebug() << "DeltaHandler::triggerProviderHintSignal: tempContext is not set, returning.";
        return;
    }

    dc_provider_t* tempProvider = dc_provider_new_from_email(tempContext, emailAddress.toUtf8().constData());

    if (!tempProvider) {
        tempProvider = dc_provider_new_from_email_with_dns(tempContext, emailAddress.toUtf8().constData());

    }

    if (!tempProvider) {
        // no provider info available
        emit providerHint(QString(""));
        emit providerInfoUrl(QString(""));
        return;
    } else {
        // provider info is available
        if (DC_PROVIDER_STATUS_OK == dc_provider_get_status(tempProvider)) {
            emit providerHint(QString(""));
            emit providerInfoUrl(QString(""));
            emit providerStatus(true);
        } else {
            // Status is either DC_PROVIDER_STATUS_PREPARATION or
            // DC_PROVIDER_STATUS_BROKEN, the hint needs to be sent
            // in both cases. The info URL is sent, too. UI will take
            // care of an empty URL string.
            char* tempText = dc_provider_get_before_login_hint(tempProvider);
            emit providerHint(QString(tempText));
            dc_str_unref(tempText);

            tempText = dc_provider_get_overview_page(tempProvider);
            emit providerInfoUrl(QString(tempText));
            dc_str_unref(tempText);

            if (DC_PROVIDER_STATUS_PREPARATION == dc_provider_get_status(tempProvider)) {
                emit providerStatus(true);
            } else {
                emit providerStatus(false);
            }
        }
        
        dc_provider_unref(tempProvider);
    }

    
}


QString DeltaHandler::copyToCache(QString fromFilePath)
{

    // Method copies the file in fromFilePath in to a new dir in
    // <StandardPaths::CacheLocation>. The subdir is created from the
    // current date and time to avoid overwriting of existing
    // files/dirs. The pathname of the newly created file will be
    // returned.
    //
    // Reason is, for example, to be able to call finalize() 
    // when importing a file via ContentHub. This is needed
    // because the cleaning of the cache dir upon shutdown
    // (see DeltaHandler::shutdownTasks()) cannot remove the
    // HubIncoming directory, but the finalize() call does.
    // However, we have to perform this call while we still
    // need the file to be present.
    
    // fromFilePath might be prepended by "file://" or "qrc:",
    // remove it
    QString tempQString = fromFilePath;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        fromFilePath.remove(0, 7);
    }

    tempQString = fromFilePath;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        fromFilePath.remove(0, 4);
    }

    QString fromFileBasename = fromFilePath.section('/', -1);
    
    QString toFilePath(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    toFilePath.append("/");

    // to avoid overwriting existing files, prepend filename by the current date
    QString dateAndTime = QDateTime::currentDateTime().toString(QStringView(QString(("yymmddhhmmss"))));
    toFilePath.append(dateAndTime);

    QDir tempdir;
    bool success = tempdir.mkpath(toFilePath);
    if (!success) {
        qDebug() << "DeltaHandler::copyToCache(): ERROR: Could not create subdir " << toFilePath << " in cache, aborting.";
        return QString("");
    }

    toFilePath.append("/");

    // complete toFilePath
    toFilePath.append(fromFileBasename);

    qDebug() << "DeltaHandler::copyToCache: Copying " << fromFilePath << " to " << toFilePath;
    QFile::copy(fromFilePath, toFilePath);

    return toFilePath;
}

void DeltaHandler::shutdownTasks()
{
    dc_accounts_stop_io(allAccounts);
    QDir cachepath(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    cachepath.removeRecursively();
}


void DeltaHandler::removeClosedAccountFromList(uint32_t accID)
{
    size_t i = 0;
    size_t endpos = m_closedAccounts.size();
    while (i < endpos) {
        if (m_closedAccounts[i] == accID) {
            qDebug() << "DeltaHandler::removeClosedAccountFromList(): removing account ID " << m_closedAccounts[i] << " from list of closed accounts";
            m_closedAccounts.erase(m_closedAccounts.begin() + i);
            --endpos;
            // could break now, but don't in case an account ID is listed twice
        } else {
            // only increase i if no item is removed from m_closedAccounts
            ++i;
        }
    }

    // If the last closed account has been removed, delete the
    // database passphrase. The user will then have to choose
    // a new one if a new closed account will be added
    if (m_closedAccounts.size() == 0) {
        m_databasePassphrase = "";
    }
}


void DeltaHandler::addClosedAccountToList(uint32_t accID)
{
    m_closedAccounts.push_back(accID);
    qDebug() << "DeltaHandler::addClosedAccountToList(): added ID " << accID << " to list of closed accounts";
}


void DeltaHandler::connectivityUpdate(uint32_t accID)
{
    if (currentContext) {
        if (m_currentAccID == accID) {
            emit connectivityChangedForActiveAccount();
        }
    }
}


bool DeltaHandler::isClosedAccount(uint32_t accID)
{
    bool retval {false};
    for (size_t i = 0; i < m_closedAccounts.size(); ++i) {
        if (m_closedAccounts[i] == accID) {
            retval = true;
            break;
        }
    }
    return retval;
}


void DeltaHandler::receiveJsonrcpResponse(QString response)
{
    emit newJsonrpcResponse(response);
}


uint32_t DeltaHandler::getJsonrpcRequestId() const
{
    // the id is circled between 1000000000 and
    // 2147483647, see comment in constructor
    if (m_jsonrpcRequestId == 2147483647) {
        m_jsonrpcRequestId = 1000000000;
    } else {
        ++m_jsonrpcRequestId;
    }

    return m_jsonrpcRequestId;
}


QString DeltaHandler::constructJsonrpcRequestString(QString method, QString arguments) const
{
    QString requestString("{ \"jsonrpc\": \"2.0\", \"method\": \"");
    requestString.append(method);
    requestString.append("\", \"id\": ");

    QString tempString;
    tempString.setNum(getJsonrpcRequestId());
    requestString.append(tempString);

    requestString.append(", \"params\": [");
    requestString.append(arguments);
    requestString.append(" ] }");

    return requestString;
}


void DeltaHandler::refreshChatlistVector(dc_chatlist_t* tempChatlist)
{
    size_t templistSize = dc_chatlist_get_cnt(tempChatlist);
    size_t internalVectorSize = m_chatlistVector.size();

    std::vector<uint32_t>::iterator it;

    for (size_t i = 0; i < templistSize; ++i) {
        size_t j;
        uint32_t tempChatID = dc_chatlist_get_chat_id(tempChatlist, i);

        for (j = i; j < internalVectorSize; ++j) {
            if (m_chatlistVector[j] == tempChatID) {
                // if j == i, then the chat is already at the right place
                if (j != i) {
                    it = m_chatlistVector.begin();

                    if (1 == j - i) {
                        // if j is the next higher neighbor of i, then
                        // it's likely that the chat at i has either been deleted
                        // or it was a pinned chat that's now unpinned. Even
                        // in the second case it's probably more effective to
                        // just delete it and insert it back again later on
                        // than to move a whole lot of chats one index down.
                        beginRemoveRows(QModelIndex(), i, i);
                        m_chatlistVector.erase(it+i);
                        it = m_chatlistVector.begin();
                        internalVectorSize--;
                        endRemoveRows();
                    } else {
                        beginMoveRows(QModelIndex(), j, j, QModelIndex(), i);
                        
                        // move m_chatlistVector[j] to m_chatlistVector[i],
                        // this has to be achieved via erasing and inserting
                        // Just using
                        // m_chatlistVector[i] = m_chatlistVector[j]
                        // doesn't do the trick because then the view and
                        // m_chatlistVector might differ at some indices:
                        // The view will shift every item between i and j
                        // to one higher index, which the vector doesn't
                        m_chatlistVector.erase(it+j);
                        m_chatlistVector.insert(it+i, tempChatID);

                        endMoveRows();
                    }
                }
                break;
            }
        }

        if (j == internalVectorSize) {
        // Chat at i in tempChatlist was not present in m_chatlistVector, insert it
            it = m_chatlistVector.begin();
            beginInsertRows(QModelIndex(), i, i);
            m_chatlistVector.insert(it+i, tempChatID);
            internalVectorSize++;

            endInsertRows();
        }
    }

    if (internalVectorSize > templistSize) {
        beginRemoveRows(QModelIndex(), templistSize, internalVectorSize - 1);
        m_chatlistVector.resize(templistSize);
        // internalVectorSize = templistSize;
        endRemoveRows();
    }
}


void DeltaHandler::resetChatlistVector(dc_chatlist_t* tempChatlist)
{
    beginResetModel();
    size_t count = dc_chatlist_get_cnt(tempChatlist);
    m_chatlistVector.resize(count);

    for (size_t i = 0; i < count ; ++i) {
        m_chatlistVector[i] = dc_chatlist_get_chat_id(tempChatlist, i);
    }
    endResetModel();
}


bool DeltaHandler::isQueueEmpty()
{
    return (!m_signalQueue_refreshChatlist \
            && m_signalQueue_chatsDataChanged.empty() \
            && m_signalQueue_chatsNoticed.empty() \
            && m_signalQueue_msgs.empty() \
            && m_signalQueue_notificationsToRemove.empty());
}


void DeltaHandler::removeActiveNotificationsOfChat(uint32_t accID, int chatID)
{
    m_notificationHelper->removeActiveNotificationsOfChat(accID, chatID);
}
