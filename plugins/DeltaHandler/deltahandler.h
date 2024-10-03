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

#ifndef DELTAHANDLER_H
#define DELTAHANDLER_H

#include <QtCore>
#include <QtGui>
#include <QAudioRecorder>
#include <QDBusPendingCallWatcher>
#include <QtDBus/QDBusConnection>
#include <string>
#include <array>
#include <vector>
#include <queue>
#include <atomic>

#include "chatmodel.h"
#include "accountsmodel.h"
#include "blockedcontactsmodel.h"
#include "contactsmodel.h"
#include "dbusUrlReceiver.h"
#include "groupmembermodel.h"
#include "emitterthread.h"
#include "jsonrpcresponsethread.h"
#include "notificationHelper.h"
#include "workflowConvertDbToEncrypted.h"
#include "workflowConvertDbToUnencrypted.h"
#include "fileImportSignalHelper.h"

#include "deltachat.h"
#include "quirc.h"

struct AccIdAndChatIdStruct {
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
class NotificationHelper;
class NotificationsLomiriPostal;
class NotificationsFreedesktop;
class NotificationsMissing;
class WorkflowDbToEncrypted;
class WorkflowDbToUnencrypted;
class DbusUrlReceiver;

class DeltaHandler : public QAbstractListModel {
    Q_OBJECT
public:
    explicit DeltaHandler(QObject *parent = 0);
    ~DeltaHandler();

    enum { ChatlistEntryRole, BasicChatInfoRole };
    //enum { AccountIdRole, ChatlistEntryRole, ChatIdRole, BasicChatInfoRole };

    // TODO: belongs to ChatModel, but ChatModel isn't registered as
    // a module in Qt (yet?).
    enum MsgViewType { AudioType, FileType, GifType, ImageType, StickerType, TextType, VcardType, VideoType, VideochatInvitationType, VoiceType, WebxdcType, UnknownType };
    Q_ENUM(MsgViewType)

    // TODO: belongs to ChatModel, but ChatModel isn't registered as
    // a module in Qt (yet?).
    enum MsgState { StateUnknown, StatePending, StateFailed, StateDelivered, StateReceived };
    Q_ENUM(MsgState)

    // TODO: belongs to ChatModel, but ChatModel isn't registered as
    // a module in Qt (yet?).
    enum DownloadState { DownloadDone, DownloadAvailable, DownloadInProgress, DownloadFailure };
    Q_ENUM(DownloadState)

    enum QrState { DT_QR_ASK_VERIFYCONTACT, DT_QR_ASK_VERIFYGROUP, DT_QR_FPR_OK, DT_QR_FPR_MISMATCH, DT_QR_FPR_WITHOUT_ADDR, DT_QR_ACCOUNT, DT_QR_BACKUP, DT_QR_BACKUP2, DT_QR_WEBRTC_INSTANCE, DT_QR_ADDR, DT_QR_TEXT, DT_QR_URL, DT_QR_ERROR, DT_QR_WITHDRAW_VERIFYCONTACT, DT_QR_WITHDRAW_VERIFYGROUP, DT_QR_REVIVE_VERIFYCONTACT, DT_QR_REVIVE_VERIFYGROUP, DT_QR_LOGIN, DT_UNKNOWN };
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
    
    Q_INVOKABLE bool onUbuntuTouch();

    Q_INVOKABLE bool shouldOpenOskViaDbus();

    Q_INVOKABLE void loadSelectedAccount();

    Q_INVOKABLE uint32_t getCurrentAccountId() const;

    // returns the ID of the currently opened chat (-1 if no
    // chat opened)
    int getCurrentChatId() const;

    Q_INVOKABLE void sendJsonrpcRequest(QString request);

    Q_INVOKABLE QString sendJsonrpcBlockingCall(QString request) const;

    // Checks if a jsonrpc response from the core contains an
    // error.
    // Returns the error as string; "Error" if the response has an error without
    // an error message; empty string if no error.
    Q_INVOKABLE QString getErrorFromJsonrpcResponse(QString jsonrpcResponse);

    // Returns a valid jsonrpc request for the method and arguments passed.
    // The arguments have to be separated by ", " in one single string.
    // String arguments have to be inside escaped quotation marks.
    // Example for a method call:
    // constructJsonrpcRequestString("get_backup", "12, \"qrcode:xxxxx\"");
    Q_INVOKABLE QString constructJsonrpcRequestString(QString method, QString arguments) const;

    // Parameter is the version for which the message applies,
    // not the message text itself
    Q_INVOKABLE void addDeviceMessageForVersion(QString appVersion, QString oldVersion);

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

    // Select a chat for opening. CAVE Won't open the selected chat; for that,
    // openChat() has to be called
    Q_INVOKABLE void selectChatByIndex(int myindex);
    Q_INVOKABLE void selectChatByChatId(uint32_t _chatId);

    Q_INVOKABLE void selectAndOpenLastChatId();

    // _messageBody is a draft text for the chat. It will be set in case
    // the chat ID has been set via a mailto: url that contained body
    // text. Otherwise, it will be an empty string.
    // In the current implementation, if _messageBody is set, any other
    // draft message of this chat will be overriden and consequently, lost.
    Q_INVOKABLE void openChat(QString _messageBody = "", QString _filepathToAttach = "");

    Q_INVOKABLE void setChatViewIsShown();

    Q_INVOKABLE void archiveMomentaryChat();

    Q_INVOKABLE void unarchiveMomentaryChat();

    Q_INVOKABLE void pinUnpinMomentaryChat();

    Q_INVOKABLE bool momentaryChatIsMuted();

    Q_INVOKABLE void momentaryChatSetMuteDuration(int64_t secondsToMute);

    Q_INVOKABLE void closeArchive();

    Q_INVOKABLE QString getChatNameById(uint32_t chatId);
    Q_INVOKABLE bool chatIdHasDraft(uint32_t chatId);

    // Param calledInUrlHandlingProcess needed for handling of urls that
    // trigger the question with which account they should be handled
    // (e.g. openpgp4fpr) with, so the signal accountForUrlProcessingSelected is
    // emitted even if the account is the already active one.
    Q_INVOKABLE void selectAccount(uint32_t newAccID, bool calledInUrlHandlingProcess = false);

    Q_INVOKABLE void openOskViaDbus();
    Q_INVOKABLE void closeOskViaDbus();

    void removeActiveNotificationsOfChat(uint32_t accID, int chatID);

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

    Q_INVOKABLE QString getCurrentProfileColor();

    // TODO: replace all getCurrentXY() by this method (EXCEPT
    // the ones that return a path, see the data() method in chatmodel.cpp,
    // ProfilePicRole case)
    Q_INVOKABLE QString getCurrentConfig(QString key);

    Q_INVOKABLE void setCurrentConfig(QString key, QString newValue);

    // returns whether tempContext is already configured
    Q_INVOKABLE bool prepareTempContextConfig();

    Q_INVOKABLE void configureTempContext();

    Q_INVOKABLE void setTempContext(uint32_t accID);

    Q_INVOKABLE QString getTempContextConfig(QString key);

    Q_INVOKABLE void setTempContextConfig(QString key, QString val);

    Q_INVOKABLE void deleteTemporaryAccount();

    Q_INVOKABLE void start_io();

    Q_INVOKABLE void stop_io();

    Q_INVOKABLE bool isValidAddr(QString address);

    Q_INVOKABLE bool isBackupFile(QString filePath);

    Q_INVOKABLE void importBackupFromFile(QString filePath);

    Q_INVOKABLE void chatAccept();

    Q_INVOKABLE void chatDeleteContactRequest();

    Q_INVOKABLE void chatBlockContactRequest();

    Q_INVOKABLE void exportBackup();

    Q_INVOKABLE QString saveBackupFile(QString destinationFolder);

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
    // (i.e., the one in m_currentChatID) if -1 is
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

    Q_INVOKABLE int getConnectivitySimple();
    Q_INVOKABLE QString getConnectivityHtml();

    Q_INVOKABLE QString saveLog(QString logtext, QString datetime);

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

    Q_INVOKABLE void startCreateGroup();
    
    // will set up the currently active chat
    // (i.e., the one in m_currentChatID) if -1 is
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
    Q_INVOKABLE QString getTempGroupQrTxt();
    Q_INVOKABLE QString getTempGroupQrLink();

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
    Q_INVOKABLE QString getQrInviteLink();
    Q_INVOKABLE QString getQrContactEmail();
    Q_INVOKABLE QString getQrTextOne();
    Q_INVOKABLE int evaluateQrCode(QString clipboardData);

    // Param calledAfterUrlReceived: Set to true if this function
    // is called as part of the handling of an URL that was passed
    // as parameter (in contrast to active scanning of a QR code).
    // See also comment for finishedSetConfigFromQr.
    Q_INVOKABLE void continueQrCodeAction();
    // Param calledAfterUrlReceived: see comments for continueQrCodeAction
    Q_INVOKABLE void cancelQrImport();

    Q_INVOKABLE bool prepareQrDecoder();
    Q_INVOKABLE void evaluateQrImage(QImage image, bool emitFailureSignal = false);
    Q_INVOKABLE void loadQrImage(QString filepath);
    Q_INVOKABLE bool qrOverwritesDraft();
    /* ============ End QR code related stuff ================= */

    /* ========================================================
     * =============== Audio message recording ================
     * ======================================================== */
    Q_INVOKABLE bool startAudioRecording(int recordingQuality);
    Q_INVOKABLE void dismissAudioRecording();
    Q_INVOKABLE void stopAudioRecording();
    /* ============ End audio message recording =============== */

    // Copies the given file to another location in the cache.
    // Used for, e.g., enabling ContentHub to immediately remove
    // the file in HubIncoming (can't be removed by the app itself,
    // finalize() has to be called on ContentTransfer).
    Q_INVOKABLE QString copyToCache(QString fromFilePath);

    Q_INVOKABLE void newFileImportSignalHelper();
    Q_INVOKABLE void deleteFileImportSignalHelper();

    Q_INVOKABLE void emitFontSizeChangedSignal();

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
    Q_PROPERTY(NotificationHelper* notificationHelper READ notificationHelper NOTIFY notificationHelperChanged);
    Q_PROPERTY(WorkflowDbToEncrypted* workflowdbencryption READ workflowdbencryption NOTIFY workflowdbencryptionChanged());
    Q_PROPERTY(WorkflowDbToUnencrypted* workflowdbdecryption READ workflowdbdecryption NOTIFY workflowdbdecryptionChanged());
    Q_PROPERTY(FileImportSignalHelper* fileImportSignalHelper READ fileImportSignalHelper NOTIFY fileImportSignalHelperChanged());

    ChatModel* chatmodel();
    AccountsModel* accountsmodel();
    ContactsModel* contactsmodel();
    BlockedContactsModel* blockedcontactsmodel();
    GroupMemberModel* groupmembermodel();
    EmitterThread* emitterthread();
    NotificationHelper* notificationHelper();
    WorkflowDbToEncrypted* workflowdbencryption();
    WorkflowDbToUnencrypted* workflowdbdecryption();
    FileImportSignalHelper* fileImportSignalHelper();

    Q_PROPERTY(bool hasConfiguredAccount READ hasConfiguredAccount NOTIFY hasConfiguredAccountChanged);
    Q_PROPERTY(bool networkingIsAllowed READ networkingIsAllowed NOTIFY networkingIsAllowedChanged);
    Q_PROPERTY(bool networkingIsStarted READ networkingIsStarted NOTIFY networkingIsStartedChanged);
    Q_PROPERTY(bool chatIsContactRequest READ chatIsContactRequest NOTIFY chatIsContactRequestChanged);

    bool hasConfiguredAccount();
    bool networkingIsAllowed();
    bool networkingIsStarted();
    bool chatIsContactRequest();

    void processReceivedUrl(QString myUrl);
    std::atomic<bool> m_stopThreads;

signals:
    // TODO the models never change, they communicate
    // changes themselves
    void chatmodelChanged();
    void accountsmodelChanged();
    void contactsmodelChanged();
    void blockedcontactsmodelChanged();
    void groupmembermodelChanged();
    void emitterthreadChanged();
    void notificationHelperChanged();
    void workflowdbencryptionChanged();
    void workflowdbdecryptionChanged();
    void fileImportSignalHelperChanged();
    
    void chatlistShowsArchivedOnly(bool showsArchived);
    void closeChatViewRequest();
    void chatlistToBeginning();

    void fontSizeChanged();

    void newJsonrpcResponse(QString response);

    // In case of encrypted databases
    void databaseDecryptionSuccess();
    void databaseDecryptionFailure();
    void noEncryptedDatabase();

    // emitted if
    // - the event DC_EVENT_CHAT_MODIFIED is received
    // - a username was modified by the user
    void chatDataChanged();

    // emitted if a chat was a contact request,
    // but is not anymore because the request was
    // accepted, deleted or blocked
    void chatIsNotContactRequestAnymore(uint32_t accID, uint32_t chatID);

    // Informs about provider specific prerequisites
    // when setting up a new account via login with
    // email address + password
    // Parameter "address" is the mail address for which the
    // hint or the Url is valid
    void providerHint(QString provHint, QString address);
    void providerInfoUrl(QString provUrl, QString address);

    // working == true: The provider can be used with DC (but may require
    // preparations as indicated via providerHint).
    // working == false: DC does not work with the provider (reason given
    // via providerHint)
    // The status "OK" as listed on providers.delta.chat is signalled
    // indirectly via providerStatus(true) and providerHint("").
    // Parameter "address" is the mail address for which the
    // status is valid
    void providerStatus(bool working, QString address);

    void hasConfiguredAccountChanged();
    void networkingIsAllowedChanged();
    void networkingIsStartedChanged();
    void accountChanged();
    void accountDataChanged();
    void msgsChanged(int msgID);
    void messageRead(int msgID);
    void messageDelivered(int msgID);
    void messageFailed(int msgID);
    void messageReaction(int msgID);
    void progressEventReceived(int perMill, QString errorMsg);
    void imexEventReceived(int perMill);
    void newUnconfiguredAccount();
    void newConfiguredAccount();
    void accountIsConfiguredChanged(uint32_t);
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

    void qrDecoded(QString qrContent);
    void qrDecodingFailed(QString errorMessage);

    // not really QR code, but related: URL handling
    // urlReceived signals that an Url has been passed to the app
    // (needed on non-UT platforms only)
    void urlReceived(QString myUrl);

    void accountForUrlProcessingSelected();
    /* ============ End QR code related stuff ================= */

    void errorEvent(QString errorMessage);

public slots:
    void appIsActiveAgainActions();
    void unrefTempContext();
    void chatViewIsClosed(bool gotoQrScanPage);
    void deleteQrDecoder();
    void prepareContactsmodelForGroupMemberAddition();

    // Main.qml emits a signal every 5 minutes that is connected
    // to this slot
    void periodicTimerActions();
    void updateChatlistQueryText(QString query);
    void getProviderHintSignal(QString emailAddress);
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

    // _messageBody is a draft text for the chat. It will be set in case
    // the chat ID has been set via a mailto: url that contained body
    // text. Otherwise, it will be an empty string.
    // In the current implementation, if _messageBody is set, any other
    // draft message of this chat will be overriden and consequently, lost.
    void chatCreationReceiver(uint32_t chatID, QString _messageBody = "");
    void updateCurrentChatMessageCount();
    void resetCurrentChatMessageCount();
    void removeClosedAccountFromList(uint32_t accID);
    void resetPassphrase();
    void addClosedAccountToList(uint32_t accID);
    void connectivityUpdate(uint32_t accID);
    void processSignalQueueTimerTimeout();
    void internalOpenOskViaDbus();
    void startQrBackupImport();


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
    FileImportSignalHelper* m_fileImportSignalHelper;

    uint32_t m_currentAccID;
    uint32_t m_currentChatID;

    // Page with chat is opened, but the app
    // is not necessarily shown at the screen atm
    bool currentChatIsOpened;
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
    bool editingVerifiedGroup;

    // Stores the chat ID of the chatlist index for which
    // an action was triggered. Reason is that QML does not
    // have the type uint32_t, and using the chatlist index
    // is unsafe because the index of the selected chat might
    // change in the background while the user is still
    // in some action page
    uint32_t m_momentaryChatId;

    // for searching the chatlist
    QString m_query;

    QDBusConnection m_bus;

    // for scanning QR codes
    int m_qrTempState;
    uint32_t m_qrTempContactID;
    QString m_qrTempText;
    QString m_qrTempLotTextOne;

    struct quirc* m_qr;

    // for recording of audio messages
    QAudioRecorder* m_audioRecorder;

    // for acting as primary device when adding second device
    dc_backup_provider_t* m_backupProvider;

    bool m_coreTranslationsAlreadySet;

    mutable uint32_t m_jsonrpcRequestId;

    uint32_t getJsonrpcRequestId() const;

    // for the signal queue
    bool m_signalQueue_refreshChatlist;

    // queue for the active account
    std::queue<int> m_signalQueue_chatsDataChanged;
    std::queue<int> m_signalQueue_chatsNoticed;
    std::queue<int> m_signalQueue_msgs;
    std::queue<AccIdAndChatIdStruct> m_signalQueue_notificationsToRemove;

    // vector for all accounts, will be used by m_accountsmodel,
    // contains all accID/chatID combinations for which DeltaHandler::messagesChanged()
    // was called
    std::vector<uint32_t> m_signalQueue_accountsmodelInfo;

    QTimer* m_signalQueueTimer;

    static constexpr int queueTimerFreq = 1000;

    bool m_onUbuntuTouch;
    bool m_isDesktopMode;
    bool m_openOskViaDbus;

    NotificationHelper* m_notificationHelper;

    QObject dbusUrlReceiverObj;
    /**************************************
     *********   Private methods   ********
     **************************************/
    bool isExistingChat(uint32_t chatID);
    void setCoreTranslations();
    void contextSetupTasks();

    void enableVerifiedOneOnOneForAllAccs();
    void addDeviceMessageToAllContexts(QString deviceMessage, QString messageLabel);

    void processSignalQueue();
    bool isQueueEmpty();

    // adapts the internal chatlist to tempChatlist via
    // move, remove and insert operations
    void refreshChatlistVector(dc_chatlist_t* tempChatlist);
    
    // adapts the internal chatlist to tempChatlist via
    // beginResetModel() / endResetModel()
    void resetChatlistVector(dc_chatlist_t* tempChatlist);

    void triggerProviderHintSignal(QString emailAddress);
};

#endif // DELTAHANDLER_H
