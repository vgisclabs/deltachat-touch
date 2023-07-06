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

#include <vector>
#include <fstream>
#include "deltahandler.h"
//#include <unistd.h> // for sleep
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusMessage>

namespace C {
#include <libintl.h>
}


DeltaHandler::DeltaHandler(QObject* parent)
    : QAbstractListModel(parent), tempContext {nullptr}, currentChatlist {nullptr}, m_blockedcontactsmodel {nullptr}, m_groupmembermodel {nullptr}, currentChatID {0}, m_networkingIsAllowed {true}, m_networkingIsStarted {false}, m_showArchivedChats {false}, m_tempGroupChatID {0}, m_query {""}, m_audioRecorder {nullptr}
{
    {
        // to be able to access the files under assets
        Q_INIT_RESOURCE(assets);

        // make the logo accessible in the cache (needed for
        // notifications)
        QFile logoFile(":assets/logo.svg");
        logoFile.copy(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg");

        // prepare directory for the user to put keys to import into
        QString keysToImportDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
        keysToImportDir.append("/keys_to_import");

        if (!QFile::exists(keysToImportDir)) {
            qDebug() << "DeltaHandler::DeltaHandler(): Directory in cache for putting keys to import into not existing, creating it now";
            QDir keysdir;
            bool mkdirsuccess = keysdir.mkpath(keysToImportDir);
            if (mkdirsuccess) {
                qDebug() << "DeltaHandler::DeltaHandler(): Directory " << keysToImportDir << " successfully created";
            }
            else {
                // TODO: any follow-up action?
                qDebug() << "DeltaHandler::DeltaHandler(): Error: Could not create directory " << keysToImportDir;
            }
        }
    }
    // Must use QStandardPaths::AppConfigLocation to get the config dir. With
    // QStandardPaths::ConfigLocation, we just get /home/phablet/.config
    QString configdir(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation));
    qDebug() << "DeltaHandler::DeltaHandler(): Config directory set to: " << configdir;

    settings = new QSettings("deltatouch.lotharketterer", "deltatouch.lotharketterer");

    // stored via QSettings, otherwise removing the previous push notification
    // when receiving a new one would not work as m_lastTag would
    // not be preserved across a restart
    m_lastTag = settings->value("settingsLastTag").toByteArray();

    if (!QFile::exists(configdir)) {
        qDebug() << "DeltaHandler::DeltaHandler(): Config directory not existing, creating it now";
        QDir tempdir;
        bool success = tempdir.mkpath(configdir);
        if (success) {
            qDebug() << "DeltaHandler::DeltaHandler(): Config directory successfully created";
        }
        else {
            qDebug() << "DeltaHandler::DeltaHandler(): Could not create config directory, exiting";
            exit(1);
        }
    }

    // create the cache dir if it doesn't exist yet
    QString cachedir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));

    if (!QFile::exists(cachedir)) {
        qDebug() << "Cache directory not existing, creating it now";
        QDir tempdir;
        bool success = tempdir.mkpath(cachedir);
        if (success) {
            qDebug() << "Cache directory successfully created";
        }
        else {
            qDebug() << "Could not create Cache directory, exiting";
            exit(1);
        }
    }

    m_chatmodel = new ChatModel();
    // TODO: should be something like chatIsCurrentlyViewed or
    // similar because the only time the variable is used is
    // when a new message arrives. Actions to do upon arrival of
    // a new message depends on whether the corresponding chat is
    // currently shown to the user.
    // Also, the page that shows the chat needs to set it to false
    // when the page is destroyed.
    chatmodelIsConfigured = false;

    m_accountsmodel = new AccountsModel();

    m_contactsmodel = new ContactsModel();

    configdir.append("/accounts/");  
    qDebug() << "Config directory set to: " << configdir;
    // Qt documentation for QString:
    // [...] you can pass a QString to a function that takes a const char *
    // argument using the qPrintable() macro which returns the given QString
    // as a const char *. This is equivalent to calling
    // <QString>.toLocal8Bit().constData().
    //
    // Also possible: <QString>.toUtf8().constData() ==>> preferred!
    //
    // Also possible: <QString>.toStdString().c_str()
    //
    // TODO unref the accounts somewhen later? => done in the destructor
    allAccounts = dc_accounts_new(NULL, qPrintable(configdir));

    if (!allAccounts) {
        qDebug() << "DeltaHandler::DeltaHandler: Fatal error trying to create account manager.";
        exit(1);
    }

    m_accountsmodel->configure(allAccounts, this);

    size_t noOfAccounts = m_accountsmodel->rowCount(QModelIndex());

    qDebug() << "DeltaHandler::DeltaHandler: Found " << noOfAccounts << " account(s)";


    eventThread = new EmitterThread();
    eventThread->setAccounts(allAccounts);

    bool connectSuccess = connect(eventThread, SIGNAL(newMsg(uint32_t, int, int)), this, SLOT(incomingMessage(uint32_t, int, int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal newMsg to slot incomingMessage";
        exit(1);
    }

    connectSuccess = connect(eventThread, SIGNAL(msgsChanged(uint32_t, int, int)), this, SLOT(messagesChanged(uint32_t, int, int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal msgsChanged to slot messagesChanged";
        exit(1);
    }

    connectSuccess = connect(eventThread, SIGNAL(chatDataModified(uint32_t, int)), this, SLOT(chatDataModifiedReceived(uint32_t, int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal chatModified to slot chatDataModifiedReceived";
        exit(1);
    }

    connectSuccess = connect(eventThread, SIGNAL(configureProgress(int, QString)), this, SLOT(progressEvent(int, QString)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal configureProgress to slot progressEvent";
        exit(1);
    }

    connectSuccess = connect(eventThread, SIGNAL(contactsChanged()), this, SLOT(changedContacts()));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal contactsChanged to slot changedContacts";
        exit(1);
    }

    connectSuccess = connect(m_contactsmodel, SIGNAL(chatCreationSuccess(uint32_t)), this, SLOT(chatCreationReceiver(uint32_t)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal chatCreationSuccess to slot chatCreationReceiver";
        exit(1);
    }

    connectSuccess = connect(m_chatmodel, SIGNAL(markedAllMessagesSeen()), this, SLOT(resetCurrentChatMessageCount()));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal markedAllMessagesSeen to slot resetCurrentChatMessageCount";
        exit(1);
    }

    connectSuccess = connect(this, SIGNAL(openChatViewRequest()), m_chatmodel, SLOT(chatViewIsOpened()));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal openChatViewRequest to slot chatViewIsOpened";
        exit(1);
    }

    connectSuccess = connect(eventThread, SIGNAL(msgDelivered(uint32_t, int, int)), this, SLOT(messageDeliveredToServer(uint32_t, int, int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal msgDelivered to slot messageDeliveredToServer";
        exit(1);
    }

    connectSuccess = connect(this, SIGNAL(messageDelivered(int)), m_chatmodel, SLOT(messageStatusChangedSlot(int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal messageDelivered to slot messageStatusChangedSlot";
        exit(1);
    }

    connectSuccess = connect(eventThread, SIGNAL(msgRead(uint32_t, int, int)), this, SLOT(messageReadByRecipient(uint32_t, int, int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal msgRead to slot messageReadByRecipient";
        exit(1);
    }

    connectSuccess = connect(this, SIGNAL(messageRead(int)), m_chatmodel, SLOT(messageStatusChangedSlot(int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal messageRead to slot messageReadSlot";
        exit(1);
    }

    connectSuccess = connect(eventThread, SIGNAL(msgFailed(uint32_t, int, int)), this, SLOT(messageFailedSlot(uint32_t, int, int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal msgRead to slot messageReadByRecipient";
        exit(1);
    }

    connectSuccess = connect(this, SIGNAL(messageFailed(int)), m_chatmodel, SLOT(messageStatusChangedSlot(int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal messageRead to slot messageReadSlot";
        exit(1);
    }

    eventThread->start();

    if (noOfAccounts == 0){
        qDebug() << "DeltaHandler::DeltaHandler: No account found";
        m_hasConfiguredAccount = false;
        currentContext = nullptr;
    }
    else {
        currentContext = dc_accounts_get_selected_account(allAccounts);
        contextSetupTasks();

        setCoreTranslations();

        if (dc_is_configured(currentContext)) {
            m_hasConfiguredAccount = true;
        }
        else {
            qDebug() << "DeltaHandler::DeltaHandler: Selected account is not configured, searching for another account..";
            m_hasConfiguredAccount = false;

            // TODO: Is it possible that the selected account is
            // unconfigured, but a aconfigured account exists?
            dc_array_t* tempArray = dc_accounts_get_all(allAccounts);

            for (size_t i = 0; i < noOfAccounts; ++i) {
                uint32_t tempAccID = dc_array_get_id(tempArray, i);
                tempContext = dc_accounts_get_account(allAccounts, tempAccID);
                if (dc_is_configured(tempContext)) {
                    m_hasConfiguredAccount = true;
                    // TODO: does the signal have to be emitted?
                    emit hasConfiguredAccountChanged();
                    dc_accounts_select_account(allAccounts, tempAccID);

                    dc_context_unref(currentContext);
                    currentContext = tempContext;
                    tempContext = nullptr;
                    contextSetupTasks();

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

        if (m_hasConfiguredAccount) {
            currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
        }
    } // else of if(noOfAccounts == 0)
}

DeltaHandler::~DeltaHandler()
{
    dc_accounts_stop_io(allAccounts);

    if (currentChatlist) {
        dc_chatlist_unref(currentChatlist);
    }

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
}

int DeltaHandler::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    // return our data count
    if (m_hasConfiguredAccount) {
        return dc_chatlist_get_cnt(currentChatlist);
    }
    else {
        return 0;
    }
}

QHash<int, QByteArray> DeltaHandler::roleNames() const
{
    QHash<int, QByteArray> roles;

    roles[ChatnameRole] = "chatname";
    roles[ChatIsPinnedRole] = "chatIsPinned";
    roles[ChatIsArchivedRole] = "chatIsArchived";
    roles[ChatIsArchiveLinkRole] = "chatIsArchiveLink";
    roles[MsgPreviewRole] = "msgPreview";
    roles[TimestampRole] = "timestamp";
    roles[StateRole] = "state";
    roles[ChatPicRole] = "chatPic";
    roles[IsContactRequestRole] = "isContactRequest";
    roles[AvatarColorRole] = "avatarColor";
    roles[AvatarInitialRole] = "avatarInitial";
    roles[ChatIsMutedRole] = "chatIsMuted";
    roles[NewMsgCountRole] = "newMsgCount";
    return roles;
}

QVariant DeltaHandler::data(const QModelIndex &index, int role) const
{
    if (!m_hasConfiguredAccount) {
        return QVariant();
    }
    int row = index.row();

    // If row is out of bounds, an empty QVariant is returned
    if(row < 0 || row >= static_cast<int>(dc_chatlist_get_cnt(currentChatlist))) {
        return QVariant();
    }

    uint32_t tempChatID = dc_chatlist_get_chat_id(currentChatlist, row);
    dc_chat_t* tempChat = dc_get_chat(currentContext, tempChatID);
    dc_lot_t* tempLot = dc_chatlist_get_summary(currentChatlist, row, tempChat);

    QString tempQString;
    QVariant retval;
    char* tempText {nullptr};
    uint64_t timestampSecs {0};
    uint32_t tempColor {0};
    QDateTime timestampDate;
    QColor tempQColor;

    switch(role) {
        case DeltaHandler::ChatnameRole:
            tempText = dc_chat_get_name(tempChat); 
            tempQString = tempText;
            retval = tempQString;
            break;

        case DeltaHandler::ChatIsPinnedRole:
            if (DC_CHAT_VISIBILITY_PINNED == dc_chat_get_visibility(tempChat)) {
                retval = true;
            } else {
                retval = false;
            }

            break;

        case DeltaHandler::ChatIsArchivedRole:
            if (DC_CHAT_VISIBILITY_ARCHIVED == dc_chat_get_visibility(tempChat)) {
                retval = true;
            } else {
                retval = false;
            }
            break;
            
        case DeltaHandler::ChatIsArchiveLinkRole:
            if (DC_CHAT_ID_ARCHIVED_LINK == tempChatID) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        case DeltaHandler::MsgPreviewRole:
            // TODO: internationalize text1, so for example, "Me"
            // will get translated
            tempText = dc_lot_get_text1(tempLot); 

            if (tempText) {
                tempQString = tempText;
                tempQString += ": ";
                dc_str_unref(tempText);
            }

            tempText = dc_lot_get_text2(tempLot); 
            tempQString += tempText;
            retval = tempQString;
            break;

        case DeltaHandler::ChatPicRole:
            tempText = dc_chat_get_profile_image(tempChat);
            tempQString = tempText;
            tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
            retval = tempQString;
            break;

        case DeltaHandler::TimestampRole:
            timestampSecs = dc_lot_get_timestamp(tempLot);
            if (timestampSecs == 0) {
                tempQString = "n/a";
                retval = tempQString;
                break;
            }
            timestampDate = QDateTime::fromSecsSinceEpoch(timestampSecs);
            if (timestampDate.date() == QDate::currentDate()) {
                tempQString = timestampDate.toString("hh:mm");
                // TODO: if <option_for_am/pm> ...("hh:mm ap")
                // => check the QLocale Class
            }
            else if (timestampDate.date().daysTo(QDate::currentDate()) < 7) {
                // TODO: "...hh:mm ap " as above
                tempQString = timestampDate.toString("ddd hh:mm");
            }
            else {
                tempQString = timestampDate.toString("dd MMM yy" );
            }
            retval = tempQString;
            break;

        case DeltaHandler::IsContactRequestRole:
            if (dc_chat_is_contact_request(tempChat)) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        case DeltaHandler::AvatarColorRole:
            tempColor = dc_chat_get_color(tempChat);
            // doesn't work as it won't take care of leading zeros
            //tempQString = QString::number(tempColor, 16);
            tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
            tempQString = tempQColor.name();
            retval = tempQString;
            break;

        case DeltaHandler::AvatarInitialRole:
            tempText = dc_chat_get_name(tempChat); 
            tempQString = tempText;
            if (tempQString == "") {
                tempQString = "#";
            } else {
               tempQString = QString(tempQString.at(0)).toUpper(); 
            }
            retval = tempQString;
            break;

        case DeltaHandler::ChatIsMutedRole:
            if (dc_chat_is_muted(tempChat)) {
                retval = true;
            } else {
                retval = false;
            }

            break;

        case DeltaHandler::NewMsgCountRole:
            retval = dc_get_fresh_msg_cnt(currentContext, tempChatID);
            break;

        default:
            retval = QString("");

    }

    dc_lot_unref(tempLot);
    dc_chat_unref(tempChat);

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
        qDebug() << "DeltaHandler::blockedcontactsmodel(): FATAL ERROR: currentContext is not set, exiting.";
        exit(1);
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
    m_momentaryChatId = dc_chatlist_get_chat_id(currentChatlist, myindex);
}


void DeltaHandler::setMomentaryChatIdById(uint32_t myId)
{
    m_momentaryChatId = myId;
}


void DeltaHandler::selectChat(int myindex)
{
    currentChatID = dc_chatlist_get_chat_id(currentChatlist, myindex);
}


void DeltaHandler::openChat()
{

    if (currentChatID == DC_CHAT_ID_ARCHIVED_LINK) {
        // If the archive link has been clicked, reset
        // the model to show the archived chats only.
        m_showArchivedChats = true;
        beginResetModel();

        // only clear the search string when switching to the archive
        // view, but not when opening a normal chat
        if (m_query != "") {
            m_query = "";
            emit clearChatlistQueryRequest();
        }

        dc_chatlist_unref(currentChatlist);
        currentChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, NULL, 0);
        endResetModel();
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
        chatmodelIsConfigured = true;

        emit openChatViewRequest();
    }
}


void DeltaHandler::archiveMomentaryChat()
{
    // It is not needed to 
    // - call beginResetModel() / endResetModel
    // - unref the chatlist and get it again
    // because changing the visibility will trigger
    // DC_EVENT_MSGS_CHANGED, causing the messagesChanged() slot to reset
    // the model and the chatlist
    dc_set_chat_visibility(currentContext, m_momentaryChatId, DC_CHAT_VISIBILITY_ARCHIVED);
}


void DeltaHandler::unarchiveMomentaryChat()
{
    // see comments in archiveMomentaryChat(int)
    dc_set_chat_visibility(currentContext, m_momentaryChatId, DC_CHAT_VISIBILITY_NORMAL);
}


void DeltaHandler::pinUnpinMomentaryChat()
{
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
    int success = dc_set_chat_mute_duration(currentContext, m_momentaryChatId, secondsToMute);

    if (0 == success) {
        qDebug() << "DeltaHandler::chatSetMuteDuration(): ERROR:Setting the mute duration failed";
    }

    beginResetModel();

    dc_chatlist_unref(currentChatlist);

    if (m_showArchivedChats) {
        if (m_query == "") {
            currentChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, NULL, 0);
        } else {
            currentChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, m_query.toUtf8().constData(), 0);
        }
    } else {
        if (m_query == "") {
            currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
        } else {
            currentChatlist = dc_get_chatlist(currentContext, 0, m_query.toUtf8().constData(), 0);
        }
    }

    endResetModel();
}


void DeltaHandler::closeArchive()
{
    m_showArchivedChats = false;

    beginResetModel();

    // clear the query before obtaining a new chatlist
    if (m_query != "") {
        m_query = "";
        emit clearChatlistQueryRequest();
    }

    dc_chatlist_unref(currentChatlist);
    currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);

    endResetModel();

    emit chatlistShowsArchivedOnly(m_showArchivedChats);
}


void DeltaHandler::selectAccount(int myindex)
{
    dc_array_t* contextArray = dc_accounts_get_all(allAccounts);

    if (myindex < 0 || myindex >= dc_array_get_cnt(contextArray)) {
        qDebug() << "DeltaHandler::selectAccount: Error: index out of bounds";
        return;
    }

    uint32_t accID = dc_array_get_id(contextArray, myindex);

    if (currentContext && accID == dc_get_id(currentContext)) {
        qDebug() << "DeltaHandler::selectAccount: Selected account already active, doing nothing.";
        return;
    }

    beginResetModel();

    if (tempContext) {
        dc_context_unref(tempContext);
    }

    int success = dc_accounts_select_account(allAccounts, accID);
    if (0 == success) {
        qDebug() << "DeltaHandler::selectAccount: ERROR: dc_accounts_select_account was unsuccessful";
    }

    tempContext = dc_accounts_get_selected_account(allAccounts);

    if (!dc_is_configured(tempContext)) {
        qDebug() << "DeltaHandler::selectAccount: trying to select unconfigured account, refusing";
        dc_context_unref(tempContext);
        endResetModel();
        return;
    }

    if (currentChatlist) {
        dc_chatlist_unref(currentChatlist);
    }
    
    if (currentContext) {
        dc_context_unref(currentContext);
    }

    // guard context change by stopping io to avoid
    // new messages coming in while creating the unread message
    // vector
    bool restartNetwork = m_networkingIsStarted;
    if (m_networkingIsStarted) {
        stop_io();
    }
    currentContext = tempContext;
    tempContext = nullptr;
    contextSetupTasks();

    if (restartNetwork) {
        start_io();
    }

    // clear the query before obtaining a new chatlist
    if (m_query != "") {
        m_query = "";
        emit clearChatlistQueryRequest();
    }

    currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);

    chatmodelIsConfigured = false;

    endResetModel();

    emit accountChanged();
    
    dc_array_unref(contextArray);
}


void DeltaHandler::messagesChanged(uint32_t accID, int chatID, int msgID)
{
    uint32_t currentAccID = dc_get_id(currentContext);
   
    // needs to be done in any case, whether a notification is 
    // created or not
    if (currentAccID == accID) {
        // need to reset the model because
        // - a chat may have been deleted (chatID would be 0 then)
        // - a new chat may be present
        // - one or more new messages may have been received, so
        //   the new message counter and the message preview may be
        //   affected.
        beginResetModel();

        if (currentChatlist) {
            dc_chatlist_unref(currentChatlist);
        }
        
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
                currentChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, NULL, 0);
                if (0 == dc_chatlist_get_cnt(currentChatlist)) {
                    m_showArchivedChats = false;
                    dc_chatlist_unref(currentChatlist);
                    currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
                    emit chatlistShowsArchivedOnly(m_showArchivedChats);
                }
            } else {
                currentChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, m_query.toUtf8().constData(), 0);
            }

        } else {
            // we're in the standard (i.e., non-archive) view
            if (m_query == "") {
                currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
            } else {
                currentChatlist = dc_get_chatlist(currentContext, 0, m_query.toUtf8().constData(), 0);
            }
        }
        
        endResetModel();

        // Have to emit the signal if the chatmodel may be
        // affected (in case of deletion of a message, chatID
        // and msgID will be 0).
        // TODO: Create new signal with more suitable name?
        if (chatmodelIsConfigured && (currentChatID == chatID || 0 == chatID)) {
            emit msgsChanged(msgID);
        }

    } else { // message(s) for context other than the current one
        qDebug() << "DeltaHandler::messagesChanged(): signal newMsg received with accID: " << accID << ", chatID: " << chatID << "msgID: " << msgID;
    }
}


void DeltaHandler::chatDataModifiedReceived(uint32_t accID, int chatID)
{
    uint32_t currentAccID = dc_get_id(currentContext);
   
    if (currentAccID == accID && currentChatID == chatID) {
        emit chatDataChanged();
    }
}


void DeltaHandler::incomingMessage(uint32_t accID, int chatID, int msgID)
{
    uint32_t currentAccID = dc_get_id(currentContext);
   
    // needs to be done in any case, whether a notification is 
    // created or not
    if (currentAccID == accID) {
        // insert the new message into the vector containing all
        // unread messages of this context
        if (0 != chatID && 0 != msgID) {
            std::array<uint32_t, 2> tempStdArr {msgID, chatID};
            freshMsgs.push_back(tempStdArr);
        }
    }

    sendNotification(accID, chatID, msgID);

    messagesChanged(accID, chatID, msgID);
}


void DeltaHandler::sendNotification(uint32_t accID, int chatID, int msgID)
{
    if (!m_enablePushNotifications) {
        // disabled in the settings
        return;
    }

    uint32_t currentAccID = dc_get_id(currentContext);

    if (accID == currentAccID && chatID == currentChatID && chatmodelIsConfigured && QGuiApplication::applicationState() == Qt::ApplicationActive) {
        // don't send a notification if the user is looking at the chat
        return;
    }

    if (accID == currentAccID && !chatmodelIsConfigured && QGuiApplication::applicationState() == Qt::ApplicationActive) {
        // don't send a notification if the user is looking at the chatlist of
        // the account for which a message was received
        return;
    }

    dc_context_t* tempContext = dc_accounts_get_account(allAccounts, accID);

    if (!tempContext) {
        qDebug() << "DeltaHandler::sendNotification(): ERROR: tempContect is NULL";
        return;
    }

    dc_chat_t* tempChat = dc_get_chat(tempContext, chatID);

    if (!tempChat) {
        qDebug() << "DeltaHandler::sendNotification(): ERROR: tempChat is NULL";
        dc_context_unref(tempContext);
        return;
    }

    if (dc_chat_is_muted(tempChat)) {
        // don't create notification if the chat is muted
        dc_chat_unref(tempChat);
        dc_context_unref(tempContext);
        return;
    }

    QString accNumberString;
    accNumberString.setNum(accID);

    QString chatNumberString;
    chatNumberString.setNum(chatID);

    QString msgNumberString;
    msgNumberString.setNum(msgID);

    // the email address of the user
    QString accNameString("?");
    char* tempText = dc_get_config(tempContext, "mail_user");
    if (tempText) {
        accNameString = tempText;
        dc_str_unref(tempText);
        tempText = nullptr;
    } 

    QString chatNameString("?");
    tempText = dc_chat_get_name(tempChat);
    if (tempText) {
        chatNameString = tempText;
        dc_str_unref(tempText);
        tempText = nullptr;
    }

    dc_msg_t* tempMsg = dc_get_msg(tempContext, msgID);
    if (!tempMsg) {
        qDebug() << "DeltaHandler::sendNotification(): ERROR: tempMsg is NULL";
        dc_chat_unref(tempChat);
        dc_context_unref(tempContext);
        return;
    }

    dc_lot_t* tempLot = dc_msg_get_summary(tempMsg, tempChat);

    QString fromString;
    tempText = dc_msg_get_override_sender_name(tempMsg);
    if (!tempText) {
        tempText = dc_contact_get_display_name(dc_get_contact(tempContext, dc_msg_get_from_id(tempMsg)));
        fromString = tempText;
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

    if (m_detailedPushNotifications) {
    // only show name of sender + content of message
    // if m_detailedPushNotifications is set
    //
    // Get the avatar of the user or group
        tempText = dc_chat_get_profile_image(tempChat);
        if (tempText) {
            icon = tempText;
            dc_str_unref(tempText);
            tempText = nullptr;
        }

        createNotification(fromString, messageExcerpt, accNumberString + "_" + chatNumberString + "_" + msgNumberString, icon);
    } else { // if (m_detailedPushNotifications)
        // m_detailedPushNotifications is not set, just send generic notification
        //
        // Instead of the avatar of the user or group, the DeltaTouch icon is used
        QString icon;
        QFile logoFile(":assets/logo.svg");
        logoFile.copy(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg");
        icon = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/logo.svg";

        createNotification(C::gettext("New message"), C::gettext("New message"), accNumberString + "_" + chatNumberString + "_" + msgNumberString, icon);
    }

    dc_msg_unref(tempMsg);
    dc_chat_unref(tempChat);
    dc_context_unref(tempContext);

    if (tempLot) {
        dc_lot_unref(tempLot);
    }
}

void DeltaHandler::setEnablePushNotifications(bool enabled)
{
    m_enablePushNotifications = enabled;
}


void DeltaHandler::setDetailedPushNotifications(bool detailed)
{
    m_detailedPushNotifications = detailed;
}


void DeltaHandler::setAggregatePushNotifications(bool aggregate)
{
    m_aggregateNotifications = aggregate;
}


void DeltaHandler::messageReadByRecipient(uint32_t accID, int chatID, int msgID)
{
    uint32_t currentAccID = dc_get_id(currentContext);

    if (currentAccID == accID && currentChatID == chatID && chatmodelIsConfigured) {
        emit messageRead(msgID);
    }
}


void DeltaHandler::messageDeliveredToServer(uint32_t accID, int chatID, int msgID)
{
    uint32_t currentAccID = dc_get_id(currentContext);

    if (currentAccID == accID && currentChatID == chatID && chatmodelIsConfigured) {
        emit messageDelivered(msgID);
    }
    
}


void DeltaHandler::messageFailedSlot(uint32_t accID, int chatID, int msgID)
{
    uint32_t currentAccID = dc_get_id(currentContext);

    if (currentAccID == accID && currentChatID == chatID && chatmodelIsConfigured) {
        emit messageFailed(msgID);
    }
    
}


QString DeltaHandler::chatName()
{
    if (chatmodelIsConfigured) {
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

    if (dc_chat_get_type(tempChat) == DC_CHAT_TYPE_GROUP) {
        if (1 == dc_chat_is_protected(tempChat)) {
            retval = true;
        } 
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

        if ("mail_pw" == key || "send_pw" == key || "socks5_password" == key) {
            qDebug() << "DeltaHandler::getCurrentConfig() called for " << key << ", returning " << "*****";
        } else {
            qDebug() << "DeltaHandler::getCurrentConfig() called for " << key << ", returning " << retval;
        }

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
        tempChatID = dc_chatlist_get_chat_id(currentChatlist, myindex);
    }

    return dc_get_chat_ephemeral_timer(currentContext, tempChatID);
}


void DeltaHandler::setChatEphemeralTimer(int myindex, uint32_t timer)
{
    uint32_t tempChatID;

    if (myindex == -1) {
        tempChatID = currentChatID;
    } else {
        tempChatID = dc_chatlist_get_chat_id(currentChatlist, myindex);
    }

    if (timer != getChatEphemeralTimer(myindex)) {
        dc_set_chat_ephemeral_timer(currentContext, tempChatID, timer);
    }
}


void DeltaHandler::deleteMomentaryChat()
{
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
            // the url handed over by the ContentHub starts with
            // "file:///home....", so we have to remove the first 7
            // characters
            newValue.remove(0, 7);
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
        uint32_t currentAccID = dc_get_id(currentContext);

        if (accID == currentAccID) {
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


void DeltaHandler::prepareTempContextConfig() {
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
        uint32_t accID = dc_accounts_add_account(allAccounts);
        tempContext = dc_accounts_get_account(allAccounts, accID);
        m_configuringNewAccount = true;
    }
    else {
        m_configuringNewAccount = false;
    }
}

void DeltaHandler::configureTempContext() {
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
            uint32_t tempAccID = dc_get_id(currentContext);
            dc_accounts_select_account(allAccounts, tempAccID);
        }
        if (m_configuringNewAccount) {
            emit newUnconfiguredAccount(); 
        } else {
            emit updatedAccountConfig(dc_get_id(tempContext));
        }

        // allow networking again, see configureTempContext()
        m_networkingIsAllowed = true;
        emit networkingIsAllowedChanged();

    } else if (perMill == 1000) {
        beginResetModel();

        if (currentChatlist) {
            dc_chatlist_unref(currentChatlist);
        }
        
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

        if (restartNetwork) {
            start_io();
        }

        // clear the query before obtaining a new chatlist
        if (m_query != "") {
            m_query = "";
            emit clearChatlistQueryRequest();
        }

        currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);

        chatmodelIsConfigured = false;

        if (!m_hasConfiguredAccount) {
            m_hasConfiguredAccount = true;
            emit hasConfiguredAccountChanged();
        }
        endResetModel();
        // TODO: correct order of actions in lines above + below?
        if (m_configuringNewAccount) {
            emit newConfiguredAccount();
            emit accountChanged();
        }
        else {
            emit updatedAccountConfig(dc_get_id(currentContext));
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
            uint32_t tempAccID = dc_get_id(currentContext);
            dc_accounts_select_account(allAccounts, tempAccID);
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
        beginResetModel();

        if (currentChatlist) {
            dc_chatlist_unref(currentChatlist);
        }
        
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

        if (restartNetwork) {
            start_io();
        }

        // clear the query before obtaining a new chatlist
        if (m_query != "") {
            m_query = "";
            emit clearChatlistQueryRequest();
        }

        currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);

        chatmodelIsConfigured = false;

        if (!m_hasConfiguredAccount) {
            m_hasConfiguredAccount = true;
            emit hasConfiguredAccountChanged();
        }
        endResetModel();

        emit newConfiguredAccount();
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
    // Resetting model, re-loading currentChatlist not
    // needed because the emitter emits the signal
    // newMsg which is connected to the slot incomingMessage.
    // The slot will take care of adding the new
    // chat to the chatlist.
     
    // NOT calling selectChat(int) as the parameter of
    // this method is the array index, not the chatID
    currentChatID = chatID; 
    openChat();
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
    if (dc_get_id(currentContext) != accIDtoUnselect) {
        qDebug() << "DeltaHandler::unselectAccount: Being called to unselect account id " << accIDtoUnselect << ", but it is already not the selected account.";
        return;
    }

    beginResetModel();
    
    dc_array_t* tempArray = dc_accounts_get_all(allAccounts);
    size_t noOfAccounts = m_accountsmodel->rowCount(QModelIndex());

    if (1 == noOfAccounts) {
        dc_context_unref(currentContext);
        currentContext = nullptr;
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

        if (currentChatlist) {
            dc_chatlist_unref(currentChatlist);
            currentChatlist = nullptr;
        }

        if (foundConfiguredAccount) {
            qDebug() << "DeltaHandler::unselectAccount: Choosing configured account " << accountToSwitchTo << "as new selected account.";
            dc_context_unref(currentContext);

            bool restartNetwork = m_networkingIsStarted;
            if (m_networkingIsStarted) {
                stop_io();
            }
            currentContext = tempContext;
            // TODO: why not setting tempContext to nullptr here?
            //tempContext = nullptr;
            contextSetupTasks();

            if (restartNetwork) {
                start_io();
            }

            // clear the query before obtaining a new chatlist
            if (m_query != "") {
                m_query = "";
                emit clearChatlistQueryRequest();
            }

            currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
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
            contextSetupTasks();

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
            //chatmodelIsConfigured = false; // should be set by the
            //chatview page, see comment on introduction of this
            //variable

    } // else if (1 == noOfAccounts9

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


bool DeltaHandler::isBackupFile(QString filePath)
{
    // the url handed over by the ContentHub starts with
    // "file:///home....", so we have to remove the first 7
    // characters
    filePath.remove(0, 7);

    if (!filePath.contains('/')) {
        qDebug() << "DeltaHandler::isBackupFile: Looks like the passed path is no path from ContentHub: No / found in string.";
        return false;
    }

    QString fileName = filePath.section('/', -1);
    QString purePath = filePath;
    purePath.resize(filePath.length() - fileName.length());
    
    if (tempContext) {
        qDebug() << "DeltaHandler::isBackupFile: tempContext is unexpectedly set, will now be unref'd";
        dc_context_unref(tempContext);
        tempContext = nullptr;
    }

    uint32_t accID = dc_accounts_add_account(allAccounts);
    
    if (0 == accID) {
        qDebug() << "DeltaHandler::isBackupFile: Could not create new account.";
        return false;
    }

    tempContext = dc_accounts_get_account(allAccounts, accID);

    char* tempText = dc_imex_has_backup(tempContext, purePath.toUtf8().constData());
    QString tempFile = tempText;
    
    bool isBackup;

    if (tempFile == filePath) {
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
    // imexProgress may be connected to imexBackupExportProgressReceiver,
    // disconnect it...
    // TODO: imexBackupImportProgressReceiver is disconnected, too, because
    // it might cause problems if it's connected twice, is this true?
    // TODO check return values?
    bool disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));
    disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
    
    // ... and connect it to imexBackupImportProgressReceiver instead
    bool connectSuccess = connect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal imexProgress to slot imexBackupImportProgressReceiver";
        exit(1);
    }

    // the url handed over by the ContentHub starts with
    // "file:///home....", so we have to remove the first 7
    // characters
    filePath.remove(0, 7);
    qDebug() << "DeltaHandler::importBackupFromFile: path to backup file is: " << filePath;
    m_networkingIsAllowed = false;
    // not emitting signal, but stopping io directly
    stop_io();
    // TODO: implement password for importing backup
    dc_imex(tempContext, DC_IMEX_IMPORT_BACKUP, filePath.toUtf8().constData(), NULL);
}


void DeltaHandler::chatAcceptContactRequest()
{
    dc_accept_chat(currentContext, currentChatID);
    m_chatmodel->acceptChat();
    emit chatIsContactRequestChanged();
}


void DeltaHandler::chatDeleteContactRequest()
{
    dc_delete_chat(currentContext, currentChatID);
}


void DeltaHandler::chatBlockContactRequest()
{
    dc_block_chat(currentContext, currentChatID);
}


void DeltaHandler::exportBackup()
{
    if (!currentContext) return;

    // imexProgress may be connected to imexBackupImportProgressReceiver,
    // disconnect it...
    // TODO: imexBackupExportProgressReceiver is disconnected, too, because
    // it might cause problems if it's connected twice, is this true?
    // TODO check return values?
    bool disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
    disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));
    
    // ... and connect it to imexBackupExportProgressReceiver instead
    bool connectSuccess = connect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal imexProgress to slot imexBackupExportProgressReceiver";
        exit(1);
    }

    connectSuccess = connect(eventThread, SIGNAL(imexFileWritten(QString)), this, SLOT(imexFileReceiver(QString)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal imexFileWritten to slot imexFileReceiver";
        exit(1);
    }

    QString cacheDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));

    dc_imex(currentContext, DC_IMEX_EXPORT_BACKUP, cacheDir.toUtf8().constData(), NULL);
}


QString DeltaHandler::getUrlToExport()
{
    return m_tempExportPath;
}


bool DeltaHandler::isExistingChat(uint32_t chatID) {
    if (!currentChatlist) {
        qDebug() << "DeltaHandler::isExistingChat(): ERROR: currentChatlist is not set";
        return false;
    }
    for (size_t i = 0; i < dc_chatlist_get_cnt(currentChatlist); ++i) {
        if (dc_chatlist_get_chat_id(currentChatlist, i) == chatID) {
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
        // the url handed over by the ContentHub starts with
        // "file:///home....", so we have to remove the first 7
        // characters
        newValue.remove(0, 7);
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
        tempText = dc_contact_get_verifier_addr(tempContact);
        retval = tempText;
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
        if (timestampSecs == 0) {
            retval = "";
        } else {
            QDateTime timestampDate;
            timestampDate = QDateTime::fromSecsSinceEpoch(timestampSecs);
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


void DeltaHandler::startCreateGroup(bool verifiedGroup)
{
    creatingNewGroup = true;
    creatingOrEditingVerifiedGroup = verifiedGroup;
    m_groupmembermodel = new GroupMemberModel();
    m_groupmembermodel->setConfig(currentContext, true);

    m_contactsmodel->setVerifiedOnly(verifiedGroup);
    m_contactsmodel->resetNewMemberList();
    m_contactsmodel->setMembersAlreadyInGroup(m_groupmembermodel->getMembersAlreadyInGroup());
    
    bool connectSuccess = connect(m_contactsmodel, SIGNAL(addContactToGroup(uint32_t)), m_groupmembermodel, SLOT(addMember(uint32_t)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::startCreateGroup(): Could not connect signal addContactToGroup to slot addMember";
        exit(1);
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
        m_tempGroupChatID = dc_chatlist_get_chat_id(currentChatlist, myindex);
    }

    m_groupmembermodel = new GroupMemberModel();
    m_groupmembermodel->setConfig(currentContext, false, m_tempGroupChatID);

    dc_chat_t* tempChat = dc_get_chat(currentContext, m_tempGroupChatID);
    if (1 == dc_chat_is_protected(tempChat)) {
        m_contactsmodel->setVerifiedOnly(true);
        creatingOrEditingVerifiedGroup = true;
    } else {
        m_contactsmodel->setVerifiedOnly(false);
        creatingOrEditingVerifiedGroup = false;
    }
    dc_chat_unref(tempChat);

    m_contactsmodel->resetNewMemberList();
    m_contactsmodel->setMembersAlreadyInGroup(m_groupmembermodel->getMembersAlreadyInGroup());
    
    bool connectSuccess = connect(m_contactsmodel, SIGNAL(addContactToGroup(uint32_t)), m_groupmembermodel, SLOT(addMember(uint32_t)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::startCreateGroup(): Could not connect signal addContactToGroup to slot addMember";
        exit(1);
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
        creatingOrEditingVerifiedGroup = true;
    } else {
        m_contactsmodel->setVerifiedOnly(false);
        creatingOrEditingVerifiedGroup = false;
    }
    dc_chat_unref(tempChat);

    m_contactsmodel->resetNewMemberList();
    m_contactsmodel->setMembersAlreadyInGroup(m_groupmembermodel->getMembersAlreadyInGroup());
    
    bool connectSuccess = connect(m_contactsmodel, SIGNAL(addContactToGroup(uint32_t)), m_groupmembermodel, SLOT(addMember(uint32_t)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::startCreateGroup(): Could not connect signal addContactToGroup to slot addMember";
        exit(1);
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
    return creatingOrEditingVerifiedGroup;
}


void DeltaHandler::setGroupPic(QString filepath)
{
    filepath.remove(0, 7);
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


void DeltaHandler::finalizeGroupEdit(QString groupName, QString imagePath)
{

    if (creatingNewGroup) {
        if (creatingOrEditingVerifiedGroup) {
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
    // the array received from currentContext, but no
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

    uint32_t accID = dc_accounts_add_account(allAccounts);
    
    if (0 == accID) {
        qDebug() << "DeltaHandler::prepareQrBackupImport: Could not create new account.";
        // TODO: add boolean parameter to readyForQrBackupImport(), emit the signal
        // here with false and handle it accordingly in the GUI?
        return;
    }

    tempContext = dc_accounts_get_account(allAccounts, accID);
    
    emit readyForQrBackupImport();
}


void DeltaHandler::startQrBackupImport()
{
    // imexProgress may be connected to imexBackupExportProgressReceiver or imexBackupImportProgressReceiver
    // disconnect it.
    // As dc_receive_backup() is blocking, imexProgress signals from eventThread will
    // not be processed anyway, so the return value from dc_receive_backup() will
    // be evaluated.
    // TODO check return values?
    // TODO disconnect the slots directly after completion of the corresponding actions
    bool disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupExportProgressReceiver(int)));
    disconnectSuccess = disconnect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexBackupImportProgressReceiver(int)));
 
    m_networkingIsAllowed = false;
    // not emitting signal, but stopping io directly
    stop_io();
    
    // TODO check return value?
    int importSuccess = dc_receive_backup(tempContext, m_qrTempText.toUtf8().constData());
    if (0 == importSuccess) {
        // If the backup import was not successful, re-select the
        // currently active (and configured) account and delete the
        // new account that has been prepared for the importing
        // process.
        if (currentContext) {
            uint32_t tempAccID = dc_get_id(currentContext);
            dc_accounts_select_account(allAccounts, tempAccID);
        }
        
        if (tempContext) {
            int tempAccID = dc_get_id(tempContext);
            dc_context_unref(tempContext);
            tempContext = nullptr;
            dc_accounts_remove_account(allAccounts, tempAccID);
        }
        m_networkingIsAllowed = true;
        emit networkingIsAllowedChanged();
    } else {
        beginResetModel();

        if (currentChatlist) {
            dc_chatlist_unref(currentChatlist);
        }
        
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

        if (restartNetwork) {
            start_io();
        }

        // clear the query before obtaining a new chatlist
        if (m_query != "") {
            m_query = "";
            emit clearChatlistQueryRequest();
        }

        currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);

        chatmodelIsConfigured = false;

        if (!m_hasConfiguredAccount) {
            m_hasConfiguredAccount = true;
            emit hasConfiguredAccountChanged();
        }
        endResetModel();

        emit newConfiguredAccount();
        emit accountChanged();
        m_networkingIsAllowed = true;
        emit networkingIsAllowedChanged();
    }
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


void DeltaHandler::prepareAudioRecording(int recordingQuality)
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
}


QString DeltaHandler::startAudioRecording()
{

    QString outfile("/voice_message.opus");
    QString retval = outfile;
    outfile.prepend(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    m_audioRecorder->setOutputLocation(QUrl(outfile));

    m_audioRecorder->record();

    return retval;
}


void DeltaHandler::stopAudioRecording()
{
    m_audioRecorder->stop();
}


void DeltaHandler::dismissAudioRecording()
{
    if (m_audioRecorder) {
        delete m_audioRecorder;
        m_audioRecorder = nullptr;
    }
}


void DeltaHandler::sendAudioRecording(QString filepath)
{
    dc_msg_t* msg = dc_msg_new(currentContext, DC_MSG_VOICE);

    filepath.prepend(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    dc_msg_set_file(msg, filepath.toUtf8().constData(), NULL);
    dc_send_msg(currentContext, currentChatID, msg);
     
    dc_msg_unref(msg);
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

void DeltaHandler::updateCurrentChatMessageCount()
{
    for (size_t i = 0; i < dc_chatlist_get_cnt(currentChatlist); ++i) {
        if (dc_chatlist_get_chat_id(currentChatlist, i) == currentChatID) {
            QAbstractItemModel::dataChanged(index(i, 0), index(i, 0));
        }
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
            // assemble the tag of the message (see sendNotification())
            QString accNumberString;
            accNumberString.setNum(dc_get_id(currentContext));

            QString chatNumberString;
            chatNumberString.setNum(currentChatID);

            QString msgNumberString;
            msgNumberString.setNum(freshMsgs[i][0]);
            removeNotification(accNumberString + "_" + chatNumberString + "_" + msgNumberString);

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
                // assemble the tag of the message (see sendNotification())
                QString accNumberString;
                accNumberString.setNum(dc_get_id(currentContext));

                QString chatNumberString;
                chatNumberString.setNum(currentChatID);

                QString msgNumberString;
                msgNumberString.setNum(tempMsgID);
                removeNotification(accNumberString + "_" + chatNumberString + "_" + msgNumberString);
            }
            dc_msg_unref(tempMsg);
        }
        dc_array_unref(tempArray);
    }
    // notify the view about changes in the model
    updateCurrentChatMessageCount();
}


void DeltaHandler::changedContacts()
{
    if (currentChatlist) {
        beginResetModel();
        dc_chatlist_unref(currentChatlist);
        if (m_query == "") {
            currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
        } else {
            currentChatlist = dc_get_chatlist(currentContext, 0, m_query.toUtf8().constData(), 0);
        }
        endResetModel();
    }
}


void DeltaHandler::chatViewIsClosed()
{
    chatmodelIsConfigured = false;
    emit chatViewClosed();
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
        chatID = dc_chatlist_get_chat_id(currentChatlist, myindex);
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
        chatID = dc_chatlist_get_chat_id(currentChatlist, myindex);
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
}


void DeltaHandler::createNotification(QString summary, QString body, QString tag, QString icon)
{
    qDebug() << "DeltaHandler::createNotification(): creating tag " << tag;
    qDebug() << "DeltaHandler::createNotification(): icon is " << icon;
    QDBusConnection bus = QDBusConnection::sessionBus();

    QString appid("deltatouch.lotharketterer_deltatouch");
    QString path;
    QDBusMessage message;

    path = "/com/lomiri/Postal/deltatouch_2elotharketterer";
    message = QDBusMessage::createMethodCall("com.lomiri.Postal", path, "com.lomiri.Postal", "Post");

    // replace_tag doesn't work, maybe it's positioned wrongly?
    QString mynotif("{\"message\": \"foobar\", \"notification\":{\"tag\": \"" + tag + "\", \"card\": {\"summary\": \"" + summary + "\", \"body\": \"" + body + "\", \"popup\": true, \"persist\": true, \"icon\": \"" + icon + "\"}, \"sound\": true, \"vibrate\": {\"pattern\": [200], \"duration\": 200, \"repeat\": 1 }}}");

    message << appid << mynotif;
    bus.send(message);
//    QDBusPendingCall pcall = bus.asyncCall(message);
//    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);
//    connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this, SLOT(setCounterFinished(QDBusPendingCallWatcher*)));
    
    if (m_lastTag != "" && m_aggregateNotifications) {
        removeNotification(m_lastTag);
    }
    m_lastTag = tag;
    settings->setValue("settingsLastTag", m_lastTag);
}

void DeltaHandler::removeNotification(QString tag)
{
    qDebug() << "DeltaHandler::removeNotification(): removing tag " << tag;
    // remove the notification with m_lastTag as default
    if (tag == "") {
        tag = m_lastTag;
    }

    QDBusConnection bus = QDBusConnection::sessionBus();

    QString appid("deltatouch.lotharketterer_deltatouch");
    QString path;
    QDBusMessage message;

    if (QSysInfo::productVersion() == "16.04") {
        path = "/com/ubuntu/Postal/deltatouch_2elotharketterer";
        message = QDBusMessage::createMethodCall("com.ubuntu.Postal", path, "com.ubuntu.Postal", "ClearPersistent");
    } else {
        path = "/com/lomiri/Postal/deltatouch_2elotharketterer";
        message = QDBusMessage::createMethodCall("com.lomiri.Postal", path, "com.lomiri.Postal", "ClearPersistent");
    }

    message << appid << tag;
    bus.send(message);
//    QDBusPendingCall pcall = bus.asyncCall(message);
//    QDBusPendingCallWatcher *watcher = new QDBusPendingCallWatcher(pcall, this);
//    connect(watcher, SIGNAL(finished(QDBusPendingCallWatcher*)), this, SLOT(setCounterFinished(QDBusPendingCallWatcher*)));

}


void DeltaHandler::contextSetupTasks()
{
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
            qDebug() << "DeltaHandler::contextSetupTasks(): ERROR obtaining the chat ID for the unread msg ID " << tempMsg;
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
    if (m_hasConfiguredAccount && currentChatlist) {

        QVector<int> roleVector;
        roleVector.append(DeltaHandler::ChatIsMutedRole);

        for (size_t i = 0; i < dc_chatlist_get_cnt(currentChatlist); ++i) {
            emit dataChanged(index(i, 0), index(i, 0), roleVector);
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

    if (m_hasConfiguredAccount && currentChatlist) {
        beginResetModel();

        dc_chatlist_unref(currentChatlist);

        // if the query is empty, need to pass NULL instead of empty string
        if (m_query == "") {
            if (currentChatID == DC_CHAT_ID_ARCHIVED_LINK) {
                currentChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, NULL, 0);
            } else {
                currentChatlist = dc_get_chatlist(currentContext, 0, NULL, 0);
            }
        } else {
            if (currentChatID == DC_CHAT_ID_ARCHIVED_LINK) {
                currentChatlist = dc_get_chatlist(currentContext, DC_GCL_ARCHIVED_ONLY | DC_GCL_ADD_ALLDONE_HINT, m_query.toUtf8().constData(), 0);
            } else {
                currentChatlist = dc_get_chatlist(currentContext, 0, m_query.toUtf8().constData(), 0);
            }
        }

        endResetModel();
    }
}
