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

#ifndef DELTAHANDLER_H
#define DELTAHANDLER_H

#include <QtCore>
#include <QtGui>
#include <string>
#include "chatmodel.h"
#include "accountsmodel.h"
#include "blockedcontactsmodel.h"
#include "contactsmodel.h"
#include "emitterthread.h"
#include "deltachat.h"

class ChatModel;
class AccountsModel;
class EmitterThread;
class ContactsModel;

class DeltaHandler : public QAbstractListModel {
    Q_OBJECT
public:
    explicit DeltaHandler(QObject *parent = 0);
    ~DeltaHandler();

    enum { ChatnameRole, ChatIsPinnedRole, ChatIsArchivedRole, ChatIsArchiveLinkRole, MsgPreviewRole, TimestampRole, StateRole, ChatPicRole, IsContactRequestRole, AvatarColorRole, AvatarInitialRole, ChatIsMutedRole, NewMsgCountRole };

    // TODO: belongs to ChatModel, but ChatModel isn't registered as
    // a module in Qt (yet?).
    enum MsgViewType { AudioType, FileType, GifType, ImageType, StickerType, TextType, VideoType, VideochatInvitationType, VoiceType, WebXdcType, UnknownType };
    Q_ENUM(MsgViewType)

    enum MsgState { StatePending, StateFailed, StateDelivered, StateReceived };
    Q_ENUM(MsgState)

    // invoked by a tap/click on a list item representing a chat
    // on the chat overview page
    Q_INVOKABLE void selectChat(int myindex);

    Q_INVOKABLE void openChat();

    Q_INVOKABLE void archiveChat(int myindex);

    Q_INVOKABLE void unarchiveChat(int myindex);

    Q_INVOKABLE void pinUnpinChat(int myindex);

    Q_INVOKABLE void closeArchive();

    Q_INVOKABLE void selectAccount(int myindex);

    Q_INVOKABLE void sendAttachment(QString filepath, MsgViewType attachType = MsgViewType::FileType);

    // Returns the name of the currently selected chat
    Q_INVOKABLE QString chatName();

    Q_INVOKABLE QString getChatName(int myindex);

    Q_INVOKABLE void deleteChat(int myindex);

    // Returns the username of the current context
    Q_INVOKABLE QString getCurrentUsername();

    // Returns the email address of the current context
    Q_INVOKABLE QString getCurrentEmail();

    // Returns the relative path to the current profile
    // picture (for full path, StandardPaths.AppConfigLocation
    // needs to be prepended)
    Q_INVOKABLE QString getCurrentProfilePic();

    // TODO: replace all getCurrentXY() by this method (EXCEPT
    // the ones that return a path, see the data() method in chatmodel.cpp,
    // ProfilePicRole case)
    Q_INVOKABLE QString getCurrentConfig(QString key);

    Q_INVOKABLE void setCurrentConfig(QString key, QString newValue);

    Q_INVOKABLE void prepareTempContextConfig();

    Q_INVOKABLE void configureTempContext();

    Q_INVOKABLE void setTempContext(uint32_t accID);

    Q_INVOKABLE QString getTempContextConfig(QString key);

    Q_INVOKABLE void setTempContextConfig(QString key, QString val);

    Q_INVOKABLE void start_io();

    Q_INVOKABLE void stop_io();

    Q_INVOKABLE bool isBackupFile(QString filePath);

    Q_INVOKABLE void importBackup(QString filePath);

    Q_INVOKABLE void chatAcceptContactRequest();

    Q_INVOKABLE void chatDeleteContactRequest();

    Q_INVOKABLE void chatBlockContactRequest();

    Q_INVOKABLE void exportBackup();

    Q_INVOKABLE QString getUrlToExport();

    // expects the index of the chat in the chatlist
    Q_INVOKABLE QString getChatEncInfo(int myindex);

    // expects the index of the chat in the chatlist
    Q_INVOKABLE bool chatIsDeviceTalk(int myindex);

    // expects the index of the chat in the chatlist
    Q_INVOKABLE bool chatIsSelfTalk(int myindex);

    // expects the index of the chat in the chatlist
    Q_INVOKABLE bool chatIsGroup(int myindex);

    Q_INVOKABLE void chatBlockContact(int myindex);

    // Has to be called before using the
    // blockedcontactsmodel.
    // TODO: Solve differently? (see comments
    // in method)
    Q_INVOKABLE void prepareBlockedContactsModel();

    /* ========================================================
     * =================== Profile editing ====================
     * ======================================================== */
    Q_INVOKABLE QString getCurrentSignature();

    Q_INVOKABLE void startProfileEdit();

    Q_INVOKABLE void setProfileValue(QString key, QString newValue);

    Q_INVOKABLE void finalizeProfileEdit();

    /* ================ End Profile editing ================== */

    void unselectAccount(uint32_t accID);

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

    Q_PROPERTY(ChatModel* chatmodel READ chatmodel NOTIFY chatmodelChanged);
    Q_PROPERTY(AccountsModel* accountsmodel READ accountsmodel NOTIFY accountsmodelChanged);
    Q_PROPERTY(ContactsModel* contactsmodel READ contactsmodel NOTIFY contactsmodelChanged);
    Q_PROPERTY(BlockedContactsModel* blockedcontactsmodel READ blockedcontactsmodel NOTIFY blockedcontactsmodelChanged);

    ChatModel* chatmodel();
    AccountsModel* accountsmodel();
    ContactsModel* contactsmodel();
    BlockedContactsModel* blockedcontactsmodel();

    Q_PROPERTY(bool hasConfiguredAccount READ hasConfiguredAccount NOTIFY hasConfiguredAccountChanged);
    Q_PROPERTY(bool networkingIsAllowed READ networkingIsAllowed NOTIFY networkingIsAllowedChanged);
    Q_PROPERTY(bool networkingIsStarted READ networkingIsStarted NOTIFY networkingIsStartedChanged);
    Q_PROPERTY(bool chatIsContactRequest READ chatIsContactRequest NOTIFY chatIsContactRequestChanged);

    bool hasConfiguredAccount();
    bool networkingIsAllowed();
    bool networkingIsStarted();
    bool chatIsContactRequest();


signals:
    // TODO the models never change, they communicate
    // changes themselves
    void chatmodelChanged();
    void accountsmodelChanged();
    void contactsmodelChanged();
    void blockedcontactsmodelChanged();
    void chatlistShowsArchivedOnly(bool showsArchived);

    void hasConfiguredAccountChanged();
    void networkingIsAllowedChanged();
    void networkingIsStartedChanged();
    void accountChanged();
    void newMsgReceived(int msgID);
    void messageRead(int msgID);
    void messageDelivered(int msgID);
    void messageFailed(int msgID);
    void progressEventReceived(int perMill, QString errorMsg);
    void imexEventReceived(int perMill);
    void newUnconfiguredAccount();
    void newConfiguredAccount();
    void updatedAccountConfig(uint32_t);
    void chatIsContactRequestChanged();
    void openChatViewRequest();
    void newTempProfilePic(QString);
    void chatBlockContactDone();

    // for exporting backup, will be emitted
    // when the backup file has been written (i.e.
    // the event DC_EVENT_IMEX_FILE_WRITTEN has
    // been received
    void backupFileWritten();

public slots:
    void unrefTempContext();
    void chatViewIsClosed();

protected:
    QHash<int, QByteArray> roleNames() const;

private slots:
    void newMessage(uint32_t accID, int chatID, int msgID);
    void messageReadByRecipient(uint32_t accID, int chatID, int msgID);
    void messageDeliveredToServer(uint32_t accID, int chatID, int msgID);
    void messageFailedSlot(uint32_t accID, int chatID, int msgID);
    void progressEvent(int perMill, QString errorMsg);
    void imexBackupImportProgressReceiver(int perMill);
    void imexBackupExportProgressReceiver(int perMill);
    void imexFileReceiver(QString filepath);
    void chatCreationReceiver(uint32_t chatID);
    void updateCurrentChatMessageCount();
    void resetCurrentChatMessageCount();
    void changedContacts();

private:
    dc_accounts_t* allAccounts;
    dc_context_t* currentContext;
    dc_context_t* tempContext; // for creation of new account
    dc_chatlist_t* currentChatlist;
    EmitterThread* eventThread;
    ChatModel* m_chatmodel;
    AccountsModel* m_accountsmodel;
    BlockedContactsModel* m_blockedcontactsmodel;
    ContactsModel* m_contactsmodel;
    uint32_t currentChatID;
    bool chatmodelIsConfigured;
    bool m_hasConfiguredAccount;
    bool m_networkingIsAllowed;
    bool m_networkingIsStarted;
    bool m_configuringNewAccount;
    bool m_showArchivedChats;
    QString m_tempExportPath;
    //QSettings* settings;
    QHash<QString, QString> m_changedProfileValues;

    bool isExistingChat(uint32_t chatID);
};

#endif // DELTAHANDLER_H
