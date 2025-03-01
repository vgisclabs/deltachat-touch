/*
 * Copyright (C) 2023, 2024 Lothar Ketterer
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

#include <QQuickView>
#include <QtCore>
#include <QtGui>
#include <QHash>

#include <string>
#include <deque>

#include "deltahandler.h"
#include "chatlistmodel.h"
#include "webxdcImageProvider.h"
#include "../deltachat.h"

class DeltaHandler;
class WebxdcImageProvider;

class ChatModel : public QAbstractListModel {
    Q_OBJECT

public:
    explicit ChatModel(DeltaHandler* dhandler, QObject *parent = 0);
    ~ChatModel();

    // TODO remove MessageSeenRole
    enum { IsUnreadMsgsBarRole, IsForwardedRole, IsInfoRole, IsProtectionInfoRole, ProtectionInfoTypeRole, IsDownloadedRole, DownloadStateRole, IsSelfRole, MessageSeenRole, MessageStateRole, QuotedTextRole, QuoteIsSelfRole, QuoteUserRole, QuoteAvatarColorRole, DurationRole, MessageInfoRole, TypeRole, TextRole, ProfilePicRole, IsSameSenderAsNextRole, PadlockRole, DateRole, UsernameRole, SummaryTextRole, FilePathRole, FilenameRole, AudioFilePathRole, ImageWidthRole, ImageHeightRole, AvatarColorRole, AvatarInitialRole, IsSearchResultRole, ContactIdRole, HasHtmlRole, ReactionsRole, VcardRole, WebxdcInfoRole, WebxdcImageRole };

    // Main objective for setQQuickView is to set the image provider (m_webxdcImgProvider)
    // for obtaining the icons of webxdc apps. This method should be called once,
    // namely in onCompleted in Main.qml.
    Q_INVOKABLE void setQQuickView(QQuickView* view);

    Q_INVOKABLE void setMomentaryMessage(int myindex);

    Q_INVOKABLE void deleteMomentaryMessage();

    Q_INVOKABLE bool momentaryMessageIsFromSelf();

    // Will open the private chat with the sender of m_MomentaryMsgId, with
    // m_MomentaryMsgId set as quote in the draft message. The caller has
    // to ensure that m_MomentaryMsgId is a message for which a private
    // reply makes sense (e.g., it shouldn't be a message from self). A
    // pre-existing quote in the draft message of the private chat will
    // be replaced.
    Q_INVOKABLE void momentaryMessageReplyPrivately();

    Q_INVOKABLE void deleteAllMessagesInCurrentChat();

    Q_INVOKABLE QString getMomentarySummarytext();

    Q_INVOKABLE QString getMomentaryText();

    Q_INVOKABLE int getMomentaryViewType();

    Q_INVOKABLE QString exportMomentaryFileToFolder(QString destinationFolder);

    Q_INVOKABLE QString getMomentaryFilenameToExport();

    Q_INVOKABLE QString exportFileToFolder(QString sourceFilePath, QString destinationFolder);

    Q_INVOKABLE QString getMomentaryInfo();

    Q_INVOKABLE void addVcardByIndexAndStartChat(int myindex);

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

    Q_INVOKABLE void setVcardAttachment(uint32_t contactId);

    // called upon entering ChatView to create the attachment preview
    Q_INVOKABLE void checkDraftHasAttachment();

    Q_INVOKABLE void unsetAttachment();

    Q_INVOKABLE QString getDraftQuoteSummarytext();

    Q_INVOKABLE QString getDraftQuoteUsername();

    Q_INVOKABLE QVariant callData(int myindex, QString role);

    Q_INVOKABLE void initiateQuotedMsgJump(int myindex);

    Q_INVOKABLE void newChatlistmodel();

    Q_INVOKABLE void deleteChatlistmodel();

    Q_INVOKABLE void forwardMessage(uint32_t chatIdToForwardTo, uint32_t msgId);

    // Returns the message ID. If myindex corresponds to the
    // unread message bar, -1 is returned.
    Q_INVOKABLE int indexToMessageId(int myindex);

    // With myindex == -1, currentMessageDraft is used as Webxdc instance
    Q_INVOKABLE uint32_t setWebxdcInstance(int myindex);

    Q_INVOKABLE void sendWebxdcInstanceData();

    Q_INVOKABLE void sendWebxdcUpdate(QString update, QString description);

    Q_INVOKABLE QString getWebxdcUpdate(int last_serial);

    Q_INVOKABLE void sendToChat(uint32_t _chatId, QString _data);
    
    Q_INVOKABLE QString getWebxdcId();

    Q_INVOKABLE QString getWebxdcJs(QString scriptname);

    Q_INVOKABLE void webxdcSendRealtimeData(QString _rtData);
    Q_INVOKABLE void webxdcSendRealtimeAdvertisement();
    Q_INVOKABLE void webxdcLeaveRealtimeChannel();
    
    Q_INVOKABLE void checkAndJumpToWebxdcParent(int myindex);

//    Q_INVOKABLE QString getWebxdcIndex();

    Q_INVOKABLE void downloadFullMessage(int myindex);

    // invoked by clicking the "send" icon in a chat,
    // if a text has been entered into the TextArea
    Q_INVOKABLE void sendMessage(QString messageText, int accID, int chatID, int cursorPosition = 0);

    Q_PROPERTY(bool hasDraft READ hasDraft);

    Q_PROPERTY(bool draftHasQuote READ draftHasQuote NOTIFY draftHasQuoteChanged);
    Q_PROPERTY(bool draftHasAttachment READ draftHasAttachment NOTIFY draftHasAttachmentChanged);

    // presents a list of chats to forward messages to
    Q_PROPERTY(ChatlistModel* chatlistmodel READ chatlistmodel);

    // _messageBody is a draft text for the chat. It will be set in case
    // the chat ID has been opened via a mailto: url that contained body
    // text. Otherwise, it will be an empty string.
    // In the current implementation, if _messageBody is set, any other
    // draft message of this chat will be overriden and consequently, lost.
    void configure(uint32_t chatID, uint32_t aID, dc_accounts_t* allAccs, std::vector<uint32_t> unreadMsgs, QString _messageBody, QString _filepathToAttach, bool isContactRequest = false);
    
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

    void webxdcUpdateReceiver(uint32_t accID, int msgID);
    void webxdcDeleteLocalStorage(uint32_t accID, int msgID);

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
    void previewVcardAttachment(QString address, QString displayname, QString contactcolor, QString imageaddress);
    void previewWebxdcAttachment(QString webxdcIconPath, QString webxdcPreviewInfoJson);

    void newWebxdcInstanceData(QString id, dc_msg_t* instance);
    void updateCurrentWebxdc();

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

    // -1 if there's currently no unread message bar
    int m_unreadMessageBarIndex;
    uint32_t m_firstUnreadMessageID;
    bool m_hasUnreadMessages;

    QString m_tempExportPath;
    dc_msg_t* currentMessageDraft;

    // for selection of a chat for some other action (forwarding,
    // Webxdc's sendToChat, ...)
    // Needs to be generated via newChatlistmodel() prior to using it, 
    // and must be deleted after usage via deleteChatlistmodel().
    ChatlistModel* m_chatlistmodel;

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

    QQuickView* m_view;
    WebxdcImageProvider* m_webxdcImgProvider;
    uint32_t m_webxdcInstanceMsgId;
};


#endif // CHATMODEL_H
