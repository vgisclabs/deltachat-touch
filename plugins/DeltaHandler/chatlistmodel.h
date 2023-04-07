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

#ifndef CHATLISTMODEL_H
#define CHATLISTMODEL_H

#include <QtCore>
#include <QtGui>
//#include <string>
#include "deltachat.h"

class ChatlistModel : public QAbstractListModel {
    Q_OBJECT

public:
    explicit ChatlistModel(QObject *parent = 0);
    ~ChatlistModel();

    enum { ChatnameRole, MsgPreviewRole, TimestampRole, ChatPicRole, AvatarColorRole, AvatarInitialRole };

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

    Q_INVOKABLE uint32_t getChatID(int myindex);

    void configure(dc_context_t* context, int flagsForChatlist);

public slots:
    void updateQuery(QString query);

protected:
    QHash<int, QByteArray> roleNames() const;

private:
    dc_context_t* currentContext;
    dc_chatlist_t* currentChatlist;
    int m_flagsForChatlist;
    QString m_query;

// TODO delete from here until before the final };
//
//    // invoked by a tap/click on a list item representing a chat
//    // on the chat overview page
//    Q_INVOKABLE void selectChat(int myindex);
//
//    Q_INVOKABLE void openChat();
//
//    Q_INVOKABLE void selectAccount(int myindex);
//
//    Q_INVOKABLE void sendAttachment(QString filepath, MsgViewType attachType = MsgViewType::FileType);
//
//    // Returns the name of the currently selected chat
//    Q_INVOKABLE QString chatName();
//
//    Q_INVOKABLE QString getChatName(int myindex);
//
//    Q_INVOKABLE void deleteChat(int myindex);
//
//    // Returns the username of the current context
//    Q_INVOKABLE QString getCurrentUsername();
//
//    // Returns the email address of the current context
//    Q_INVOKABLE QString getCurrentEmail();
//
//    // Returns the relative path to the current profile
//    // picture (for full path, StandardPaths.AppConfigLocation
//    // needs to be prepended)
//    Q_INVOKABLE QString getCurrentProfilePic();
//
//    Q_INVOKABLE void setCurrentConfig(QString key, QString newValue);
//
//    Q_INVOKABLE void prepareTempContextConfig();
//
//    Q_INVOKABLE void configureTempContext();
//
//    Q_INVOKABLE void setTempContext(uint32_t accID);
//
//    Q_INVOKABLE QString getTempContextConfig(QString key);
//
//    Q_INVOKABLE void setTempContextConfig(QString key, QString val);
//
//    Q_INVOKABLE void start_io();
//
//    Q_INVOKABLE void stop_io();
//
//    Q_INVOKABLE bool isBackupFile(QString filePath);
//
//    Q_INVOKABLE void importBackup(QString filePath);
//
//    Q_INVOKABLE void chatAcceptContactRequest();
//
//    Q_INVOKABLE void chatDeleteContactRequest();
//
//    Q_INVOKABLE void chatBlockContactRequest();
//
//    /* ========================================================
//     * =================== Profile editing ====================
//     * ======================================================== */
//    Q_INVOKABLE QString getCurrentSignature();
//
//    Q_INVOKABLE void startProfileEdit();
//
//    Q_INVOKABLE void setProfileValue(QString key, QString newValue);
//
//    Q_INVOKABLE void finalizeProfileEdit();
//
//    /* ================ End Profile editing ================== */
//
//    void unselectAccount(uint32_t accID);
//
//    // QAbstractListModel interface
//    virtual int rowCount(const QModelIndex &parent) const;
//    virtual QVariant data(const QModelIndex &index, int role) const;
//
//    Q_PROPERTY(ChatModel* chatmodel READ chatmodel NOTIFY chatmodelChanged);
//    Q_PROPERTY(AccountsModel* accountsmodel READ accountsmodel NOTIFY accountsmodelChanged);
//    Q_PROPERTY(ContactsModel* contactsmodel READ contactsmodel NOTIFY contactsmodelChanged);
//
//    ChatModel* chatmodel();
//    AccountsModel* accountsmodel();
//    ContactsModel* contactsmodel();
//
//    Q_PROPERTY(bool hasConfiguredAccount READ hasConfiguredAccount NOTIFY hasConfiguredAccountChanged);
//    Q_PROPERTY(bool networkingIsAllowed READ networkingIsAllowed NOTIFY networkingIsAllowedChanged);
//    Q_PROPERTY(bool networkingIsStarted READ networkingIsStarted NOTIFY networkingIsStartedChanged);
//    Q_PROPERTY(bool chatIsContactRequest READ chatIsContactRequest NOTIFY chatIsContactRequestChanged);
//
//    bool hasConfiguredAccount();
//    bool networkingIsAllowed();
//    bool networkingIsStarted();
//    bool chatIsContactRequest();
//
//
//signals:
//    // TODO the models never change, they communicate
//    // changes themselves
//    void chatmodelChanged();
//    void accountsmodelChanged();
//    void contactsmodelChanged();
//
//    void hasConfiguredAccountChanged();
//    void networkingIsAllowedChanged();
//    void networkingIsStartedChanged();
//    void accountChanged();
//    void newMsgReceived(int msgID);
//    void messageRead(int msgID);
//    void progressEventReceived(int perMill, QString errorMsg);
//    void imexEventReceived(int perMill);
//    void newUnconfiguredAccount();
//    void newConfiguredAccount();
//    void updatedAccountConfig(uint32_t);
//    void chatIsContactRequestChanged();
//    void openChatViewRequest();
//    void newTempProfilePic(QString);
//
//public slots:
//    void unrefTempContext();
//    void chatViewIsClosed();
//
//protected:
//    QHash<int, QByteArray> roleNames() const;
//
//private slots:
//    void newMessage(uint32_t accID, int chatID, int msgID);
//    void messageReadByRecipient(uint32_t accID, int chatID, int msgID);
//    void progressEvent(int perMill, QString errorMsg);
//    void imexProgressReceiver(int perMill);
//    void chatCreationReceiver(uint32_t chatID);
//    void updateCurrentChatMessageCount();
//    void resetCurrentChatMessageCount();
//
//private:
//    dc_accounts_t* allAccounts;
//    dc_context_t* currentContext;
//    dc_context_t* tempContext; // for creation of new account
//    dc_chatlist_t* currentChatlist;
//    EmitterThread* eventThread;
//    ChatModel* m_chatmodel;
//    AccountsModel* m_accountsmodel;
//    ContactsModel* m_contactsmodel;
//    uint32_t currentChatID;
//    bool chatmodelIsConfigured;
//    bool m_hasConfiguredAccount;
//    bool m_networkingIsAllowed;
//    bool m_networkingIsStarted;
//    bool m_configuringNewAccount;
//    QSettings* settings;
//    QHash<QString, QString> m_changedProfileValues;
//
//    bool isExistingChat(uint32_t chatID);
};

#endif // CHATLISTMODEL_H
