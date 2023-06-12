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

#ifndef CHATMODEL_H
#define CHATMODEL_H

#include <QtCore>
#include <QtGui>
#include <string>
#include <deque>
#include "deltahandler.h"
#include "chatlistmodel.h"
#include "deltachat.h"

class DeltaHandler;

class ChatModel : public QAbstractListModel {
    Q_OBJECT

public:
    explicit ChatModel(QObject *parent = 0);
    ~ChatModel();

    // TODO remove MessageSeenRole
    enum { IsUnreadMsgsBarRole, IsForwardedRole, IsInfoRole, IsDownloadedRole, DownloadStateRole, IsSelfRole, MessageSeenRole, MessageStateRole, QuotedTextRole, QuoteIsSelfRole, QuoteUserRole, DurationRole, MessageInfoRole, TypeRole, TextRole, ProfilePicRole, IsSameSenderAsNextRole, PadlockRole, DateRole, UsernameRole, SummaryTextRole, FilePathRole, AudioFilePathRole, ImageWidthRole, AvatarColorRole, AvatarInitialRole, IsSearchResultRole };

    Q_INVOKABLE void deleteMessage(int myindex);

    Q_INVOKABLE QString getMessageSummarytext(int myindex);

    Q_INVOKABLE int getUnreadMessageCount();

    Q_INVOKABLE int getUnreadMessageBarIndex();

    Q_INVOKABLE void setUrlToExport(int myindex);

    Q_INVOKABLE QString getUrlToExport();

    Q_INVOKABLE QString getDraft();

    Q_INVOKABLE void setDraft(QString draftText);

    Q_INVOKABLE void setQuote(int myindex);

    Q_INVOKABLE void unsetQuote();

    Q_INVOKABLE QString getDraftQuoteSummarytext();

    Q_INVOKABLE QString getDraftQuoteUsername();

    Q_INVOKABLE QVariant callData(int myindex, QString role);

    Q_INVOKABLE void initiateQuotedMsgJump(int myindex);

    Q_INVOKABLE void prepareForwarding(int myindex);

    Q_INVOKABLE void forwardingFinished();

    Q_INVOKABLE void forwardMessage(uint32_t chatIdToForwardTo);

    Q_INVOKABLE void downloadFullMessage(int myindex);

    // invoked by clicking the "send" icon in a chat,
    // if a text has been entered into the TextArea
    Q_INVOKABLE void sendMessage(QString messageText);


    Q_PROPERTY(bool hasDraft READ hasDraft);

    Q_PROPERTY(bool draftHasQuote READ draftHasQuote NOTIFY draftHasQuoteChanged);

    // presents a list of chats to forward messages to
    Q_PROPERTY(ChatlistModel* chatlistmodel READ chatlistmodel);

    void configure(uint32_t chatID, dc_context_t* context, DeltaHandler* deltaHandler, std::vector<uint32_t> unreadMsgs, bool isContactRequest = false);
    
    bool chatIsContactRequest();
    bool hasDraft();
    bool draftHasQuote();
    void acceptChat();

    ChatlistModel* chatlistmodel();

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

public slots:
    void messageStatusChangedSlot(int msgID);
    void appIsActiveAgainActions();
    void chatViewIsOpened();
    void chatViewIsClosed();

    // handles entries into the search field in ChatView
    void updateQuery(QString query);

signals:
    void markedAllMessagesSeen();
    void jumpToMsg(int myindex);
    void draftHasQuoteChanged();
    void chatDataChanged();

protected:
    QHash<int, QByteArray> roleNames() const;

private slots:
    void newMessage(int msgID);

private:
    DeltaHandler* m_dhandler;
    dc_context_t* currentMsgContext;
    uint32_t chatID;
    bool m_chatIsBeingViewed;
    size_t currentMsgCount;
    std::vector<uint32_t> msgVector;
    bool m_isContactRequest;
    int m_unreadMessageBarIndex;
    uint32_t m_firstUnreadMessageID;
    bool m_hasUnreadMessages;

    QString m_tempExportPath;
    dc_msg_t* currentMessageDraft;

    // for forwarding of messages
    ChatlistModel* m_chatlistmodel;
    uint32_t messageIdToForward;

    // for storing msgIDs that are to be marked
    // seen later. Used when new messages arrive while
    // the app is in background (if background suspension
    // is disabled). The messages will be marked seen
    // and their notifications will be removed when the
    // app is actyive again.
    std::vector<uint32_t> msgsToMarkSeenLater;

    // For caching the dc_msg_t* used in data() because the method is
    // being called repeatedly for the same message, but different
    // roles. Mutable is needed because the data() method is
    // const.
    mutable int data_row;
    mutable uint32_t data_tempMsgID;
    mutable dc_msg_t* data_tempMsg;

    QString copyToCache(QString fromFile) const;

    // for searching messages
    QString m_query;
    dc_array_t* oldSearchMsgArray;
    dc_array_t* currentSearchMsgArray;
};

#endif // CHATMODEL_H
