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
#include <QHash>
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
    enum { IsUnreadMsgsBarRole, IsForwardedRole, IsInfoRole, IsProtectionInfoRole, ProtectionInfoTypeRole, IsDownloadedRole, DownloadStateRole, IsSelfRole, MessageSeenRole, MessageStateRole, QuotedTextRole, QuoteIsSelfRole, QuoteUserRole, QuoteAvatarColorRole, DurationRole, MessageInfoRole, TypeRole, TextRole, ProfilePicRole, IsSameSenderAsNextRole, PadlockRole, DateRole, UsernameRole, SummaryTextRole, FilePathRole, FilenameRole, AudioFilePathRole, ImageWidthRole, ImageHeightRole, AvatarColorRole, AvatarInitialRole, IsSearchResultRole, ContactIdRole, HasHtmlRole, ReactionsRole };

    Q_INVOKABLE void setMomentaryMessage(int myindex);

    Q_INVOKABLE void deleteMomentaryMessage();

    Q_INVOKABLE void deleteAllMessagesInCurrentChat();

    Q_INVOKABLE QString getMomentarySummarytext();

    Q_INVOKABLE QString getMomentaryText();

    Q_INVOKABLE int getMomentaryViewType();

    Q_INVOKABLE QString exportMomentaryFileToFolder(QString destinationFolder);

    Q_INVOKABLE QString getMomentaryFilenameToExport();

    Q_INVOKABLE QString exportFileToFolder(QString sourceFilePath, QString destinationFolder);

    Q_INVOKABLE QString getMomentaryInfo();

    Q_INVOKABLE uint32_t getCurrentChatId();

    Q_INVOKABLE int getUnreadMessageCount();

    Q_INVOKABLE int getUnreadMessageBarIndex();

    // TODO: similar things like chatIsContactRequest are
    // currently Q_PROPERTY, and in DeltaHandler
    Q_INVOKABLE bool chatCanSend();

    Q_INVOKABLE bool chatIsProtectionBroken();

    Q_INVOKABLE bool chatIsDeviceTalk();

    Q_INVOKABLE bool selfIsInGroup();

    Q_INVOKABLE bool setUrlToExport();

    Q_INVOKABLE QString getUrlToExport();

    Q_INVOKABLE QString getHtmlMessage(int myindex);

    Q_INVOKABLE QString getHtmlMsgSubject(int myindex);

    Q_INVOKABLE QString getDraftText();

    Q_INVOKABLE void setDraftText(QString draftText);

    void saveDraft();

    Q_INVOKABLE void setQuote(int myindex);

    Q_INVOKABLE void unsetQuote();

    // int attachType should be DeltaHandler::MsgViewType attachType, but this
    // only works if the method is used in the DeltaHandler class itself
    Q_INVOKABLE void setAttachment(QString filepath, int attachType);

    // called upon entering ChatView to create the attachment preview
    Q_INVOKABLE void checkDraftHasAttachment();

    Q_INVOKABLE void unsetAttachment();

    Q_INVOKABLE QString getDraftQuoteSummarytext();

    Q_INVOKABLE QString getDraftQuoteUsername();

    Q_INVOKABLE QVariant callData(int myindex, QString role);

    Q_INVOKABLE void initiateQuotedMsgJump(int myindex);

    Q_INVOKABLE bool prepareForwarding(int myindex);

    Q_INVOKABLE void forwardingFinished();

    Q_INVOKABLE void forwardMessage(uint32_t chatIdToForwardTo);

    Q_INVOKABLE int indexToMessageId(int myindex);

    Q_INVOKABLE void downloadFullMessage(int myindex);

    // invoked by clicking the "send" icon in a chat,
    // if a text has been entered into the TextArea
    Q_INVOKABLE void sendMessage(QString messageText, int accID, int chatID, int cursorPosition = 0);

    Q_PROPERTY(bool hasDraft READ hasDraft);

    Q_PROPERTY(bool draftHasQuote READ draftHasQuote NOTIFY draftHasQuoteChanged);
    Q_PROPERTY(bool draftHasAttachment READ draftHasAttachment NOTIFY draftHasAttachmentChanged);

    // presents a list of chats to forward messages to
    Q_PROPERTY(ChatlistModel* chatlistmodel READ chatlistmodel);

    void configure(uint32_t chatID, uint32_t aID, dc_accounts_t* allAccs, DeltaHandler* deltaHandler, std::vector<uint32_t> unreadMsgs, bool isContactRequest = false);
    
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

    // checks whether a file is a gif
    Q_INVOKABLE bool isGif(QString fileToCheck) const;

    // will be called by ChatView.qml after receiving and
    // processing the newChatConfigured(uint32_t chatID) signal
    Q_INVOKABLE void allowSettingDraftAgain(uint32_t chatID);

public slots:
    void messageStatusChangedSlot(int msgID);
    void appIsActiveAgainActions();

    // unusedParam is only there so the signal from ChatView.qml
    // can be connected to both a slot in DeltaHandler (which
    // needs this parameter) and here (where the parameter
    // is not needed)
    void chatViewIsClosed(bool unusedParam);

    // handles entries into the search field in ChatView
    void updateQuery(QString query);
    void searchJumpSlot(int posType);

signals:
    void markedAllMessagesSeen();
    void jumpToMsg(int myindex);
    void draftHasQuoteChanged();
    void draftHasAttachmentChanged();
    void chatDataChanged();
    void newChatConfigured(uint32_t chatID);
    void searchCountUpdate(int current, int total);

    // if addCacheLocation is set, filepath has to be prepended
    // by CacheLocation by the receiver of the signal, otherwise
    // AppConfigLocation has to be set. Only relevant for the signal
    // for images because only images and audio need to be accessed
    // from QML, and in the cause of audio, it will be copied
    // to cache first (won't play from AppConfigLocation due to AppArmor)
    void previewAudioAttachment(QString filepathInCache, QString filename);
    void previewImageAttachment(QString filepathInCache, bool isAnimated);
    void previewFileAttachment(QString filename);
    void previewVoiceAttachment(QString filepathInCache);

protected:
    QHash<int, QByteArray> roleNames() const;

private slots:
    void newMessage(int msgID);

private:
    DeltaHandler* m_dhandler;
    dc_context_t* currentMsgContext;
    uint32_t m_chatID;
    bool m_chatIsBeingViewed;
    bool m_settingDraftTextAllowed;
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

    // For message IDs that are found in this vector,
    // QuotedTextRole in data() will return the full quoted
    // text (otherwise, truncated text + " […]" is returned)
    std::vector<uint32_t> msgIdsWithExpandedQuote;

    // key: <accID>_<chatID>, see m_accIdChatIdKey
    // value: the draft text
    QHash<QString, QString> m_draftTextHash;

    // contains <accID>_<chatID> as string so it doesn't
    // have to be generated each time m_draftTextHash is accessed
    QString m_accIdChatIdKey;


    bool toggleQuoteVectorContainsId(const uint32_t tempID) const;
    void toggleQuoteVectorRemoveId(uint32_t tempID);

    void emitDraftHasAttachmentSignals(QString filepath, int messageType);
};


#endif // CHATMODEL_H
