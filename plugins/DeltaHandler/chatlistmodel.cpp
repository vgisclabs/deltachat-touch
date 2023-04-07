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

#include "chatlistmodel.h"
//#include <unistd.h> // for sleep

ChatlistModel::ChatlistModel(QObject* parent)
    : QAbstractListModel(parent), currentContext {nullptr}, currentChatlist {nullptr}, m_query {""}
{
}


ChatlistModel::~ChatlistModel()
{
    if (currentChatlist) {
        dc_chatlist_unref(currentChatlist);
    }

}


int ChatlistModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);

    if (currentChatlist) {
        return dc_chatlist_get_cnt(currentChatlist);
    }
    else {
        return 0;
    }
}


QHash<int, QByteArray> ChatlistModel::roleNames() const
{
    QHash<int, QByteArray> roles;

    roles[ChatnameRole] = "chatname";
    roles[MsgPreviewRole] = "msgPreview";
    roles[TimestampRole] = "timestamp";
//    roles[StateRole] = "state";
    roles[ChatPicRole] = "chatPic";
//    roles[IsContactRequestRole] = "isContactRequest";
    roles[AvatarColorRole] = "avatarColor";
    roles[AvatarInitialRole] = "avatarInitial";
//    roles[ChatIsMutedRole] = "chatIsMuted";
//    roles[NewMsgCountRole] = "newMsgCount";
    return roles;
}


QVariant ChatlistModel::data(const QModelIndex &index, int role) const
{
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
        case ChatlistModel::ChatnameRole:
            tempText = dc_chat_get_name(tempChat); 
            tempQString = tempText;
            retval = tempQString;
            break;
            
        case ChatlistModel::MsgPreviewRole:
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

        case ChatlistModel::ChatPicRole:
            tempText = dc_chat_get_profile_image(tempChat);
            tempQString = tempText;
            tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
            retval = tempQString;
            break;

        case ChatlistModel::TimestampRole:
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

//        case ChatlistModel::IsContactRequestRole:
//            if (dc_chat_is_contact_request(tempChat)) {
//                retval = true;
//            } else {
//                retval = false;
//            }
//            break;

        case ChatlistModel::AvatarColorRole:
            tempColor = dc_chat_get_color(tempChat);
            // doesn't work as it won't take care of leading zeros
            //tempQString = QString::number(tempColor, 16);
            tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
            tempQString = tempQColor.name();
            retval = tempQString;
            break;

        case ChatlistModel::AvatarInitialRole:
            tempText = dc_chat_get_name(tempChat); 
            tempQString = tempText;
            if (tempQString == "") {
                tempQString = "#";
            } else {
               tempQString = QString(tempQString.at(0)).toUpper(); 
            }
            retval = tempQString;
            break;

//        case ChatlistModel::ChatIsMutedRole:
//            if (dc_chat_is_muted(tempChat)) {
//                retval = true;
//            } else {
//                retval = false;
//            }
//
//            break;

//        case ChatlistModel::NewMsgCountRole:
//            retval = dc_get_fresh_msg_cnt(currentContext, tempChatID);
//            break;

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


void ChatlistModel::configure(dc_context_t* context, int flagsForChatlist)
{
    currentContext = context;
    m_flagsForChatlist = flagsForChatlist;

    currentChatlist = dc_get_chatlist(currentContext, m_flagsForChatlist, NULL, 0);
}


uint32_t ChatlistModel::getChatID(int myindex)
{
    if(myindex < 0 || myindex >= static_cast<int>(dc_chatlist_get_cnt(currentChatlist))) {
        qDebug() << "ChatlistModel::getChatID: ERROR: index out of bounds";
        return 0;
    }

    if (currentChatlist) {
        return dc_chatlist_get_chat_id(currentChatlist, myindex);
    } else {
        qDebug() << "ChatlistModel::getChatID: ERROR: chatlist is not set";
        return 0;
    }

}

void ChatlistModel::updateQuery(QString query) {
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

    beginResetModel();
    dc_chatlist_unref(currentChatlist);
    
    if (m_query == "") {
        currentChatlist = dc_get_chatlist(currentContext, m_flagsForChatlist, NULL, 0);

    } else {
        const char* query_cstring = m_query.toStdString().c_str();
        currentChatlist = dc_get_chatlist(currentContext, m_flagsForChatlist, query_cstring, 0);
    }

    endResetModel();
}

//    qRegisterMetaType<uint32_t>("uint32_t");
//    //qRegisterMetaType<size_t>("size_t");
//
//    // Must use QStandardPaths::AppConfigLocation to get the config dir. With
//    // QStandardPaths::ConfigLocation, we just get /home/phablet/.config
//    QString configdir(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation));
//    qDebug() << "Config directory set to: " << configdir;
//
//    settings = new QSettings("deltatouch.lotharketterer", "deltatouch.lotharketterer");
//
//    if (!QFile::exists(configdir)) {
//        qDebug() << "Config directory not existing, creating it now";
//        QDir tempdir;
//        bool success = tempdir.mkpath(configdir);
//        if (success) {
//            qDebug() << "Config directory successfully created";
//        }
//        else {
//            qDebug() << "Could not create config directory, exiting";
//            exit(1);
//        }
//    }
//    m_chatmodel = new ChatModel();
//    // TODO: should be something like chatIsCurrentlyViewed or
//    // similar because the only time the variable is used is
//    // when a new message arrives. Actions to do upon arrival of
//    // a new message depends on whether the corresponding chat is
//    // currently shown to the user.
//    // Also, the page that shows the chat needs to set it to false
//    // when the page is destroyed.
//    chatmodelIsConfigured = false;
//
//    m_accountsmodel = new AccountsModel();
//
//    m_contactsmodel = new ContactsModel();
//
//    configdir.append("/accounts/");  
//    qDebug() << "Config directory set to: " << configdir;
//    // Qt documentation for QString:
//    // [...] you can pass a QString to a function that takes a const char *
//    // argument using the qPrintable() macro which returns the given QString
//    // as a const char *. This is equivalent to calling
//    // <QString>.toLocal8Bit().constData().
//    //
//    // Also possible: <QString>.toStdString().c_str()
//    //
//    // TODO unref the accounts somewhen later? => done in the destructor
//    allAccounts = dc_accounts_new(NULL, qPrintable(configdir));
//
//    if (!allAccounts) {
//        qDebug() << "ChatlistModel::DeltaHander: Fatal error trying to create account manager.";
//        exit(1);
//    }
//
//    m_accountsmodel->configure(allAccounts, this);
//
//    size_t noOfAccounts = m_accountsmodel->rowCount(QModelIndex());
//
//    qDebug() << "DeltaHander::DeltaHander: Found " << noOfAccounts << " account(s)";
//
//
//    eventThread = new EmitterThread();
//    eventThread->setAccounts(allAccounts);
//
//    bool connectSuccess = connect(eventThread, SIGNAL(newMsg(uint32_t, int, int)), this, SLOT(newMessage(uint32_t, int, int)));
//    if (!connectSuccess) {
//        qDebug() << "ChatlistModel::ChatlistModel: Could not connect signal newMsg to slot newMessage";
//        exit(1);
//    }
//
//    connectSuccess = connect(eventThread, SIGNAL(msgsChanged(uint32_t, int, int)), this, SLOT(newMessage(uint32_t, int, int)));
//    if (!connectSuccess) {
//        qDebug() << "ChatlistModel::ChatlistModel: Could not connect signal msgsChanged to slot newMessage";
//        exit(1);
//    }
//
//    connectSuccess = connect(eventThread, SIGNAL(msgRead(uint32_t, int, int)), this, SLOT(messageReadByRecipient(uint32_t, int, int)));
//    if (!connectSuccess) {
//        qDebug() << "ChatlistModel::ChatlistModel: Could not connect signal msgRead to slot messageReadByRecipient";
//        exit(1);
//    }
//
//    connectSuccess = connect(eventThread, SIGNAL(configureProgress(int, QString)), this, SLOT(progressEvent(int, QString)));
//    if (!connectSuccess) {
//        qDebug() << "ChatlistModel::ChatlistModel: Could not connect signal configureProgress to slot progressEvent";
//        exit(1);
//    }
//
//    connectSuccess = connect(eventThread, SIGNAL(imexProgress(int)), this, SLOT(imexProgressReceiver(int)));
//    if (!connectSuccess) {
//        qDebug() << "ChatlistModel::ChatlistModel: Could not connect signal imexProgress to slot imexProgressReceiver";
//        exit(1);
//    }
//
//    connectSuccess = connect(m_contactsmodel, SIGNAL(chatCreationSuccess(uint32_t)), this, SLOT(chatCreationReceiver(uint32_t)));
//    if (!connectSuccess) {
//        qDebug() << "ChatlistModel::ChatlistModel: Could not connect signal chatCreationSuccess to slot chatCreationReceiver";
//        exit(1);
//    }
//
//    connectSuccess = connect(m_chatmodel, SIGNAL(messageMarkedSeen()), this, SLOT(updateCurrentChatMessageCount()));
//    if (!connectSuccess) {
//        qDebug() << "ChatlistModel::ChatlistModel: Could not connect signal messageMarkedSeen to slot updateCurrentChatMessageCount";
//        exit(1);
//    }
//
//    connectSuccess = connect(m_chatmodel, SIGNAL(markedAllMessagesSeen()), this, SLOT(resetCurrentChatMessageCount()));
//    if (!connectSuccess) {
//        qDebug() << "ChatlistModel::ChatlistModel: Could not connect signal markedAllMessagesSeen to slot resetCurrentChatMessageCount";
//        exit(1);
//    }
//
//    connectSuccess = connect(this, SIGNAL(messageRead(int)), m_chatmodel, SLOT(messageReadSlot(int)));
//    if (!connectSuccess) {
//        qDebug() << "ChatlistModel::ChatlistModel: Could not connect signal messageRead to slot messageReadSlot";
//        exit(1);
//    }
//
//    eventThread->start();
//
//    if (noOfAccounts == 0){
//        qDebug() << "ChatlistModel::ChatlistModel: No account found";
//        m_hasConfiguredAccount = false;
//        currentContext = nullptr;
//    }
//    else {
//        currentContext = dc_accounts_get_selected_account(allAccounts);
//        // TODO: check whether m_contactsmodel is updated each time currentContext changes
//        // probably set currentContext via a separate function?
//        m_contactsmodel->updateContext(currentContext);
//
//        if (dc_is_configured(currentContext)) {
//            m_hasConfiguredAccount = true;
//        }
//        else {
//            qDebug() << "ChatlistModel::ChatlistModel: Selected account is not configured, searching for another account..";
//            m_hasConfiguredAccount = false;
//
//            // TODO: Is it possible that the selected account is
//            // unconfigured, but a aconfigured account exists?
//            dc_array_t* tempArray = dc_accounts_get_all(allAccounts);
//
//            for (size_t i = 0; i < noOfAccounts; ++i) {
//                uint32_t tempAccID = dc_array_get_id(tempArray, i);
//                tempContext = dc_accounts_get_account(allAccounts, tempAccID);
//                if (dc_is_configured(tempContext)) {
//                    m_hasConfiguredAccount = true;
//                    // TODO: does the signal have to be emitted?
//                    emit hasConfiguredAccountChanged();
//                    dc_accounts_select_account(allAccounts, tempAccID);
//
//                    dc_context_unref(currentContext);
//                    currentContext = tempContext;
//                    tempContext = nullptr;
//                    m_contactsmodel->updateContext(currentContext);
//
//                    qDebug() << "ChatlistModel::ChatlistModel: ...found one!";
//                    break;
//                }
//                dc_context_unref(tempContext);
//                tempContext = nullptr;
//            } // for
//            dc_array_unref(tempArray);
//
//            if (!m_hasConfiguredAccount) {
//                qDebug() << "ChatlistModel::ChatlistModel: ...did not find one.";
//            }
//        } // else of if(dc_is_configured(currentContext)
//
//        if (m_hasConfiguredAccount) {
//            currentChatlist = dc_get_chatlist(currentContext, 0, 0, 0);
//        }
//    } // else of if(noOfAccounts == 0)
//}
//
//ChatlistModel::~ChatlistModel()
//{
//    dc_accounts_stop_io(allAccounts);
//
//    if (currentChatlist) {
//        dc_chatlist_unref(currentChatlist);
//    }
//
//    if (currentContext) {
//        dc_context_unref(currentContext);
//    }
//
//    if (tempContext) {
//        dc_context_unref(tempContext);
//    }
//
//    if (allAccounts) {
//        dc_accounts_unref(allAccounts);
//    }
//
//    delete eventThread;
//    delete m_accountsmodel;
//    delete m_chatmodel;
//    delete m_contactsmodel;
//}
//
//int ChatlistModel::rowCount(const QModelIndex &parent) const
//{
//    Q_UNUSED(parent);
//    // return our data count
//    if (m_hasConfiguredAccount) {
//        return dc_chatlist_get_cnt(currentChatlist);
//    }
//    else {
//        return 0;
//    }
//}
//
//QHash<int, QByteArray> ChatlistModel::roleNames() const
//{
//    QHash<int, QByteArray> roles;
//
//    roles[ChatnameRole] = "chatname";
//    roles[MsgPreviewRole] = "msgPreview";
//    roles[TimestampRole] = "timestamp";
//    roles[StateRole] = "state";
//    roles[ChatPicRole] = "chatPic";
//    roles[IsContactRequestRole] = "isContactRequest";
//    roles[AvatarColorRole] = "avatarColor";
//    roles[AvatarInitialRole] = "avatarInitial";
//    roles[ChatIsMutedRole] = "chatIsMuted";
//    roles[NewMsgCountRole] = "newMsgCount";
//    return roles;
//}
//
//QVariant ChatlistModel::data(const QModelIndex &index, int role) const
//{
//    if (!m_hasConfiguredAccount) {
//        return QVariant();
//    }
//    int row = index.row();
//
//    // If row is out of bounds, an empty QVariant is returned
//    if(row < 0 || row >= static_cast<int>(dc_chatlist_get_cnt(currentChatlist))) {
//        return QVariant();
//    }
//
//    uint32_t tempChatID = dc_chatlist_get_chat_id(currentChatlist, row);
//    dc_chat_t* tempChat = dc_get_chat(currentContext, tempChatID);
//    dc_lot_t* tempLot = dc_chatlist_get_summary(currentChatlist, row, tempChat);
//
//    QString tempQString;
//    QVariant retval;
//    char* tempText {nullptr};
//    uint64_t timestampSecs {0};
//    uint32_t tempColor {0};
//    QDateTime timestampDate;
//    QColor tempQColor;
//
//    switch(role) {
//        case ChatlistModel::ChatnameRole:
//            tempText = dc_chat_get_name(tempChat); 
//            tempQString = tempText;
//            retval = tempQString;
//            break;
//            
//        case ChatlistModel::MsgPreviewRole:
//            // TODO: internationalize text1, so for example, "Me"
//            // will get translated
//            tempText = dc_lot_get_text1(tempLot); 
//
//            if (tempText) {
//                tempQString = tempText;
//                tempQString += ": ";
//                dc_str_unref(tempText);
//            }
//
//            tempText = dc_lot_get_text2(tempLot); 
//            tempQString += tempText;
//            retval = tempQString;
//            break;
//
//        case ChatlistModel::ChatPicRole:
//            tempText = dc_chat_get_profile_image(tempChat);
//            tempQString = tempText;
//            tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
//            retval = tempQString;
//            break;
//
//        case ChatlistModel::TimestampRole:
//            timestampSecs = dc_lot_get_timestamp(tempLot);
//            if (timestampSecs == 0) {
//                tempQString = "n/a";
//                retval = tempQString;
//                break;
//            }
//            timestampDate = QDateTime::fromSecsSinceEpoch(timestampSecs);
//            if (timestampDate.date() == QDate::currentDate()) {
//                tempQString = timestampDate.toString("hh:mm");
//                // TODO: if <option_for_am/pm> ...("hh:mm ap")
//                // => check the QLocale Class
//            }
//            else if (timestampDate.date().daysTo(QDate::currentDate()) < 7) {
//                // TODO: "...hh:mm ap " as above
//                tempQString = timestampDate.toString("ddd hh:mm");
//            }
//            else {
//                tempQString = timestampDate.toString("dd MMM yy" );
//            }
//            retval = tempQString;
//            break;
//
//        case ChatlistModel::IsContactRequestRole:
//            if (dc_chat_is_contact_request(tempChat)) {
//                retval = true;
//            } else {
//                retval = false;
//            }
//            break;
//
//        case ChatlistModel::AvatarColorRole:
//            tempColor = dc_chat_get_color(tempChat);
//            // doesn't work as it won't take care of leading zeros
//            //tempQString = QString::number(tempColor, 16);
//            tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
//            tempQString = tempQColor.name();
//            retval = tempQString;
//            break;
//
//        case ChatlistModel::AvatarInitialRole:
//            tempText = dc_chat_get_name(tempChat); 
//            tempQString = tempText;
//            if (tempQString == "") {
//                tempQString = "#";
//            } else {
//               tempQString = QString(tempQString.at(0)).toUpper(); 
//            }
//            retval = tempQString;
//            break;
//
//        case ChatlistModel::ChatIsMutedRole:
//            if (dc_chat_is_muted(tempChat)) {
//                retval = true;
//            } else {
//                retval = false;
//            }
//
//            break;
//
//        case ChatlistModel::NewMsgCountRole:
//            retval = dc_get_fresh_msg_cnt(currentContext, tempChatID);
//            break;
//
//        default:
//            retval = QString("");
//
//    }
//
//    dc_lot_unref(tempLot);
//    dc_chat_unref(tempChat);
//
//    if (tempText) {
//        dc_str_unref(tempText);
//        tempText = nullptr;
//    }
//
//    return retval;
//
//}
//
//ChatModel* ChatlistModel::chatmodel()
//{
//    return m_chatmodel;
//}
//
//
//AccountsModel* ChatlistModel::accountsmodel()
//{
//    return m_accountsmodel;
//}
//
//
//ContactsModel* ChatlistModel::contactsmodel()
//{
//    return m_contactsmodel;
//}
//
//
//void ChatlistModel::sendAttachment(QString filepath, MsgViewType attachType)
//{
//    // the url handed over by the ContentHub starts with
//    // "file:///home....", so we have to remove the first 7
//    // characters
//    filepath.remove(0, 7);
// 
//    dc_msg_t* msg {nullptr};
//
//    switch (attachType) {
//        case MsgViewType::AudioType:
//            msg = dc_msg_new(currentContext, DC_MSG_AUDIO);
//            break;
//
//        case MsgViewType::FileType:
//            msg = dc_msg_new(currentContext, DC_MSG_FILE);
//            break;
//        
//        case MsgViewType::GifType:
//            msg = dc_msg_new(currentContext, DC_MSG_GIF);
//            break;
//        
//        case MsgViewType::ImageType:
//            msg = dc_msg_new(currentContext, DC_MSG_IMAGE);
//            break;
//        
//        case MsgViewType::StickerType:
//            msg = dc_msg_new(currentContext, DC_MSG_STICKER);
//            break;
//        
//        case MsgViewType::TextType:
//            msg = dc_msg_new(currentContext, DC_MSG_TEXT);
//            break;
//
//        case MsgViewType::VideoType:
//            msg = dc_msg_new(currentContext, DC_MSG_VIDEO);
//            break;
//        
//        case MsgViewType::VideochatInvitationType:
//            msg = dc_msg_new(currentContext, DC_MSG_VIDEOCHAT_INVITATION);
//            break;
//        
//        case MsgViewType::VoiceType:
//            msg = dc_msg_new(currentContext, DC_MSG_VOICE);
//            break;
//
//        case MsgViewType::WebXdcType:
//            msg = dc_msg_new(currentContext, DC_MSG_WEBXDC);
//            break;
//
//        default:
//            msg = dc_msg_new(currentContext, DC_MSG_FILE);
//            break;
//    }
//
//    dc_msg_set_file(msg, filepath.toStdString().c_str(), NULL);
//    dc_send_msg(currentContext, currentChatID, msg);
//     
//    dc_msg_unref(msg);
//}
//
//
//void ChatlistModel::selectChat(int myindex)
//{
//    currentChatID = dc_chatlist_get_chat_id(currentChatlist, myindex);
//}
//
//
//void ChatlistModel::openChat()
//{
//    dc_chat_t* tempChat = dc_get_chat(currentContext, currentChatID);
//    bool contactRequest = dc_chat_is_contact_request(tempChat);
//    dc_chat_unref(tempChat);
//
//    m_chatmodel->configure(currentChatID, currentContext, this, contactRequest);
//    chatmodelIsConfigured = true;
//
//    emit openChatViewRequest();
//}
//
//
//void ChatlistModel::selectAccount(int myindex)
//{
//    dc_array_t* contextArray = dc_accounts_get_all(allAccounts);
//
//    if (myindex < 0 || myindex >= dc_array_get_cnt(contextArray)) {
//        qDebug() << "ChatlistModel::selectAccount: Error: index out of bounds";
//        return;
//    }
//
//    uint32_t accID = dc_array_get_id(contextArray, myindex);
//
//    if (currentContext && accID == dc_get_id(currentContext)) {
//        qDebug() << "ChatlistModel::selectAccount: Selected account already active, doing nothing.";
//        return;
//    }
//
//    beginResetModel();
//
//    if (tempContext) {
//        dc_context_unref(tempContext);
//    }
//
//    int success = dc_accounts_select_account(allAccounts, accID);
//    if (0 == success) {
//        qDebug() << "ChatlistModel::selectAccount: ERROR: dc_accounts_select_account was unsuccessful";
//    }
//
//    tempContext = dc_accounts_get_selected_account(allAccounts);
//
//    if (!dc_is_configured(tempContext)) {
//        qDebug() << "ChatlistModel::selectAccount: trying to select unconfigured account, refusing";
//        dc_context_unref(tempContext);
//        endResetModel();
//        return;
//    }
//
//    if (currentChatlist) {
//        dc_chatlist_unref(currentChatlist);
//    }
//    
//    if (currentContext) {
//        dc_context_unref(currentContext);
//    }
//
//    currentContext = tempContext;
//    tempContext = nullptr;
//    m_contactsmodel->updateContext(currentContext);
//
//    currentChatlist = dc_get_chatlist(currentContext, 0, 0, 0);
//
//    chatmodelIsConfigured = false;
//
//    endResetModel();
//
//    emit accountChanged();
//    
//    dc_array_unref(contextArray);
//}
//
//
//void ChatlistModel::newMessage(uint32_t accID, int chatID, int msgID)
//{
//    uint32_t currentAccID = dc_get_id(currentContext);
//
//    if (currentAccID == accID) {
//        // need to reset the model because
//        // - a chat may have been deleted (chatID would be 0 then)
//        // - a new chat may be present
//        // - one or more new messages may have been received, so
//        //   the new message counter and the message preview may be
//        //   affected.
//        beginResetModel();
//        
//        if (currentChatlist) {
//            dc_chatlist_unref(currentChatlist);
//        }
//        
//        currentChatlist = dc_get_chatlist(currentContext, 0, 0, 0);
//        
//        endResetModel();
//
//        // Have to emit the signal if the chatmodel may be
//        // affected (in case of deletion of a message, chatID
//        // and msgID will be 0).
//        // TODO: Create new signal with more suitable name?
//        if (chatmodelIsConfigured && (currentChatID == chatID || 0 == chatID)) {
//            emit newMsgReceived(msgID);
//        }
//
//    } else { // message(s) for context other than the current one
//        qDebug() << "ChatlistModel::newMessage(): signal newMsg received with accID: " << accID << ", chatID: " << chatID << "msgID: " << msgID;
//    }
//}
//
//
//void ChatlistModel::messageReadByRecipient(uint32_t accID, int chatID, int msgID)
//{
//    uint32_t currentAccID = dc_get_id(currentContext);
//
//    if (currentAccID == accID && currentChatID == chatID && chatmodelIsConfigured) {
//        emit messageRead(msgID);
//    }
//    
//}
//
//
//QString ChatlistModel::chatName()
//{
//    if (chatmodelIsConfigured) {
//        dc_chat_t* tempChat = dc_get_chat(currentContext, currentChatID);
//        char* tempName = dc_chat_get_name(tempChat);
//        QString name = tempName;
//        dc_str_unref(tempName);
//        dc_chat_unref(tempChat);
//        return name;
//    }
//    else return QString();
//}
//
//
//QString ChatlistModel::getCurrentUsername()
//{
//    QString retval;
//    if (currentContext) {
//        char * tempString = dc_get_config(currentContext, "displayname");
//        retval = tempString;
//        dc_str_unref(tempString);
//    }
//    else {
//        retval = "";
//    }
//    return retval;
//}
//
//
//QString ChatlistModel::getCurrentEmail()
//{
//    QString retval;
//    if (currentContext) {
//        char * tempString = dc_get_config(currentContext, "addr");
//        retval = tempString;
//        dc_str_unref(tempString);
//    }
//    else {
//        retval = "";
//    }
//    return retval;
//}
//
//
//QString ChatlistModel::getCurrentProfilePic()
//{
//    QString retval;
//    if (currentContext) {
//        char * tempString = dc_get_config(currentContext, "selfavatar");
//        retval = tempString;
//        dc_str_unref(tempString);
//        if (retval.length() >= QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length()) {
//            retval.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
//        }
//        else {
//            retval = "";
//        }
//    }
//    else {
//        retval = "";
//    }
//    return retval;
//}
//
//
//bool ChatlistModel::hasConfiguredAccount()
//{
//    return m_hasConfiguredAccount;
//}
//
//
//bool ChatlistModel::networkingIsAllowed()
//{
//    return m_networkingIsAllowed;
//}
//
//
//bool ChatlistModel::networkingIsStarted()
//{
//    return m_networkingIsStarted;
//}
//
//
//QString ChatlistModel::getChatName(int myindex)
//{
//    QString tempQString;
//    uint32_t tempChatID = dc_chatlist_get_chat_id(currentChatlist, myindex);
//    dc_chat_t* tempChat = dc_get_chat(currentContext, tempChatID);
//
//    if (tempChat) {
//        char* tempText = dc_chat_get_name(tempChat);
//        tempQString = tempText;
//
//        dc_str_unref(tempText);
//        dc_chat_unref(tempChat);
//    } else {
//        tempQString = "";
//    }
//
//    return tempQString;
//}
//
//
//void ChatlistModel::deleteChat(int myindex)
//{
//    uint32_t tempChatID = dc_chatlist_get_chat_id(currentChatlist, myindex);
//    dc_delete_chat(currentContext, tempChatID);
//}
//
//
//void ChatlistModel::setCurrentConfig(QString key, QString newValue)
//{
//
//    if ("selfavatar" == key) {
//        // have to check for the special case where the
//        // selfavatar should be deleted
//        if ("" == newValue) {
//            int success = dc_set_config(currentContext, key.toStdString().c_str(), NULL);
//
//            if (!success) {
//                qDebug() << "ChatlistModel::setCurrentConfig: ERROR: Setting key " << key << " to \"\" was not successful.";
//            }
// 
//            emit accountChanged();
//            return;
//        }
//        else {
//            // the url handed over by the ContentHub starts with
//            // "file:///home....", so we have to remove the first 7
//            // characters
//            newValue.remove(0, 7);
//        }
//    }
//
//    int success = dc_set_config(currentContext, key.toStdString().c_str(), newValue.toStdString().c_str());
//
//    if (!success) {
//        qDebug() << "ChatlistModel::setCurrentConfig: ERROR: Setting key " << key << " to " << newValue << " was not successful.";
//    }
// 
//    // TODO: emit only if profile pic or displayname changed?
//    emit accountChanged();
////    emit updatedAccountConfig(dc_get_id(currentContext));
//}
//
//
//void ChatlistModel::setTempContext(uint32_t accID)
//{
//    if (tempContext) {
//        qDebug() << "ChatlistModel::configureAccount: ERROR: tempContext is unexpectedly set";
//        dc_context_unref(tempContext);
//    }
//    
//    // If the currently active account (i.e., the one of currentContext)
//    // is selected for configuration, tempContext will be set to
//    // currentContext. Needs to be considered when unsetting
//    // tempContext again in
//    // - unrefTempContext()
//    // - progressEvent()
//    if (currentContext) {
//        uint32_t currentAccID = dc_get_id(currentContext);
//
//        if (accID == currentAccID) {
//            tempContext = currentContext;
//        } else {
//            tempContext = dc_accounts_get_account(allAccounts, accID);
//        }
//    } else {
//        tempContext = dc_accounts_get_account(allAccounts, accID);
//    }
//}
//
//
//// TODO: rename to getTempContextConfig or something to make 
//// distinguishable from getConfig and setConfig
//QString ChatlistModel::getTempContextConfig(QString key)
//{
//    QString retval;
//
//    if (!tempContext) {
//        qDebug() << "ChatlistModel::getTempContextConfig: ERROR: tempContext is not set";
//        retval = "";
//    }
//    else {
//        char* tempText = dc_get_config(tempContext, key.toStdString().c_str());
//        retval = tempText;
//        dc_str_unref(tempText);
//    }
//
//    if ("mail_pw" == key || "send_pw" == key || "socks5_password" == key) {
//        qDebug() << "ChatlistModel::getTempContextConfig() called for " << key << ", returning " << "*****";
//    } else {
//        qDebug() << "ChatlistModel::getTempContextConfig() called for " << key << ", returning " << retval;
//    }
//    return retval;
//}
//
//
//void ChatlistModel::setTempContextConfig(QString key, QString val)
//{
//    QString origVal = getTempContextConfig(key);
//    if (origVal == val) {
//
//        if ("mail_pw" == key || "send_pw" == key || "socks5_password" == key) {
//            qDebug() << "ChatlistModel::setTempContextConfig: Not setting key " << key << " to ***** as it has not changed.";
//        } else {
//            qDebug() << "ChatlistModel::setTempContextConfig: Not setting key " << key << " to " << val << " as it has not changed.";
//        }
//
//    } else {
//        dc_set_config(tempContext, key.toStdString().c_str(), val.toStdString().c_str());
//
//        if ("mail_pw" == key || "send_pw" == key || "socks5_password" == key) {
//            qDebug() << "ChatlistModel::setTempContextConfig: Setting " << key << " to " << "*****";
//        } else {
//            qDebug() << "ChatlistModel::setTempContextConfig: Setting " << key << " to " << val;
//        }
//    }
//}
//
//
//void ChatlistModel::prepareTempContextConfig() {
//    // If tempContext is set, either an existing account has been
//    // selected for changing the configuration or the user encountered
//    // an error while configuring a new account and is still in the
//    // mask to enter addr and password and such, and is presumably
//    // correcting these entries, so we will change the configuration
//    // of this context.
//    //
//    // (Note that tempContext is set to nullptr
//    // - after a successful configuration by the slot progressEvent
//    //   of this class
//    // - when leaving the addEmailAccount page as this page will
//    //   emit the signal "leavingAddEmailPage", which is connected
//    //   to the slot unrefTempContext()
//    if (!tempContext) {
//        uint32_t accID = dc_accounts_add_account(allAccounts);
//        tempContext = dc_accounts_get_account(allAccounts, accID);
//        m_configuringNewAccount = true;
//    }
//    else {
//        m_configuringNewAccount = false;
//    }
//}
//
//void ChatlistModel::configureTempContext() {
//    // "During configuration IO must not be started"
//    m_networkingIsAllowed = false;
//    emit networkingIsAllowedChanged();
//
//    dc_configure(tempContext);
//
//    // Acc to DC documentation, dc_configure returns
//    // immediately, but the configuration process may
//    // take a while. So we cannot allow networking here.
//    // Instead, it has to be allowed once the configuration process
//    // is finished, i.e. in progressEvent()
//}
//
//
//void ChatlistModel::progressEvent(int perMill, QString errorMsg)
//{
//
//    emit progressEventReceived(perMill, errorMsg);
//    if (perMill == 0) {
//        // A newly added account is automatically the selected account
//        // as per documentation for dc_accounts_add_account(). But if
//        // the new account could not be successfully configured, we
//        // shouldn't switch to it. Probably this account should also
//        // not be selected then, especially considering that the app
//        // will try to choose the unconfigured account upon the next
//        // startup. It will find it unconfigured, and will then just
//        // select the first configured account. This may be a
//        // different one that the one that was previously active for
//        // the user. To prevent that, we re-select the currently
//        // active (and configured) account.
//
//        if (currentContext) {
//            uint32_t tempAccID = dc_get_id(currentContext);
//            dc_accounts_select_account(allAccounts, tempAccID);
//        }
//        if (m_configuringNewAccount) {
//            emit newUnconfiguredAccount(); 
//        }
//        else {
//            emit updatedAccountConfig(dc_get_id(tempContext));
//        }
//
//        // allow networking again, see configureTempContext()
//        m_networkingIsAllowed = true;
//        emit networkingIsAllowedChanged();
//
//    } else if (perMill == 1000) {
//        beginResetModel();
//
//        if (currentChatlist) {
//            dc_chatlist_unref(currentChatlist);
//        }
//        
//        // If the user has selected the currently active account
//        // (= currentContext) for re-configuration, setTempContext() has
//        // set tempContext = currentContext. So currentContext
//        // must only be unref'd if it is != tempContext.
//        if (currentContext && currentContext != tempContext) {
//            dc_context_unref(currentContext);
//        }
//
//        // checking for the special case where tempContext ==
//        // currentContext (see comment above) is not absolutely
//        // necessary for the following sequences, so we skip it
//        // to avoid making the code unnecessarily complicated - it's
//        // too complicated already :-(
//        currentContext = tempContext;
//        tempContext = nullptr;
//        m_contactsmodel->updateContext(currentContext);
//
//        currentChatlist = dc_get_chatlist(currentContext, 0, 0, 0);
//
//        chatmodelIsConfigured = false;
//
//        if (!m_hasConfiguredAccount) {
//            m_hasConfiguredAccount = true;
//            emit hasConfiguredAccountChanged();
//        }
//        endResetModel();
//        // TODO: correct order of actions in lines above + below?
//        if (m_configuringNewAccount) {
//            emit newConfiguredAccount();
//            emit accountChanged();
//        }
//        else {
//            emit updatedAccountConfig(dc_get_id(currentContext));
//            emit accountChanged();
//        }
//
//        // allow networking again, see configureTempContext()
//        m_networkingIsAllowed = true;
//        emit networkingIsAllowedChanged();
//    }
//}
//
//
//void ChatlistModel::imexProgressReceiver(int perMill)
//{
//    emit imexEventReceived(perMill);
//    if (perMill == 0) {
//        // If the backup import was not successful, re-select the
//        // currently active (and configured) account and delete the
//        // new account that has been prepared for the importing
//        // process.
//        if (currentContext) {
//            uint32_t tempAccID = dc_get_id(currentContext);
//            dc_accounts_select_account(allAccounts, tempAccID);
//        }
//        
//        if (tempContext) {
//            int tempAccID = dc_get_id(tempContext);
//            dc_context_unref(tempContext);
//            tempContext = nullptr;
//            dc_accounts_remove_account(allAccounts, tempAccID);
//        }
//        m_networkingIsAllowed = true;
//        emit networkingIsAllowedChanged();
//    } else if (perMill == 1000) {
//        beginResetModel();
//
//        if (currentChatlist) {
//            dc_chatlist_unref(currentChatlist);
//        }
//        
//        if (currentContext) {
//            dc_context_unref(currentContext);
//        }
//
//        currentContext = tempContext;
//        tempContext = nullptr;
//        m_contactsmodel->updateContext(currentContext);
//
//        currentChatlist = dc_get_chatlist(currentContext, 0, 0, 0);
//
//        chatmodelIsConfigured = false;
//
//        if (!m_hasConfiguredAccount) {
//            m_hasConfiguredAccount = true;
//            emit hasConfiguredAccountChanged();
//        }
//        endResetModel();
//
//        emit newConfiguredAccount();
//        emit accountChanged();
//        m_networkingIsAllowed = true;
//        emit networkingIsAllowedChanged();
//    }
//}
//
//
//void ChatlistModel::chatCreationReceiver(uint32_t chatID)
//{
//    // Resetting model, re-loading currentChatlist not
//    // needed because the emitter emits the signal
//    // newMsg which is connected to the slot newMessage.
//    // The slot will take care of adding the new
//    // chat to the chatlist.
//     
//    // NOT calling selectChat(int) as the parameter of
//    // this method is the array index, not the chatID
//    currentChatID = chatID; 
//    openChat();
//}
//
//
//void ChatlistModel::unrefTempContext()
//{
//    if (tempContext != currentContext) {
//        dc_context_unref(tempContext);
//        tempContext = nullptr;
//    } else {
//        tempContext = nullptr;
//    }
//}
//
//
//void ChatlistModel::unselectAccount(uint32_t accIDtoUnselect)
//{
//    if (dc_get_id(currentContext) != accIDtoUnselect) {
//        qDebug() << "ChatlistModel::unselectAccount: Being called to unselect account id " << accIDtoUnselect << ", but it is already not the selected account.";
//        return;
//    }
//
//    // Fälle zu berücksichtigen:
//    // ok - es gibt nur einen Account, dieser ist configured und wird gelöscht
//    // ok - es gibt nur einen Account, dieser ist unconfigured und wird gelöscht
//    // - es gibt keinen configured account (dann ist ein unconfigured
//    // account der selected account, der jetzt gelöscht wird)
//    // - es gibt einen configured account, dieser wird gelöscht
//    // - es gibt mehrere configured accounts
//    //
//    beginResetModel();
//    
//    dc_array_t* tempArray = dc_accounts_get_all(allAccounts);
//    size_t noOfAccounts = m_accountsmodel->rowCount(QModelIndex());
//
//    if (1 == noOfAccounts) {
//        dc_context_unref(currentContext);
//        currentContext = nullptr;
//        if (m_hasConfiguredAccount) {
//            m_hasConfiguredAccount = false;
//            emit hasConfiguredAccountChanged();
//        }
//    }
//    else { // more accounts than one are present
//        if (tempContext) {
//            qDebug() << "ChatlistModel::unselectAccount: tempContext was set, will now be unref'd.";
//            dc_context_unref(tempContext);
//            tempContext = nullptr;
//        }
//
//        bool foundConfiguredAccount {false};
//        uint32_t accountToSwitchTo {0};
//
//        for (size_t i = 0; i < noOfAccounts; ++i) {
//            uint32_t tempAccID = dc_array_get_id(tempArray, i);
//            // cannot choose the account that is to be unselected
//            if (accIDtoUnselect == tempAccID) {
//                continue;
//            }
//
//            accountToSwitchTo = tempAccID;
//            tempContext = dc_accounts_get_account(allAccounts, tempAccID);
//
//            if (dc_is_configured(tempContext)) {
//                // The first configured account is chosen. tempContext
//                // remains set in this case.
//                foundConfiguredAccount = true;
//                break;
//            }
//
//            dc_context_unref(tempContext);
//        } // for
//
//        // TODO check return value
//        dc_accounts_select_account(allAccounts, accountToSwitchTo);
//
//        if (currentChatlist) {
//            dc_chatlist_unref(currentChatlist);
//            currentChatlist = nullptr;
//        }
//
//        if (foundConfiguredAccount) {
//            qDebug() << "ChatlistModel::unselectAccount: Choosing configured account " << accountToSwitchTo << "as new selected account.";
//            dc_context_unref(currentContext);
//            currentContext = tempContext;
//            m_contactsmodel->updateContext(currentContext);
//            currentChatlist = dc_get_chatlist(currentContext, 0, 0, 0);
//        }
//        else {
//            qDebug() << "ChatlistModel::unselectAccount: No configured account available. Choosing unconfigured account " << accountToSwitchTo << "as new selected account.";
//            // If no configured account was found, tempContext is already unref'd
//            dc_context_unref(currentContext);
//            currentContext = dc_accounts_get_account(allAccounts, accountToSwitchTo);
//            m_contactsmodel->updateContext(currentContext);
//        }
//
//        // setting tempContext to nullptr here to avoid having to do
//        // so in the loop above.
//        tempContext = nullptr;
//
//        if (foundConfiguredAccount != m_hasConfiguredAccount) {
//            m_hasConfiguredAccount = !m_hasConfiguredAccount;
//            emit hasConfiguredAccountChanged();
//        }
//            //chatmodelIsConfigured = false; // should be set by the
//            //chatview page, see comment on introduction of this
//            //variable
//
//    } // else if (1 == noOfAccounts9
//
//    dc_array_unref(tempArray);
//        
//    endResetModel();
//    emit accountChanged();
//}
//
//
//void ChatlistModel::start_io()
//{
//    if (!m_networkingIsStarted) {
//        dc_accounts_start_io(allAccounts);
//        m_networkingIsStarted = true;
//    }
//    else {
//        qDebug() << "ChatlistModel::start_io(): ERROR: start_io() called, but m_networkingIsStarted is true";
//    }
//}
//
//
//void ChatlistModel::stop_io()
//{
//    if (m_networkingIsStarted) {
//        dc_accounts_stop_io(allAccounts);
//        m_networkingIsStarted = false;
//    }
//    else {
//        qDebug() << "ChatlistModel::stop_io(): ERROR: stop_io() called, but m_networkingIsStarted is false";
//    }
//}
//
//
//bool ChatlistModel::isBackupFile(QString filePath)
//{
//    // the url handed over by the ContentHub starts with
//    // "file:///home....", so we have to remove the first 7
//    // characters
//    filePath.remove(0, 7);
//
//    if (!filePath.contains('/')) {
//        qDebug() << "ChatlistModel::isBackupFile: Looks like the passed path is no path from ContentHub: No / found in string.";
//        return false;
//    }
//
//    QString fileName = filePath.section('/', -1);
//    QString purePath = filePath;
//    purePath.resize(filePath.length() - fileName.length());
//    
//    if (tempContext) {
//        qDebug() << "ChatlistModel::isBackupFile: tempContext is unexpectedly set, will now be unref'd";
//        dc_context_unref(tempContext);
//    }
//
//    uint32_t accID = dc_accounts_add_account(allAccounts);
//    
//    if (0 == accID) {
//        qDebug() << "ChatlistModel::isBackupFile: Could not create new account.";
//        return false;
//    }
//
//    tempContext = dc_accounts_get_account(allAccounts, accID);
//
//    char* tempText = dc_imex_has_backup(tempContext, purePath.toStdString().c_str());
//    QString tempFile = tempText;
//    
//    bool isBackup;
//
//    if (tempFile == filePath) {
//        isBackup = true;
//        qDebug() << "ChatlistModel::isBackupFile: yes, it is a backup file";
//    } else {
//        isBackup = false;
//        dc_context_unref(tempContext);
//        tempContext = nullptr;
//        dc_accounts_remove_account(allAccounts, accID);
//        qDebug() << "ChatlistModel::isBackupFile: no, it is not a backup file";
//    }
//
//    dc_str_unref(tempText);
//
//    return isBackup;
//}
//
//
//void ChatlistModel::importBackup(QString filePath)
//{
//    // the url handed over by the ContentHub starts with
//    // "file:///home....", so we have to remove the first 7
//    // characters
//    filePath.remove(0, 7);
//    qDebug() << "ChatlistModel::importBackup: path to backup file is: " << filePath;
//    m_networkingIsAllowed = false;
//    // not emitting signal, but stopping io directly
//    stop_io();
//    // TODO: implement password for importing backup
//    dc_imex(tempContext, DC_IMEX_IMPORT_BACKUP, filePath.toStdString().c_str(), NULL);
//}
//
//
//void ChatlistModel::chatAcceptContactRequest()
//{
//    dc_accept_chat(currentContext, currentChatID);
//    m_chatmodel->acceptChat();
//    emit chatIsContactRequestChanged();
//}
//
//
//void ChatlistModel::chatDeleteContactRequest()
//{
//    dc_delete_chat(currentContext, currentChatID);
//}
//
//
//void ChatlistModel::chatBlockContactRequest()
//{
//    dc_block_chat(currentContext, currentChatID);
//}
//
//
//bool ChatlistModel::isExistingChat(uint32_t chatID) {
//    if (!currentChatlist) {
//        qDebug() << "ChatlistModel::isExistingChat(): ERROR: currentChatlist is not set";
//        return false;
//    }
//    for (size_t i = 0; i < dc_chatlist_get_cnt(currentChatlist); ++i) {
//        if (dc_chatlist_get_chat_id(currentChatlist, i) == chatID) {
//           return true; 
//        }
//    }
//    return false;
//}
//
//
//bool ChatlistModel::chatIsContactRequest()
//{
//    return m_chatmodel->chatIsContactRequest();
//}
//
///* ========================================================
//* =================== Profile editing ====================
//* ======================================================== */
//
//QString ChatlistModel::getCurrentSignature()
//{
//    char* tempText = dc_get_config(currentContext, "selfstatus");
//    QString tempQString = tempText;
//    dc_str_unref(tempText);
//    return tempQString;
//}
//
//
//void ChatlistModel::startProfileEdit()
//{
//    m_changedProfileValues.clear();
//}
//
//
//void ChatlistModel::setProfileValue(QString key, QString newValue)
//{
//    m_changedProfileValues[key] = newValue;
//    if ("selfavatar" == key && newValue != "") {
//        // the url handed over by the ContentHub starts with
//        // "file:///home....", so we have to remove the first 7
//        // characters
//        newValue.remove(0, 7);
//        newValue.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length());
//        emit newTempProfilePic(newValue);
//    }
//}
//
//
//void ChatlistModel::finalizeProfileEdit()
//{
//    QHashIterator<QString, QString> i(m_changedProfileValues);
//
//    while (i.hasNext()) {
//        i.next();
//        setCurrentConfig(i.key(), i.value());
//    }
//}
///* ================ End Profile editing ================== */
//
//
//void ChatlistModel::updateCurrentChatMessageCount()
//{
//    for (size_t i = 0; i < dc_chatlist_get_cnt(currentChatlist); ++i) {
//        if (dc_chatlist_get_chat_id(currentChatlist, i) == currentChatID) {
//            QAbstractItemModel::dataChanged(index(i, 0), index(i, 0));
//        }
//    }
//}
//
//
//void ChatlistModel::resetCurrentChatMessageCount()
//{
//    // Currently this call is sufficient
//    updateCurrentChatMessageCount();
//}
//
//
//void ChatlistModel::chatViewIsClosed()
//{
//    chatmodelIsConfigured = false;
//}
