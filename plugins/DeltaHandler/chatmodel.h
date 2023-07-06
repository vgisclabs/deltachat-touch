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
    enum { IsUnreadMsgsBarRole, IsForwardedRole, IsInfoRole, IsDownloadedRole, DownloadStateRole, IsSelfRole, MessageSeenRole, MessageStateRole, QuotedTextRole, QuoteIsSelfRole, QuoteUserRole, DurationRole, MessageInfoRole, TypeRole, TextRole, ProfilePicRole, IsSameSenderAsNextRole, PadlockRole, DateRole, UsernameRole, SummaryTextRole, FilePathRole, AudioFilePathRole, ImageWidthRole, AvatarColorRole, AvatarInitialRole, IsSearchResultRole, ContactIdRole };

    Q_INVOKABLE void setMomentaryMessage(int myindex);

    Q_INVOKABLE void deleteMomentaryMessage();

    Q_INVOKABLE void deleteAllMessagesInCurrentChat();

    Q_INVOKABLE QString getMomentarySummarytext();

    Q_INVOKABLE QString getMomentaryText();

    Q_INVOKABLE int getMomentaryViewType();

    Q_INVOKABLE QString getMomentaryInfo();

    Q_INVOKABLE uint32_t getCurrentChatId();

    Q_INVOKABLE int getUnreadMessageCount();

    Q_INVOKABLE int getUnreadMessageBarIndex();

    // TODO: similar things like chatIsContactRequest are
    // currently Q_PROPERTY, and in DeltaHandler
    Q_INVOKABLE bool chatCanSend();

    Q_INVOKABLE bool chatIsDeviceTalk();

    Q_INVOKABLE bool selfIsInGroup();

    Q_INVOKABLE bool setUrlToExport();

    Q_INVOKABLE QString getUrlToExport();

    Q_INVOKABLE QString getDraft();

    Q_INVOKABLE void setDraft(QString draftText);

    Q_INVOKABLE void setQuote(int myindex);

    Q_INVOKABLE void unsetQuote();

    // int attachType should be DeltaHandler::MsgViewType attachType, but this
    // only works if the method is used in the DeltaHandler class itself
    Q_INVOKABLE void setAttachment(QString filepath, int attachType);

    // called upon entering ChatView to create the attachment preview
    Q_INVOKABLE void emitDraftHasAttachmentSignals();

    Q_INVOKABLE void unsetAttachment();

    Q_INVOKABLE QString getDraftQuoteSummarytext();

    Q_INVOKABLE QString getDraftQuoteUsername();

    Q_INVOKABLE QVariant callData(int myindex, QString role);

    Q_INVOKABLE void initiateQuotedMsgJump(int myindex);

    Q_INVOKABLE bool prepareForwarding(int myindex);

    Q_INVOKABLE void forwardingFinished();

    Q_INVOKABLE void forwardMessage(uint32_t chatIdToForwardTo);

    Q_INVOKABLE void downloadFullMessage(int myindex);

    // invoked by clicking the "send" icon in a chat,
    // if a text has been entered into the TextArea
    Q_INVOKABLE void sendMessage(QString messageText);

    Q_PROPERTY(bool hasDraft READ hasDraft);

    Q_PROPERTY(bool draftHasQuote READ draftHasQuote NOTIFY draftHasQuoteChanged);
    Q_PROPERTY(bool draftHasAttachment READ draftHasAttachment NOTIFY draftHasAttachmentChanged);

    // presents a list of chats to forward messages to
    Q_PROPERTY(ChatlistModel* chatlistmodel READ chatlistmodel);

    void configure(uint32_t chatID, dc_context_t* context, DeltaHandler* deltaHandler, std::vector<uint32_t> unreadMsgs, bool isContactRequest = false);
    
    bool chatIsContactRequest();
    bool hasDraft();
    bool draftHasQuote();
    bool draftHasAttachment();
    void acceptChat();

    ChatlistModel* chatlistmodel();

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

    // Returns the number of messages in the current chat
    Q_INVOKABLE int getMessageCount();

public slots:
    void messageStatusChangedSlot(int msgID);
    void appIsActiveAgainActions();
    void chatViewIsOpened();
    void chatViewIsClosed();

    // handles entries into the search field in ChatView
    void updateQuery(QString query);
    void searchJumpSlot(int posType);

signals:
    void markedAllMessagesSeen();
    void jumpToMsg(int myindex);
    void draftHasQuoteChanged();
    void draftHasAttachmentChanged();
    void chatDataChanged();
    void searchCountUpdate(int current, int total);

    // if addCacheLocation is set, filepath has to be prepended
    // by CacheLocation by the receiver of the signal, otherwise
    // AppConfigLocation has to be set. Only relevant for the signal
    // for images because only images and audio need to be accessed
    // from QML, and in the cause of audio, it will be copied
    // to cache first (won't play from AppConfigLocation due to AppArmor)
    void previewAudioAttachment(QString filepath, QString filename);
    void previewImageAttachment(QString filepath, bool addCacheLocation);
    void previewFileAttachment(QString filename);

protected:
    QHash<int, QByteArray> roleNames() const;

private slots:
    void newMessage(int msgID);

private:
    DeltaHandler* m_dhandler;
    dc_context_t* currentMsgContext;
    uint32_t m_chatID;
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
    // total number of entries in currentSearchMsgArray
    int m_searchCountTotal;
    // current index for cycling through search results
    int m_searchCountCurrent;

    int getIndexOfMsgID(uint32_t msgID);
    
    // Stores the message ID of the chatview index for which
    // an action was triggered. Reason is that QML does not
    // have the type uint32_t, and using the chatview index
    // is unsafe because the index of the selected message might
    // change in the background while the user is still
    // in some action page
    uint32_t m_MomentaryMsgId;
};


#endif // CHATMODEL_H
