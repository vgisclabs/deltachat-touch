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
#include <queue>
#include "chatmodel.h"
#include "accountsmodel.h"
#include "blockedcontactsmodel.h"
#include "contactsmodel.h"
#include "groupmembermodel.h"
#include "emitterthread.h"
#include "jsonrpcresponsethread.h"
#include "deltachat.h"
#include "workflowConvertDbToEncrypted.h"
#include "workflowConvertDbToUnencrypted.h"
#include <QDBusPendingCallWatcher>

struct checkNotificationsStruct {
    uint32_t accID;
    int chatID;
};

class ChatModel;
class AccountsModel;
class EmitterThread;
class JsonrpcResponseThread;
class ContactsModel;
class BlockedContactsModel;
class GroupMemberModel;
class WorkflowDbToEncrypted;
class WorkflowDbToUnencrypted;

class DeltaHandler : public QAbstractListModel {
    Q_OBJECT
public:
    explicit DeltaHandler(QObject *parent = 0);
    ~DeltaHandler();

    enum { ChatlistEntryRole, BasicChatInfoRole };
    //enum { AccountIdRole, ChatlistEntryRole, ChatIdRole, BasicChatInfoRole };

    // TODO: belongs to ChatModel, but ChatModel isn't registered as
    // a module in Qt (yet?).
    enum MsgViewType { AudioType, FileType, GifType, ImageType, StickerType, TextType, VideoType, VideochatInvitationType, VoiceType, WebXdcType, UnknownType };
    Q_ENUM(MsgViewType)

    // TODO: belongs to ChatModel, but ChatModel isn't registered as
    // a module in Qt (yet?).
    enum MsgState { StateUnknown, StatePending, StateFailed, StateDelivered, StateReceived };
    Q_ENUM(MsgState)

    // TODO: belongs to ChatModel, but ChatModel isn't registered as
    // a module in Qt (yet?).
    enum DownloadState { DownloadDone, DownloadAvailable, DownloadInProgress, DownloadFailure };
    Q_ENUM(DownloadState)

    enum QrState { DT_QR_ASK_VERIFYCONTACT, DT_QR_ASK_VERIFYGROUP, DT_QR_FPR_OK, DT_QR_FPR_MISMATCH, DT_QR_FPR_WITHOUT_ADDR, DT_QR_ACCOUNT, DT_QR_BACKUP, DT_QR_WEBRTC_INSTANCE, DT_QR_ADDR, DT_QR_TEXT, DT_QR_URL, DT_QR_ERROR, DT_QR_WITHDRAW_VERIFYCONTACT, DT_QR_WITHDRAW_VERIFYGROUP, DT_QR_REVIVE_VERIFYCONTACT, DT_QR_REVIVE_VERIFYGROUP, DT_QR_LOGIN, DT_UNKNOWN };
    Q_ENUM(QrState)

    enum VoiceMessageQuality { LowRecordingQuality, BalancedRecordingQuality, HighRecordingQuality };
    Q_ENUM(VoiceMessageQuality)

    // TODO: belongs to ChatModel, but ChatModel isn't registered as
    // a module in Qt (yet?).
    enum SearchJumpToPosition { PositionFirst, PositionPrev, PositionNext, PositionLast };
    Q_ENUM(SearchJumpToPosition)

    // There are more info types, search for DC_INFO in deltachat.h. But
    // for the time being, these are the only ones we need
    enum DcInfoType { InfoProtectionEnabled, InfoProtectionDisabled };
    Q_ENUM(DcInfoType)

    enum DcChatType { ChatTypeUndefined = DC_CHAT_TYPE_UNDEFINED,
        ChatTypeSingle = DC_CHAT_TYPE_SINGLE,
        ChatTypeGroup = DC_CHAT_TYPE_GROUP,
        ChatTypeMailinglist = DC_CHAT_TYPE_MAILINGLIST,
        ChatTypeBroadcast =DC_CHAT_TYPE_BROADCAST };
    Q_ENUM (DcChatType)

    Q_INVOKABLE bool isDesktopMode();

    Q_INVOKABLE void loadSelectedAccount();

    Q_INVOKABLE uint32_t getCurrentAccountId();

    Q_INVOKABLE void sendJsonrpcRequest(QString request);

    Q_INVOKABLE QString sendJsonrpcBlockingCall(QString request) const;

    // Returns a valid jsonrpc request for the method and arguments passed.
    // The arguments have to be separated by ", " in one single string.
    // String arguments have to be inside escaped quotation marks.
    // Example for a method call:
    // constructJsonrpcRequestString("get_backup", "12, \"qrcode:xxxxx\"");
    Q_INVOKABLE QString constructJsonrpcRequestString(QString method, QString arguments) const;

    // Parameter is the version for which the message applies,
    // not the message text itself
    Q_INVOKABLE void addDeviceMessageForVersion(QString appVersion);

    Q_INVOKABLE QString timeToString(uint64_t unixSeconds, bool divideByThousand = false);

    Q_INVOKABLE int intToMessageStatus(int status);

    // The passphrase for database encryption is passed from QML via this
    // method. If twiceChecked is true, QML has asked for it twice and both
    // entries by the user match.
    // The method will try to open any closed accounts. Signals emitted are:
    // - databaseDecryptionSuccess: database(s) could be opened
    // - databaseDecryptionFailure: database(s) could not be opended
    // - noEncryptedDatabases: passphrase could not be checked because
    //   there are no encrypted accounts (see method body for details on this)
    Q_INVOKABLE void setDatabasePassphrase(QString passphrase, bool twiceChecked);

    // returns the QSetting "encryptDb" (NOT whether actual
    // encrypted accounts exist, for this see hasEncryptedAccounts())
    Q_INVOKABLE bool databaseIsEncryptedSetting();

    // returns whether closed accounts exist at the moment
    Q_INVOKABLE bool hasEncryptedAccounts();

    // returns whether the database passphrase is available
    Q_INVOKABLE bool hasDatabasePassphrase();

    Q_INVOKABLE void invalidateDatabasePassphrase();

    Q_INVOKABLE int numberOfAccounts();

    // needed to determine whether the conversion from unencrypted
    // to encrypted database (or vice versa) is possible.
    // Conversion depends on exporting the accounts, which is
    // only possible if they are configured.
    Q_INVOKABLE int numberOfUnconfiguredAccounts();

    Q_INVOKABLE int numberOfEncryptedAccounts();

    Q_INVOKABLE bool isCurrentDatabasePassphrase(QString pw);

    Q_INVOKABLE void changeDatabasePassphrase(QString newPw);

    // will set the QSetting "encryptDb"
    Q_INVOKABLE void changeEncryptedDatabaseSetting(bool shouldBeEncrypted = true);

    Q_INVOKABLE void prepareDbConversionToEncrypted();

    Q_INVOKABLE bool workflowToEncryptedPending();

    // performs cleanup tasks after successfully completing a
    // WorkflowDbToEncrypted
    Q_INVOKABLE void databaseEncryptionCleanup();

    Q_INVOKABLE void prepareDbConversionToUnencrypted();

    Q_INVOKABLE bool workflowToUnencryptedPending();

    Q_INVOKABLE void databaseDecryptionCleanup();

    bool isClosedAccount(uint32_t accID);

    // see m_momentaryChatId below
    Q_INVOKABLE void setMomentaryChatIdByIndex(int myindex);
    Q_INVOKABLE void setMomentaryChatIdById(uint32_t myId);

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

    Q_INVOKABLE void deleteTemporaryAccount();

    Q_INVOKABLE void start_io();

    Q_INVOKABLE void stop_io();

    Q_INVOKABLE bool isBackupFile(QString filePath);

    Q_INVOKABLE void importBackupFromFile(QString filePath);

    Q_INVOKABLE void chatAccept();

    Q_INVOKABLE void chatDeleteContactRequest();

    Q_INVOKABLE void chatBlockContactRequest();

    Q_INVOKABLE void exportBackup();

    Q_INVOKABLE QString getUrlToExport();

    // Mainly used to remove backup files right
    // after they have been exported via ContentHub
    Q_INVOKABLE void removeTempExportFile();

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

    Q_INVOKABLE int getConnectivitySimple();
    Q_INVOKABLE QString getConnectivityHtml();

    /* ========================================================
     * ===============Self Profile editing ====================
     * ======================================================== */
    Q_INVOKABLE QString getCurrentSignature();

    Q_INVOKABLE void startProfileEdit();

    Q_INVOKABLE void setProfileValue(QString key, QString newValue);

    Q_INVOKABLE void finalizeProfileEdit();

    /* ============== End Self Profile editing ================ */

    /* ========================================================
     * ============== Other Profile editing ===================
     * ======================================================== */

    Q_INVOKABLE QString getOtherDisplayname(uint32_t userID);

    Q_INVOKABLE QString getOtherProfilePic(uint32_t userID);

    Q_INVOKABLE QString getOtherInitial(uint32_t userID);

    Q_INVOKABLE bool showContactCheckmark(uint32_t userID);

    Q_INVOKABLE QString getOtherColor(uint32_t userID);

    Q_INVOKABLE QString getOtherAddress(uint32_t userID);

    Q_INVOKABLE QString getOtherStatus(uint32_t userID);

    Q_INVOKABLE QString getOtherVerifiedBy(uint32_t userID);

    Q_INVOKABLE QString getOtherLastSeen(uint32_t userID);

    Q_INVOKABLE bool otherContactIsDevice(uint32_t userID);

    // Sets the username to newName and returns it.
    // Passing empty string will reset the username back to the
    // one received by the network and returns it, if it exists.
    Q_INVOKABLE QString setOtherUsername(uint32_t userID, QString newName);

    /* ============== End Other Profile editing =============== */

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

    // Starts the process to add a second device; this device
    // will act as primary device. Will emit backupProviderCreationSuccess
    // upon success and backupProviderCreationFailed upon failure
    Q_INVOKABLE void prepareBackupProvider();
    Q_INVOKABLE QString getBackupProviderSvg();
    Q_INVOKABLE QString getBackupProviderTxt();
    Q_INVOKABLE void cancelBackupProvider();

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

    Q_INVOKABLE bool prepareQrDecoder();
    Q_INVOKABLE void evaluateQrImage(QImage image, bool emitFailureSignal = false);
    Q_INVOKABLE void loadQrImage(QString filepath);
    /* ============ End QR code related stuff ================= */

    /* ========================================================
     * =============== Audio message recording ================
     * ======================================================== */
    Q_INVOKABLE bool startAudioRecording(int recordingQuality);
    Q_INVOKABLE void dismissAudioRecording();
    Q_INVOKABLE void stopAudioRecording();
    /* ============ End audio message recording =============== */

    Q_INVOKABLE void setEnablePushNotifications(bool enabled);
    Q_INVOKABLE void setDetailedPushNotifications(bool detailed);
    Q_INVOKABLE void setAggregatePushNotifications(bool aggregated);

    // Copies the given file to another location in the cache.
    // Used for, e.g., enabling ContentHub to immediately remove
    // the file in HubIncoming (can't be removed by the app itself,
    // finalize() has to be called on ContentTransfer).
    Q_INVOKABLE QString copyToCache(QString fromFilePath);

    // Will be executed when the app is closed
    Q_INVOKABLE void shutdownTasks();

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
    Q_PROPERTY(WorkflowDbToEncrypted* workflowdbencryption READ workflowdbencryption NOTIFY workflowdbencryptionChanged());
    Q_PROPERTY(WorkflowDbToUnencrypted* workflowdbdecryption READ workflowdbdecryption NOTIFY workflowdbdecryptionChanged());

    ChatModel* chatmodel();
    AccountsModel* accountsmodel();
    ContactsModel* contactsmodel();
    BlockedContactsModel* blockedcontactsmodel();
    GroupMemberModel* groupmembermodel();
    EmitterThread* emitterthread();
    WorkflowDbToEncrypted* workflowdbencryption();
    WorkflowDbToUnencrypted* workflowdbdecryption();

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
    void workflowdbencryptionChanged();
    void workflowdbdecryptionChanged();

    void chatlistShowsArchivedOnly(bool showsArchived);


    void newJsonrpcResponse(QString response);

    // In case of encrypted databases
    void databaseDecryptionSuccess();
    void databaseDecryptionFailure();
    void noEncryptedDatabase();

    // emitted if
    // - the event DC_EVENT_CHAT_MODIFIED is received
    // - a username was modified by the user
    void chatDataChanged();

    // Informs about provider specific prerequisites
    // when setting up a new account via login with
    // email address + password
    void providerHint(QString provHint);
    void providerInfoUrl(QString provUrl);

    // working == true: The provider can be used with DC (but may require
    // preparations as indicated via providerHint).
    // working == false: DC does not work with the provider (reason given
    // via providerHint)
    // The status "OK" as listed on providers.delta.chat is signalled
    // indirectly via providerStatus(true) and providerHint("").
    void providerStatus(bool working);

    void hasConfiguredAccountChanged();
    void networkingIsAllowedChanged();
    void networkingIsStartedChanged();
    void accountChanged();
    void msgsChanged(int msgID);
    void messageRead(int msgID);
    void messageDelivered(int msgID);
    void messageFailed(int msgID);
    void messageReaction(int msgID);
    void progressEventReceived(int perMill, QString errorMsg);
    void imexEventReceived(int perMill);
    void newUnconfiguredAccount();
    void newConfiguredAccount();
    void updatedAccountConfig(uint32_t);
    void chatIsContactRequestChanged();
    void openChatViewRequest(uint32_t accID, uint32_t chatID);
    void chatViewClosed(bool gotoQrScanPage);
    void newTempProfilePic(QString);
    void chatBlockContactDone();
    void connectivityChangedForActiveAccount();

    // For adding second device; see prepareBackupProvider().
    void backupProviderCreationSuccess();
    void backupProviderCreationFailed(QString errorMessage);

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

    // requests the search bar to be cleared (e.g., by Main.qml)
    void clearChatlistQueryRequest();

    /* ========================================================
     * ================ QR code related stuff =================
     * ======================================================== */
    void finishedSetConfigFromQr(bool successful);
    void readyForQrBackupImport();

    void qrDecoded(QString qrContent);
    void qrDecodingFailed(QString errorMessage);
    /* ============ End QR code related stuff ================= */

    void errorEvent(QString errorMessage);

public slots:
    void unrefTempContext();
    void chatViewIsClosed(bool gotoQrScanPage);

    void deleteQrDecoder();

    void prepareContactsmodelForGroupMemberAddition();

    // Main.qml emits a signal every 5 minutes that is connected
    // to this slot
    void periodicTimerActions();

    void updateChatlistQueryText(QString query);

    void triggerProviderHintSignal(QString emailAddress);

    void receiveJsonrcpResponse(QString response);

protected:
    QHash<int, QByteArray> roleNames() const;

private slots:
    void messagesChanged(uint32_t accID, int chatID, int msgID);
    void messagesNoticed(uint32_t accID, int chatID);
    void chatDataModifiedReceived(uint32_t, int);
    void incomingMessage(uint32_t accID, int chatID, int msgID);
    void messageReadByRecipient(uint32_t accID, int chatID, int msgID);
    void messageDeliveredToServer(uint32_t accID, int chatID, int msgID);
    void messageFailedSlot(uint32_t accID, int chatID, int msgID);
    void msgReactionsChanged(uint32_t accID, int chatID, int msgID);
    void progressEvent(int perMill, QString errorMsg);
    void imexBackupImportProgressReceiver(int perMill);
    void imexBackupExportProgressReceiver(int perMill);
    void imexBackupProviderProgressReceiver(int perMill);
    void imexFileReceiver(QString filepath);
    void chatCreationReceiver(uint32_t chatID);
    void updateCurrentChatMessageCount();
    void resetCurrentChatMessageCount();
    void removeClosedAccountFromList(uint32_t accID);
    void resetPassphrase();
    void addClosedAccountToList(uint32_t accID);
    void connectivityUpdate(uint32_t accID);
    void finishDeleteActiveNotificationTags(QDBusPendingCallWatcher* call);
    void processSignalQueueTimerTimeout();



private:
    dc_accounts_t* allAccounts;
    dc_context_t* currentContext;
    // TODO: rename tempContext, name's too similar to
    // local variables used in functions (tempText, tempLot etc.)
    dc_context_t* tempContext; // for creation of new account
    std::vector<uint32_t> m_chatlistVector;

    EmitterThread* eventThread;
    JsonrpcResponseThread* m_jsonrpcResponseThread;
    dc_jsonrpc_instance_t* m_jsonrpcInstance;
    ChatModel* m_chatmodel;
    AccountsModel* m_accountsmodel;
    BlockedContactsModel* m_blockedcontactsmodel;
    ContactsModel* m_contactsmodel;
    GroupMemberModel* m_groupmembermodel;
    WorkflowDbToEncrypted* m_workflowDbEncryption;
    WorkflowDbToUnencrypted* m_workflowDbDecryption;

    uint32_t m_currentAccID;
    uint32_t currentChatID;
    bool chatmodelIsConfigured;
    bool m_hasConfiguredAccount;

    // This member is needed, it can't just be
    // replaced by settings->value("encryptDb").toBool()
    // because the setting might not exist
    bool m_encryptedDatabase;

    QString m_databasePassphrase;
    std::vector<uint32_t> m_closedAccounts;
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
    uint32_t m_momentaryChatId;

    // for searching the chatlist
    QString m_query;

    // for scanning QR codes
    int m_qrTempState;
    uint32_t m_qrTempContactID;
    QString m_qrTempText;
    QString m_qrTempLotTextOne;

    struct quirc* m_qr;

    // Tag of the most recent notification
    QString m_lastTag;

    // used to store the beginning of tags that should
    // maybe be removed, consists of <accID>_<chatID>_, will
    // be set in deleteActiveNotificationTags and used
    // in finishDeleteActiveNotificationTags
    QString m_tagsToDelete;

    bool m_enablePushNotifications;
    bool m_detailedPushNotifications;
    bool m_aggregatePushNotifications;
    // if true, the previous push notification is removed when creating a new one
    bool m_aggregateNotifications;

    // for recording of audio messages
    QAudioRecorder* m_audioRecorder;

    // for acting as primary device when adding second device
    dc_backup_provider_t* m_backupProvider;

    bool m_coreTranslationsAlreadySet;

    mutable uint32_t m_jsonrpcRequestId;

    uint32_t getJsonrpcRequestId() const;

    // for the signal queue
    bool m_signalQueue_refreshChatlist;
    std::queue<int> m_signalQueue_chatsDataChanged;
    std::queue<int> m_signalQueue_chatsNoticed;
    std::queue<int> m_signalQueue_msgs;
    std::queue<checkNotificationsStruct> m_signalQueue_notificationsToRemove;
    //std::queue<MsgsChangedInfoStruct> m_msgsChangedQueue;
    QTimer* m_signalQueueTimer;

    static constexpr int queueTimerFreq = 1000;

    /**************************************
     *********   Private methods   ********
     **************************************/
    bool isExistingChat(uint32_t chatID);
    void setCoreTranslations();
    void contextSetupTasks();
    void sendNotification(uint32_t accID, int chatID, int msgID);

    void deleteActiveNotificationTags(uint32_t accID, int chatID);
    void enableVerifiedOneOnOneForAllAccs();
    void addDeviceMessageToAllContexts(QString deviceMessage, QString messageLabel);

    void processSignalQueue();
    bool isQueueEmpty();
    void refreshChatlistVector(dc_chatlist_t* tempChatlist);
    void resetChatlistVector(dc_chatlist_t* tempChatlist);
};

#endif // DELTAHANDLER_H
