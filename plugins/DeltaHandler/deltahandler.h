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
#include <QAudioRecorder>
#include <string>
#include <vector>
#include "chatmodel.h"
#include "accountsmodel.h"
#include "blockedcontactsmodel.h"
#include "contactsmodel.h"
#include "groupmembermodel.h"
#include "emitterthread.h"
#include "deltachat.h"

class ChatModel;
class AccountsModel;
class EmitterThread;
class ContactsModel;
class BlockedContactsModel;
class GroupMemberModel;

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

    enum DownloadState { DownloadDone, DownloadAvailable, DownloadInProgress, DownloadFailure };
    Q_ENUM(DownloadState)

    enum QrState { DT_QR_ASK_VERIFYCONTACT, DT_QR_ASK_VERIFYGROUP, DT_QR_FPR_OK, DT_QR_FPR_MISMATCH, DT_QR_FPR_WITHOUT_ADDR, DT_QR_ACCOUNT, DT_QR_BACKUP, DT_QR_WEBRTC_INSTANCE, DT_QR_ADDR, DT_QR_TEXT, DT_QR_URL, DT_QR_ERROR, DT_QR_WITHDRAW_VERIFYCONTACT, DT_QR_WITHDRAW_VERIFYGROUP, DT_QR_REVIVE_VERIFYCONTACT, DT_QR_REVIVE_VERIFYGROUP, DT_QR_LOGIN, DT_UNKNOWN };
    Q_ENUM(QrState)

    enum VoiceMessageQuality { LowRecordingQuality, BalancedRecordingQuality, HighRecordingQuality };
    Q_ENUM(VoiceMessageQuality)

    // see m_chatIDMomentaryIndex below
    Q_INVOKABLE void setChatIDMomentaryIndex(int myindex);

    // invoked by a tap/click on a list item representing a chat
    // on the chat overview page
    Q_INVOKABLE void selectChat(int myindex);

    Q_INVOKABLE void openChat();

    Q_INVOKABLE void archiveMomentaryChat();

    Q_INVOKABLE void unarchiveMomentaryChat();

    Q_INVOKABLE void pinUnpinMomentaryChat();

    Q_INVOKABLE bool momentaryChatIsMuted();

    Q_INVOKABLE void momentaryChatSetMuteDuration(int64_t secondsToMute);

    Q_INVOKABLE void closeArchive();

    Q_INVOKABLE void selectAccount(int myindex);

    Q_INVOKABLE void sendAttachment(QString filepath, MsgViewType attachType = MsgViewType::FileType);

    // Returns the name of the currently selected chat
    Q_INVOKABLE QString chatName();

    // Returns whether the currently selected chat is verified/protected
    Q_INVOKABLE bool chatIsVerified();

    Q_INVOKABLE QString getMomentaryChatName();

    Q_INVOKABLE uint32_t getChatEphemeralTimer(int myindex);

    Q_INVOKABLE void setChatEphemeralTimer(int myindex, uint32_t timer);

    Q_INVOKABLE void deleteMomentaryChat();

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

    Q_INVOKABLE void importBackupFromFile(QString filePath);

    Q_INVOKABLE void chatAcceptContactRequest();

    Q_INVOKABLE void chatDeleteContactRequest();

    Q_INVOKABLE void chatBlockContactRequest();

    Q_INVOKABLE void exportBackup();

    Q_INVOKABLE QString getUrlToExport();

    // expects the index of the chat in the chatlist
    Q_INVOKABLE QString getMomentaryChatEncInfo();

    Q_INVOKABLE bool momentaryChatIsDeviceTalk();

    Q_INVOKABLE bool momentaryChatIsSelfTalk();

    // expects the index of the chat in the chatlist,
    // will check for the currently active chat
    // (i.e., the one in currentChatID) if -1 is
    // passed
    // TODO: other parameter than -1 is not used anymore, see momentaryChatIsGroup
    // => adapt?
    Q_INVOKABLE bool chatIsGroup(int myindex);

    Q_INVOKABLE bool momentaryChatIsGroup();

    // TODO combine with momentaryChatSelfIsInGroup?
    Q_INVOKABLE bool selfIsInGroup(int myindex);

    Q_INVOKABLE bool momentaryChatSelfIsInGroup();

    Q_INVOKABLE void momentaryChatBlockContact();

    // Has to be called before using the
    // blockedcontactsmodel.
    // TODO: Solve differently? (see comments
    // in method)
    Q_INVOKABLE void prepareBlockedContactsModel();

    Q_INVOKABLE int getDeletionEstimation(QString secondsAsString, int fromServer);

    Q_INVOKABLE void importKeys();

    Q_INVOKABLE QString prepareExportKeys();
    Q_INVOKABLE void startExportKeys(QString dirToExportTo);

    Q_INVOKABLE void createNotification(QString summary, QString body, QString tag, QString icon);
    Q_INVOKABLE void removeNotification(QString tag = "");

    /* ========================================================
     * =================== Profile editing ====================
     * ======================================================== */
    Q_INVOKABLE QString getCurrentSignature();

    Q_INVOKABLE void startProfileEdit();

    Q_INVOKABLE void setProfileValue(QString key, QString newValue);

    Q_INVOKABLE void finalizeProfileEdit();

    /* ================ End Profile editing ================== */

    /* ========================================================
     * ============== New Group / Editing Group ===============
     * ======================================================== */

    Q_INVOKABLE void startCreateGroup(bool verifiedGroup);
    
    // will set up the currently active chat
    // (i.e., the one in currentChatID) if -1 is
    // passed
    // TODO: combine with momentaryChatStartEditGroup() ?
    Q_INVOKABLE void startEditGroup(int myindex);

    Q_INVOKABLE void momentaryChatStartEditGroup();

    Q_INVOKABLE void finalizeGroupEdit(QString groupName, QString imagePath);
    Q_INVOKABLE void stopCreateOrEditGroup();

    Q_INVOKABLE void momentaryChatLeaveGroup();

    Q_INVOKABLE QString getTempGroupPic();
    Q_INVOKABLE QString getTempGroupName();
    Q_INVOKABLE bool tempGroupIsVerified();

    Q_INVOKABLE void setGroupPic(QString filepath);

    Q_INVOKABLE QString getTempGroupQrSvg();

    /* ============ End New Group / Editing Group ============= */

    /* ========================================================
     * ================ QR code related stuff =================
     * ======================================================== */
    Q_INVOKABLE QString getQrInviteSvg();
    Q_INVOKABLE QString getQrInviteTxt();
    Q_INVOKABLE QString getQrContactEmail();
    Q_INVOKABLE QString getQrTextOne();
    Q_INVOKABLE int evaluateQrCode(QString clipboardData);
    Q_INVOKABLE void continueQrCodeAction();
    Q_INVOKABLE void prepareQrBackupImport();
    Q_INVOKABLE void startQrBackupImport();
    Q_INVOKABLE void cancelQrImport();
    /* ============ End QR code related stuff ================= */

    /* ========================================================
     * =============== Audio message recording ================
     * ======================================================== */
    Q_INVOKABLE void prepareAudioRecording(int recordingQuality);
    Q_INVOKABLE void dismissAudioRecording();
    Q_INVOKABLE QString startAudioRecording();
    Q_INVOKABLE void stopAudioRecording();
    Q_INVOKABLE void sendAudioRecording(QString filepath);
    /* ============ End audio message recording =============== */

    Q_INVOKABLE void setEnablePushNotifications(bool enabled);
    Q_INVOKABLE void setDetailedPushNotifications(bool detailed);
    Q_INVOKABLE void setAggregatePushNotifications(bool aggregated);

    void unselectAccount(uint32_t accID);

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

    Q_PROPERTY(ChatModel* chatmodel READ chatmodel NOTIFY chatmodelChanged);
    Q_PROPERTY(AccountsModel* accountsmodel READ accountsmodel NOTIFY accountsmodelChanged);
    Q_PROPERTY(ContactsModel* contactsmodel READ contactsmodel NOTIFY contactsmodelChanged);
    Q_PROPERTY(BlockedContactsModel* blockedcontactsmodel READ blockedcontactsmodel NOTIFY blockedcontactsmodelChanged);
    Q_PROPERTY(GroupMemberModel* groupmembermodel READ groupmembermodel NOTIFY groupmembermodelChanged);
    // Reason: GUI needs to connect to signal imexProgress from eventThread directly because
    // dc_receive_backup() blocks, so the DeltaHandler singleton will not pass the progress events
    // until dc_receive_backup() returns, and at this point, everything has already happened
    Q_PROPERTY(EmitterThread* emitterthread READ emitterthread NOTIFY emitterthreadChanged);

    ChatModel* chatmodel();
    AccountsModel* accountsmodel();
    ContactsModel* contactsmodel();
    BlockedContactsModel* blockedcontactsmodel();
    GroupMemberModel* groupmembermodel();
    EmitterThread* emitterthread();

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
    void groupmembermodelChanged();
    void emitterthreadChanged();
    void chatlistShowsArchivedOnly(bool showsArchived);

    void hasConfiguredAccountChanged();
    void networkingIsAllowedChanged();
    void networkingIsStartedChanged();
    void accountChanged();
    void msgsChanged(int msgID);
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
    void chatViewClosed();
    void newTempProfilePic(QString);
    void chatBlockContactDone();

    /* ========================================================
     * ============== New Group / Editing Group ===============
     * ======================================================== */
    void newChatPic(QString newPath);
    /* ============ End New Group / Editing Group ============= */

    // for exporting backup, will be emitted
    // when the backup file has been written (i.e.
    // the event DC_EVENT_IMEX_FILE_WRITTEN has
    // been received
    void backupFileWritten();

    /* ========================================================
     * ================ QR code related stuff =================
     * ======================================================== */
    void finishedSetConfigFromQr(bool successful);
    void readyForQrBackupImport();
    /* ============ End QR code related stuff ================= */

public slots:
    void unrefTempContext();
    void chatViewIsClosed();

    void prepareContactsmodelForGroupMemberAddition();

    // Main.qml emits a signal every 5 minutes that is connected
    // to this slot
    void periodicTimerActions();

protected:
    QHash<int, QByteArray> roleNames() const;

private slots:
    void messagesChanged(uint32_t accID, int chatID, int msgID);
    void incomingMessage(uint32_t accID, int chatID, int msgID);
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
    GroupMemberModel* m_groupmembermodel;
    uint32_t currentChatID;
    bool chatmodelIsConfigured;
    bool m_hasConfiguredAccount;
    bool m_networkingIsAllowed;
    bool m_networkingIsStarted;
    bool m_configuringNewAccount;
    bool m_showArchivedChats;
    QString m_tempExportPath;
    QSettings* settings;
    QHash<QString, QString> m_changedProfileValues;

    // contains all unseen message IDs of currentContext and their
    // corresponding chat IDs
    // TODO: better type than vector?
    std::vector<std::array<uint32_t, 2>> freshMsgs;

    // for creation of new group or editing of group
    uint32_t m_tempGroupChatID;
    bool creatingNewGroup;
    bool creatingOrEditingVerifiedGroup;

    // Stores the chat ID of the chatlist index for which
    // an action was triggered. Reason is that QML does not
    // have the type uint32_t, and using the chatlist index
    // is unsafe because the index of the selected chat might
    // change in the background while the user is still
    // in some action page
    uint32_t m_chatIDMomentaryIndex;

    // for scanning QR codes
    int m_qrTempState;
    uint32_t m_qrTempContactID;
    QString m_qrTempText;
    QString m_qrTempLotTextOne;

    // Tag of the most recent notification
    QString m_lastTag;
    bool m_enablePushNotifications;
    bool m_detailedPushNotifications;
    bool m_aggregatePushNotifications;
    // if true, the previous push notification is removed when creating a new one
    bool m_aggregateNotifications;

    // for recording of audio messages
    QAudioRecorder* m_audioRecorder;

    bool isExistingChat(uint32_t chatID);
    void setCoreTranslations();
    void contextSetupTasks();
    void sendNotification(uint32_t accID, int chatID, int msgID);
};

#endif // DELTAHANDLER_H
