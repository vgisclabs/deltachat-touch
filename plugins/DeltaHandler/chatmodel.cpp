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

#include "chatmodel.h"
#include <stdio.h> // for remove()
//#include <unistd.h> // for sleep
#include <limits> // for invalidating data_row

ChatModel::ChatModel(QObject* parent)
    : QAbstractListModel(parent), currentMsgContext {nullptr}, chatID {0}, m_chatIsBeingViewed {false}, currentMsgCount {0}, currentMessageDraft {nullptr}, m_chatlistmodel {nullptr}, messageIdToForward {0}, data_row {std::numeric_limits<int>::max()}, data_tempMsg {nullptr}, m_query {""}, oldSearchMsgArray {nullptr}, currentSearchMsgArray {nullptr}
{ 
};

ChatModel::~ChatModel()
{
    if (currentMsgContext) {
        dc_context_unref(currentMsgContext);
    }

    if (data_tempMsg) {
        dc_msg_unref(data_tempMsg);
    }

    if (oldSearchMsgArray) {
        dc_array_unref(oldSearchMsgArray);
    }

    if (currentSearchMsgArray) {
        dc_array_unref(currentSearchMsgArray);
    }
}

int ChatModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return currentMsgCount;
}


QHash<int, QByteArray> ChatModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IsSelfRole] = "isSelf";
    roles[IsInfoRole] = "isInfo";
    roles[IsDownloadedRole] = "isDownloaded";
    roles[DownloadStateRole] = "downloadState";
    roles[IsForwardedRole] = "isForwarded";
    roles[MessageSeenRole] = "messageSeen";
    roles[MessageStateRole] = "messageState";
    roles[QuotedTextRole] = "quotedText";
    roles[QuoteUserRole] = "quoteUser";
    roles[QuoteIsSelfRole] = "quoteIsSelf";
    roles[MessageInfoRole] = "messageInfo";
    roles[DurationRole] = "duration";
    roles[IsUnreadMsgsBarRole] = "isUnreadMsgsBar";
    roles[TypeRole] = "msgViewType";
    roles[TextRole] = "text";
    roles[ProfilePicRole] = "profilePic";
    roles[IsSameSenderAsNextRole] = "isSameSenderAsNextMsg";
    roles[PadlockRole] = "hasPadlock";
    roles[DateRole] = "date";
    roles[UsernameRole] = "username";
    roles[SummaryTextRole] = "summarytext";
    roles[FilePathRole] = "filepath";
    roles[AudioFilePathRole] = "audiofilepath";
    roles[ImageWidthRole] = "imagewidth";
    roles[AvatarColorRole] = "avatarColor";
    roles[AvatarInitialRole] = "avatarInitial";
    roles[IsSearchResultRole] = "isSearchResult";
    roles[ContactIdRole] = "contactID";

    return roles;
}


QVariant ChatModel::data(const QModelIndex &index, int role) const
{
    int row = index.row();

    if(row < 0 || row >= currentMsgCount) {
        return QVariant();
    }

    dc_msg_t* tempMsg {nullptr};
    uint32_t tempMsgID {0};


    // checking if the cached dc_msg_t* (i.e., data_tempMsg) can be used;
    // this is the case if row == data_row and data_row != max int
    if (row != data_row || std::numeric_limits<int>::max() == data_row) {
        // the cached data_tempMsg cannot be used
        
        // don't try to get the msg from DC if it's
        // the Unread Message bar
        if (row != m_unreadMessageBarIndex) {
            tempMsgID = msgVector[row];
            tempMsg = dc_get_msg(currentMsgContext, tempMsgID);

            if (data_tempMsg) {
                dc_msg_unref(data_tempMsg);
                data_tempMsg = nullptr;
            }

            data_row = row;
            data_tempMsgID = tempMsgID;
            data_tempMsg = tempMsg;
        } 
    } else { // row == data_row, so the cached dc_msg_t* is valid
        tempMsg = data_tempMsg;
        tempMsgID = data_tempMsgID;
    }

    QString tempQString;
    char* tempText {nullptr};
    dc_contact_t* tempContact {nullptr};
    uint32_t contactID = 0;
    dc_msg_t* nextMsg {nullptr};
    QDateTime msgDate;
    uint32_t tempColor {0};
    QColor tempQColor;
    int tempInt {0};
    // TODO: use message-parser instead
    QRegExp weblinkRegExp("((?:http|https|ftp|ftps)://\\S+)");
    QRegExp alreadyFormattedAsLink("href=\"");
    
    QVariant retval;

    switch(role) {
        case ChatModel::IsSelfRole:
            if (dc_msg_get_from_id(tempMsg) == DC_CONTACT_ID_SELF) {
                retval = true;
            }
            else {
                retval = false;
            }
            break;

        case ChatModel::IsInfoRole:
            if (dc_msg_is_info(tempMsg)) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        case ChatModel::IsForwardedRole:
            if (dc_msg_is_forwarded(tempMsg)) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        case ChatModel::IsDownloadedRole: 
            if (dc_msg_get_download_state(tempMsg) == DC_DOWNLOAD_DONE) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        case ChatModel::DownloadStateRole:
            tempInt = dc_msg_get_download_state(tempMsg);
            switch(tempInt) {
                case DC_DOWNLOAD_DONE:
                    retval = DeltaHandler::DownloadState::DownloadDone;
                    break;

                case DC_DOWNLOAD_AVAILABLE:
                    retval = DeltaHandler::DownloadState::DownloadAvailable;
                    break;

                case DC_DOWNLOAD_IN_PROGRESS:
                    retval = DeltaHandler::DownloadState::DownloadInProgress;
                    break;

                case DC_DOWNLOAD_FAILURE:
                    retval = DeltaHandler::DownloadState::DownloadFailure;
                    break;
            }
            break;

        case ChatModel::MessageSeenRole:
            if (dc_msg_get_state(tempMsg) == DC_STATE_OUT_MDN_RCVD) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        case ChatModel::MessageStateRole:
            tempInt = dc_msg_get_state(tempMsg);
            switch(tempInt) {
                case DC_STATE_OUT_PENDING:
                    retval = DeltaHandler::MsgState::StatePending;
                    break;

                case DC_STATE_OUT_FAILED:
                    retval = DeltaHandler::MsgState::StateFailed;
                    break;

                case DC_STATE_OUT_DELIVERED:
                    retval = DeltaHandler::MsgState::StateDelivered;
                    break;

                case DC_STATE_OUT_MDN_RCVD:
                    retval = DeltaHandler::MsgState::StateReceived;
                    break;
            } 
            break;

        case ChatModel::QuotedTextRole:
            tempText = dc_msg_get_quoted_text(tempMsg);
            if (tempText) {
                tempQString = tempText;
            } else {
                tempQString = "";
            }
            retval = tempQString;
            break;

        case ChatModel::QuoteUserRole:
            // TODO: maybe rename nextMsg as it is used
            // for the quoted message, too?
            nextMsg = dc_msg_get_quoted_msg(tempMsg);

            if (nextMsg) {
                tempText = dc_msg_get_override_sender_name(nextMsg);
                if (tempText) {
                    tempQString = "~";
                    tempQString += tempText;
                } else {
                    tempText = dc_contact_get_display_name(dc_get_contact(currentMsgContext, dc_msg_get_from_id(nextMsg)));
                    tempQString = tempText;
                }
            } else {
                tempQString = "";
            }

            retval = tempQString;
            break;

        case ChatModel::QuoteIsSelfRole:
            nextMsg = dc_msg_get_quoted_msg(tempMsg);
            if (nextMsg) {
                if (dc_msg_get_from_id(nextMsg) == DC_CONTACT_ID_SELF) {
                    retval = true;
                }
                else {
                    retval = false;
                }
            } else { // no quoted message
                retval = false;
            }
            break;

        case ChatModel::MessageInfoRole:
            tempText = dc_get_msg_info(currentMsgContext, tempMsgID);
            tempQString = tempText;
            retval = tempQString;
            break;

        case ChatModel::DurationRole:
            tempQString = "";
            tempInt = dc_msg_get_duration(tempMsg);

            if (0 == tempInt) {
                tempQString = "??:??";
            } else {
                // duration is returned in ms, converting to s
                tempInt /= 1000;
                if (tempInt / 3600 > 0) {
                    tempQString.append(QString::number(tempInt / 3600));
                    tempQString.append(":");
                    tempInt = tempInt % 3600;
                }

                if (tempInt / 60 > 0) {
                    if (tempInt / 60 < 10) {
                        tempQString.append("0");
                    }
                    tempQString.append(QString::number(tempInt / 60));
                    tempQString.append(":");
                    tempInt = tempInt % 60;
                } else {
                    tempQString.append("00:");
                }

                if (tempInt > 10) {
                    tempQString.append(QString::number(tempInt));
                } else if (tempInt > 0) {
                    tempQString.append("0");
                    tempQString.append(QString::number(tempInt));
                } else {
                    tempQString.append("00");
                }
            }

            retval = tempQString;
            break;

        case ChatModel::IsUnreadMsgsBarRole:
            if (row == m_unreadMessageBarIndex) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        case ChatModel::TypeRole:
            switch (dc_msg_get_viewtype(tempMsg)) {
                case DC_MSG_AUDIO:
                    retval = QVariant(DeltaHandler::MsgViewType::AudioType);
                    break;

                case DC_MSG_FILE:
                    retval = QVariant(DeltaHandler::MsgViewType::FileType);
                    break;
                
                case DC_MSG_GIF:
                    retval = QVariant(DeltaHandler::MsgViewType::GifType);
                    break;
                
                case DC_MSG_IMAGE:
                    retval = QVariant(DeltaHandler::MsgViewType::ImageType);
                    break;
                
                case DC_MSG_STICKER:
                    retval = QVariant(DeltaHandler::MsgViewType::StickerType);
                    break;
                
                case DC_MSG_TEXT:
                    retval = QVariant(DeltaHandler::MsgViewType::TextType);
                    break;

                case DC_MSG_VIDEO:
                    retval = QVariant(DeltaHandler::MsgViewType::VideoType);
                    break;
                
                case DC_MSG_VIDEOCHAT_INVITATION:
                    retval = QVariant(DeltaHandler::MsgViewType::VideochatInvitationType);
                    break;
                
                case DC_MSG_VOICE:
                    retval = QVariant(DeltaHandler::MsgViewType::VoiceType);
                    break;

                case DC_MSG_WEBXDC:
                    retval = QVariant(DeltaHandler::MsgViewType::WebXdcType);
                    break;

                default:
                    qDebug() << "ChatModel: Unknown message type " << dc_msg_get_viewtype(tempMsg);
                    retval = QVariant(DeltaHandler::MsgViewType::UnknownType);
                    break;
            }
            break;

        case ChatModel::ProfilePicRole:
            contactID = dc_msg_get_from_id(tempMsg);
            tempContact = dc_get_contact(currentMsgContext, contactID);
            tempText = dc_contact_get_profile_image(tempContact);
            tempQString = tempText;
            // For some reason, the QML part doesn't like the path
            // as given by dc_contact_get_profile_image.
            // The file is located in the config dir, so we remove the
            // top level of the config dir part and put it back
            // together in QML again.
            // No idea what the difference is - should be exactly the same.
            tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
            retval = tempQString;
            break;

        case ChatModel::IsSameSenderAsNextRole:
            // Most recent message has sender of next message
            if (row == 0 || row - 1 == m_unreadMessageBarIndex) {
                retval = false;
            }
            else {
                // row - 1 corresponds to the next message
                tempMsgID = msgVector[row - 1];
                nextMsg = dc_get_msg(currentMsgContext, tempMsgID);
                if (dc_msg_is_info(nextMsg)) {
                    retval = false;
                } else if (dc_msg_get_from_id(nextMsg) == dc_msg_get_from_id(tempMsg)) {
                    retval = true;
                } 
                else {
                    retval = false;
                }
            }
            break;

        case ChatModel::PadlockRole:

            if (dc_msg_get_showpadlock(tempMsg)) {
                retval = true;
            }
            else {
                retval = false;
            }
            break;

        case ChatModel::DateRole:
            msgDate = QDateTime::fromSecsSinceEpoch(dc_msg_get_timestamp(tempMsg));
            if (msgDate.date() == QDate::currentDate()) {
                tempQString = msgDate.toString("hh:mm ");
                // TODO: if <user prefers am/pm> ...("hh:mm ap ")
            }
            else {
                tempQString = msgDate.toString("dd MMM yy hh:mm " );
                // TODO: "...hh:mm ap " as above
            }
            retval = tempQString;
            break;

        case ChatModel::UsernameRole:
            tempText = dc_msg_get_override_sender_name(tempMsg);
            if (!tempText) {
                tempText = dc_contact_get_display_name(dc_get_contact(currentMsgContext, dc_msg_get_from_id(tempMsg)));
                tempQString = tempText;
            } else {
                tempQString = "~";
                tempQString += tempText;
            }
            retval = tempQString;
            break;

        case ChatModel::SummaryTextRole:
            tempText = dc_msg_get_summarytext(tempMsg, 80);
            tempQString = tempText;
            if (tempQString == "") {
                tempQString = "no summary";
            }
            retval = tempQString;
            break;

        case ChatModel::FilePathRole:
            tempText = dc_msg_get_file(tempMsg);
            tempQString = tempText;
            // see ProfilePicRole above
            tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length() + 1);
            retval = tempQString;
            break;

        case ChatModel::AudioFilePathRole:
            tempText = dc_msg_get_file(tempMsg);
            tempQString = copyToCache(tempText);
            // see ProfilePicRole above
            //tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length() + 1);
            retval = tempQString;
            break;

        case ChatModel::ImageWidthRole:
            retval = dc_msg_get_width(tempMsg);
            break;

        case ChatModel::TextRole:
            tempText = dc_msg_get_text(tempMsg);
            tempQString = tempText;
            // TODO: use message-parser instead
            //
            // Check first whether the text is already formatted as link,
            // i.e., <a href="...
            // This is done by checking whether the message contains href="
            // If there are several links, and only one of them is already
            // formatted, the others are not be formatted by this solution,
            // but as QRegExp does not support negative lookbehind, I don't
            // see a simple solution. It's a temporary solution anyway
            // that is to be replaced by message-parser in the future.
            if (!tempQString.contains(alreadyFormattedAsLink)) {
                tempQString.replace(weblinkRegExp, "<a href=\"\\1\">\\1</a>");
            }
            retval = tempQString;

            break;

        case ChatModel::AvatarColorRole:
            contactID = dc_msg_get_from_id(tempMsg);
            tempContact = dc_get_contact(currentMsgContext, contactID);
            tempColor = dc_contact_get_color(tempContact);
            tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
            retval = QString(tempQColor.name());
            break;

        case ChatModel::AvatarInitialRole:
            contactID = dc_msg_get_from_id(tempMsg);
            tempContact = dc_get_contact(currentMsgContext, contactID);
            tempText = dc_contact_get_display_name(tempContact);
            tempQString = tempText;
            if (tempQString == "") {
                tempQString = "#";
            } else {
                tempQString = QString(tempQString.at(0)).toUpper();
            }
            retval = tempQString;
            break;

        case ChatModel::IsSearchResultRole:
            retval = false;
            if (currentSearchMsgArray) {
                for (size_t i = 0; i < dc_array_get_cnt(currentSearchMsgArray); ++i) {
                    if (tempMsgID == dc_array_get_id(currentSearchMsgArray, i)) {
                        retval = true;
                        break;
                    }
                }
            }
            break;

        case ChatModel::ContactIdRole:
            retval = dc_msg_get_from_id(tempMsg);
            break;

        default:
            retval = QVariant();
            qDebug() << "ChatModel::data switch reached default";
            break;
    }

    if (tempContact) {
        dc_contact_unref(tempContact);
        tempContact = nullptr;
    }

    if (nextMsg) {
        dc_msg_unref(nextMsg);
        nextMsg = nullptr;
    }

    if (tempText) {
        dc_str_unref(tempText);
        tempText = nullptr;
    }

    return retval;
}


void ChatModel::setMomentaryMessage(int myindex)
{
    m_MomentaryMsgId = msgVector[myindex];
}


void ChatModel::messageStatusChangedSlot(int msgID)
{

    // invalidate the cached data_tempMsg (see ChatModel::data())
    data_row = std::numeric_limits<int>::max();
    if (data_tempMsg) {
        dc_msg_unref(data_tempMsg);
        data_tempMsg = nullptr;
    }

    for (size_t i = 0; i < currentMsgCount; ++i) {
        if (msgID == msgVector[i]) {
            emit dataChanged(index(i, 0), index(i, 0));
            break;
        }
    }
}


void ChatModel::configure(uint32_t cID, dc_context_t* context, DeltaHandler* deltaHandler, std::vector<uint32_t> unreadMsgs, bool cIsContactRequest)
{
    m_dhandler = deltaHandler;

    beginResetModel();

    // invalidate the cached data_tempMsg (see ChatModel::data())
    data_row = std::numeric_limits<int>::max();
    if (data_tempMsg) {
        dc_msg_unref(data_tempMsg);
        data_tempMsg = nullptr;
    }

    m_isContactRequest = cIsContactRequest;

    chatID = cID;
    currentMsgContext = context;

    dc_array_t* msgArray = dc_get_chat_msgs(currentMsgContext, chatID, 0, 0);
    currentMsgCount = dc_array_get_cnt(msgArray);

    // When a chat is selected from the chat list, its existing
    // messages are obtained via dc_get_chat_msgs and copied into the
    // private member msgVector. When new messages arrive, msgVector
    // is updated, see newMessage(). 
    //
    // msgVector will be re-initialized upon entering a new chat by
    // sizing it accordingly and copying all msgIDs.
    msgVector.resize(currentMsgCount);

    m_hasUnreadMessages = false;

    m_unreadMessageBarIndex = -1;

    // For the view to show the most recent message at the bottom
    // without going through the whole list of messages,
    // verticalLayoutDirection is set to ListView.BottomToTop. Thus,
    // the most recent message has the index 0 in the view, so we have
    // to reverse the order.
    for (size_t i = 0; i < currentMsgCount; ++i) {
        msgVector[currentMsgCount - (i + 1)] = dc_array_get_id(msgArray, i);

        // go through all messages from the oldest to the newest
        // to check for the first unread message, but only if it's
        // not a contact request, because then the messages will only
        // be marked seen if the request is accepted
        if (!m_hasUnreadMessages && !m_isContactRequest) {
            for (size_t j = 0; j < unreadMsgs.size(); ++j) {
                if (unreadMsgs[j] == msgVector[currentMsgCount - (i + 1)]) {
                    m_hasUnreadMessages = true;
                    m_unreadMessageBarIndex = currentMsgCount - (i + 1);

                    // needed to re-create the Unread Message bar in newMessage()
                    m_firstUnreadMessageID = msgVector[currentMsgCount - (i + 1)];
                    break;
                }
            }
        }
    }

    // Marking all unread messages of this chat as seen if it's not a
    // contact request (in the latter case, m_hasUnreadMessages should
    // be false even though the messages have not been marked as seen,
    // see the previous loop; still checking for m_isContactRequest
    // for clarity and in case the above loop changes)
    if (m_hasUnreadMessages && !m_isContactRequest) {
        
        for (size_t i = 0; i < unreadMsgs.size(); ++i) {
            dc_markseen_msgs(currentMsgContext, unreadMsgs.data() + i, 1);
        }
        emit markedAllMessagesSeen();
    } else if (!m_isContactRequest) {
        // to check whether there are messages that are included in the count from
        // dc_get_fresh_msg_count, but are not in the freshMsgs vector
        emit markedAllMessagesSeen();
    }

    // insert an info message "Unread messages" above the first unread message
    if (m_hasUnreadMessages && !m_isContactRequest) {
        if (m_unreadMessageBarIndex == currentMsgCount - 1) {
            msgVector.push_back(0);
        } else {
            std::vector<uint32_t>::iterator it;
            it = msgVector.begin();
            msgVector.insert(it + (m_unreadMessageBarIndex + 1), 0);
        }
        ++m_unreadMessageBarIndex;
        ++currentMsgCount;
    }

    dc_array_unref(msgArray);

    bool connectSuccess = connect(m_dhandler, SIGNAL(msgsChanged(int)), this, SLOT(newMessage(int)));
    if (!connectSuccess) {
        qDebug() << "Chatmodel::configure: Could not connect signal msgsChanged to slot newMessage";
    }

    endResetModel();

    // if there's a leftover of a previous visit of
    // another (or even this) chat view, unref the draf
    // message
    // TODO: handle upon leaving the chat view page?
    if (currentMessageDraft) {
        dc_msg_unref(currentMessageDraft);
    }

    currentMessageDraft = dc_get_draft(currentMsgContext, chatID);
}


bool ChatModel::chatIsContactRequest()
{
    return m_isContactRequest;
}


void ChatModel::acceptChat() {
    m_isContactRequest = false;

    // mark message(s) seen
    for (size_t i = 0; i < currentMsgCount; ++i) {
        dc_markseen_msgs(currentMsgContext, msgVector.data() + i, 1);
    }
    emit markedAllMessagesSeen();

}

// Handles both DC_EVENT_INCOMING_MSG and DC_EVENT_MSGS_CHANGED. A
// separation might not make much sense because if a self message is
// sent from another device, DC_EVENT_MSGS_CHANGED is emitted. So in the
// case of both events, the vector containing the message IDs might have
// to be updated. The dataChanged part could maybe be omitted for
// incoming messages, but it shouldn't be too costly.
void ChatModel::newMessage(int msgID)
{
    // invalidate the cached data_tempMsg
    data_row = std::numeric_limits<int>::max();
    if (data_tempMsg) {
        dc_msg_unref(data_tempMsg);
        data_tempMsg = nullptr;
    }

    dc_array_t* newMsgArray = dc_get_chat_msgs(currentMsgContext, chatID, 0, 0);
    size_t newMsgCount = dc_array_get_cnt(newMsgArray);

    // idea for algorithm taken from kdeltachat, see
    // https://git.sr.ht/~link2xt/kdeltachat/tree/master
    for (size_t i = 0; i < newMsgCount; ++i) {
        size_t j;
        // reverse access the array
        uint32_t tempNewMsgID = dc_array_get_id(newMsgArray, (newMsgCount - 1) - i);

        for (j = i; j < currentMsgCount; ++j) {
            if (tempNewMsgID == msgVector[j]) {
                if (j != i) {
                    beginMoveRows(QModelIndex(), j, j, QModelIndex(), i);
                    msgVector[i] = msgVector[j];
                    endMoveRows();
                }

                // need to unset m_unreadMessageBarIndex in case
                // it is overwritten
                if (i == m_unreadMessageBarIndex) {
                    m_unreadMessageBarIndex = -1;
                }

                break;
            }
        }
        if (j == currentMsgCount) {
            std::vector<uint32_t>::iterator it;
            it = msgVector.begin();

            beginInsertRows(QModelIndex(), i, i);
            msgVector.insert(it+i, tempNewMsgID);

            ++currentMsgCount;
            endInsertRows();
            if (i <  currentMsgCount - 1) {
            }
        }
    }

    if (currentMsgCount > newMsgCount) {
        beginRemoveRows(QModelIndex(), newMsgCount, currentMsgCount - 1);
        msgVector.resize(newMsgCount);
        currentMsgCount = newMsgCount;
        endRemoveRows();
    }

    // re-insert the Unread Message bar. Will fail
    // if the first unread message has been deleted.
    // TODO: take care of this case?
    if (m_hasUnreadMessages) {
        for (size_t i = 0; i < currentMsgCount; ++i) {
            if (m_firstUnreadMessageID == msgVector[i]) {
                beginInsertRows(QModelIndex(), i+1, i+1);
                if (i == currentMsgCount - 1) {
                    msgVector.push_back(0);
                } else {
                    std::vector<uint32_t>::iterator it;
                    it = msgVector.begin();
                    msgVector.insert(it + i + 1, 0);
                }
                m_unreadMessageBarIndex = i+1;
                ++currentMsgCount;

                endInsertRows();

                break;
            }
        }
    }

    dc_array_unref(newMsgArray);

    // mark new message as seen
    dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, msgID);
    if (dc_msg_get_state(tempMsg) != DC_STATE_IN_SEEN && !(dc_msg_get_from_id(tempMsg) == DC_CONTACT_ID_SELF)) {
        const uint32_t tempMsgID = msgID;
        // only mark seen + remove the notification if the app is not 
        // in background
        if (QGuiApplication::applicationState() == Qt::ApplicationActive) {
            dc_markseen_msgs(currentMsgContext, &tempMsgID, 1);
            emit markedAllMessagesSeen();
        } else {
            msgsToMarkSeenLater.push_back(tempMsgID);
        }
    }
    dc_msg_unref(tempMsg);


    // The event DC_EVENT_MSGS_CHANGED, which eventually leads to the
    // execution of this method here, is also created if a partly
    // downloaded message has been fully downloaded.  Thus, data_changed
    // has to be emitted, either for the specific message ID (if > 0) or
    // for all of them. The model is not reset because this would be
    // problematic if the current view is not at the bottom, but
    // scrolled somewhere
    if (0 == msgID) {
        for (size_t i = 0; i < currentMsgCount ; ++i) {
            emit QAbstractItemModel::dataChanged(index(i, 0), index(i, 0));
        }
    } else {
        for (size_t i = 0; i < currentMsgCount ; ++i) {
            if (msgVector[i] == msgID) {
                emit QAbstractItemModel::dataChanged(index(i, 0), index(i, 0));
                break;
            }
        }
    }

    emit chatDataChanged();
}

void ChatModel::deleteMomentaryMessage()
{
    dc_delete_msgs(currentMsgContext, &m_MomentaryMsgId, 1);
}


QString ChatModel::getMomentarySummarytext()
{
    dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, m_MomentaryMsgId);

    char* tempText;
    QString summarytext = "";

    tempText = dc_msg_get_summarytext(tempMsg, 80);

    if (tempText) {
        summarytext = tempText;
        dc_str_unref(tempText);
    }

    dc_msg_unref(tempMsg);

    return summarytext;
}


QString ChatModel::getMomentaryText()
{
    dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, m_MomentaryMsgId);

    char* tempText;
    QString msgtext = "";

    tempText = dc_msg_get_text(tempMsg);

    if (tempText) {
        msgtext = tempText;
        dc_str_unref(tempText);
    }

    dc_msg_unref(tempMsg);

    return msgtext;
}


int ChatModel::getUnreadMessageCount()
{
    return dc_get_fresh_msg_cnt(currentMsgContext, chatID);
}


int ChatModel::getUnreadMessageBarIndex()
{
    return m_unreadMessageBarIndex;
}


bool ChatModel::chatCanSend()
{
    dc_chat_t* tempChat = dc_get_chat(currentMsgContext, chatID);

    if (!tempChat) {
        qDebug() << "ChatModel::chatIsDeviceTalk(): ERROR getting chat, returning false.";
        return false;
    }

    bool retval = (1 == dc_chat_can_send(tempChat));
    dc_chat_unref(tempChat);

    return retval;
}


bool ChatModel::chatIsDeviceTalk()
{
    dc_chat_t* tempChat = dc_get_chat(currentMsgContext, chatID);

    if (!tempChat) {
        qDebug() << "ChatModel::chatIsDeviceTalk(): ERROR getting chat, returning false.";
        return false;
    }

    bool retval = (1 == dc_chat_is_device_talk(tempChat));
    dc_chat_unref(tempChat);
    
    return retval;
}


bool ChatModel::selfIsInGroup()
{
    // assumes that the current chat really is a group

    dc_array_t* tempContactsArray = dc_get_chat_contacts(currentMsgContext, chatID);
    
    bool isInGroup = false;

    for (size_t i = 0; i < dc_array_get_cnt(tempContactsArray); ++i) {
        if (DC_CONTACT_ID_SELF == dc_array_get_id(tempContactsArray, i)) {
            isInGroup = true;
            break;
        }
    }

    dc_array_unref(tempContactsArray);

    return isInGroup;
}


bool ChatModel::setUrlToExport()
{
    dc_msg_t* tempMsg;
    char* tempText;

    tempMsg = dc_get_msg(currentMsgContext, m_MomentaryMsgId);
    tempText = dc_msg_get_file(tempMsg);
    m_tempExportPath = tempText;
    
    // see ProfilePicRole above
    m_tempExportPath.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length() + 1);

    if (tempText) {
        dc_str_unref(tempText);
    }

    if (tempMsg) {
        dc_msg_unref(tempMsg);
    }

    if (m_tempExportPath != "") {
        return true;
    } else {
        return false;
    }
}


QString ChatModel::getUrlToExport()
{
    return m_tempExportPath;
}


int ChatModel::getMomentaryViewType()
{
    dc_msg_t* tempMsg;
    tempMsg = dc_get_msg(currentMsgContext, m_MomentaryMsgId);

    int retval;

    switch (dc_msg_get_viewtype(tempMsg)) {
        case DC_MSG_AUDIO:
            retval = DeltaHandler::MsgViewType::AudioType;
            break;

        case DC_MSG_FILE:
            retval = DeltaHandler::MsgViewType::FileType;
            break;
        
        case DC_MSG_GIF:
            retval = DeltaHandler::MsgViewType::GifType;
            break;
        
        case DC_MSG_IMAGE:
            retval = DeltaHandler::MsgViewType::ImageType;
            break;
        
        case DC_MSG_STICKER:
            retval = DeltaHandler::MsgViewType::StickerType;
            break;
        
        case DC_MSG_TEXT:
            retval = DeltaHandler::MsgViewType::TextType;
            break;

        case DC_MSG_VIDEO:
            retval = DeltaHandler::MsgViewType::VideoType;
            break;
        
        case DC_MSG_VIDEOCHAT_INVITATION:
            retval = DeltaHandler::MsgViewType::VideochatInvitationType;
            break;
        
        case DC_MSG_VOICE:
            retval = DeltaHandler::MsgViewType::VoiceType;
            break;

        case DC_MSG_WEBXDC:
            retval = DeltaHandler::MsgViewType::WebXdcType;
            break;

        default:
            qDebug() << "ChatModel: Unknown message type " << dc_msg_get_viewtype(tempMsg);
            retval = DeltaHandler::MsgViewType::UnknownType;
            break;
    }

    if (tempMsg) {
        dc_msg_unref(tempMsg);
    }

    return retval;
}


QString ChatModel::getMomentaryInfo()
{
    char* tempText = dc_get_msg_info(currentMsgContext, m_MomentaryMsgId);
    QString tempQString = tempText;

    if (tempText) {
        dc_str_unref(tempText);
    }
    
    return tempQString;
}


QVariant ChatModel::callData(int myindex, QString role)
{
    // TODO: maybe this is not used anymore due to the
    // introduction of m_MomentaryMsgId?
    //
    // Up to now, I didn't manage to call data(QModelIndex &index, int
    // role) from QML. I could neither find a way to create a
    // QModelIndex in QML nor to refer to the enum with the roles from
    // QML. This method creates a valie QModelIndex from the index and
    // takes the usual QML reference to the enum as string (e.g. "text"
    // for TextRole as needed in data()).
    //
    // TODO: can any method be removed due to this
    // TODO: apply this to the other models, too
    // 
    // For this, the QHash from roleNames() is iterated over until the
    // string is found.
    QHash<int, QByteArray> roles = roleNames();

    QHashIterator<int, QByteArray> i(roles);
    int roleValue {-1};

    while (i.hasNext()) {
        i.next();
        if (i.value() == role) {
            roleValue = i.key();
            break;
        }
    }

    if (roleValue >= 0) {
        return data(QAbstractItemModel::createIndex(myindex, 0), roleValue);
    } else {
        // the QString passed to role has not been found in the QHash
        return QVariant();
    }
}

QString ChatModel::copyToCache(QString fromFilePath) const
{
    // Method copies the fromFilePath which is expected to be somewhere
    // in StandardPaths::AppConfigLocation to
    // <StandardPaths::CacheLocation>/blobs/
    //
    // This is needed for audio files because the QML Audio Type cannot
    // play files in the AppConfigLocation (presumably due to an
    // AppArmor restriction)

    QString fromFileBasename = fromFilePath;
    QString slash = "/";
    int lastIndexOfSlash = fromFileBasename.lastIndexOf(slash);
    fromFileBasename.remove(0, lastIndexOfSlash + 1);
    
    // checking if the /blobs/ dir in the cache location exists,
    // if not, create it
    QString toFilePath(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    toFilePath.append("/blobs/");

    if (!QFile::exists(toFilePath)) {
        qDebug() << "ChatModel::copyToCache: Cache blobs directory not existing, creating it now";
        QDir tempdir;
        bool success = tempdir.mkpath(toFilePath);
        if (success) {
            qDebug() << "ChatModel::copyToCache: Cache blobs directory successfully created";
        } else {
            qDebug() << "ChatModel::copyToCache: ERROR: Could not create cache blobs directory";
            return QString("");
        }
    }

    // complete toFilePath
    toFilePath.append(fromFileBasename);

    // if it exists, remove it first
    if (QFile::exists(toFilePath)) {
        qDebug() << "ChatModel::copyToCache: trying to remove file " << toFilePath << " from Cache...";
        int success = remove(toFilePath.toUtf8().constData());
        if (0 == success) {
            qDebug() << "ChatModel::copyToCache: ...success.";
        } else {
            qDebug() << "ChatModel::copyToCache: ...ERROR: failed!";
        }
    }

    QFile::copy(fromFilePath, toFilePath);

    // shortening to blobs/<basename>
    lastIndexOfSlash = toFilePath.lastIndexOf(slash);
    lastIndexOfSlash = toFilePath.lastIndexOf(slash, -1 * (toFilePath.length() - (lastIndexOfSlash - 1)));
    toFilePath.remove(0, lastIndexOfSlash + 1);

    return toFilePath;
}


QString ChatModel::getDraft()
{
    dc_msg_t* tempMsg {nullptr};
    char* tempText {nullptr};
    QString tempQString("");
    
    tempMsg = dc_get_draft(currentMsgContext, chatID);

    if (tempMsg) {
        tempText = dc_msg_get_text(tempMsg);
        tempQString = tempText;
        dc_str_unref(tempText);
        dc_msg_unref(tempMsg);
    }

    return tempQString;
}


void ChatModel::setDraft(QString draftText)
{
    if (currentMessageDraft) {
        if ("" == draftText && !draftHasQuote() && !draftHasAttachment()) {
            dc_set_draft(currentMsgContext, chatID, NULL);
            dc_msg_unref(currentMessageDraft);
            currentMessageDraft = nullptr;

        } else {
            dc_msg_set_text(currentMessageDraft, draftText.toUtf8().constData());
            dc_set_draft(currentMsgContext, chatID, currentMessageDraft);
        }

    // no draft exists, and the message enter field is empty,
    // so nothing to do
    } else if ("" == draftText) { 
        return;
    // no draft exists, but the message enter field
    // contains text, so a draft message is now created
    } else {
        currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);
        dc_msg_set_text(currentMessageDraft, draftText.toUtf8().constData());
        dc_set_draft(currentMsgContext, chatID, currentMessageDraft);
    }
}


void ChatModel::setQuote(int myindex)
{
    uint32_t tempMsgID {0};
    tempMsgID = msgVector[myindex];

    if (!currentMessageDraft) {
        currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);
    }

    dc_msg_t* tempMsg;
    tempMsg = dc_get_msg(currentMsgContext, tempMsgID);

    dc_msg_set_quote(currentMessageDraft, tempMsg);
    emit draftHasQuoteChanged();

    dc_msg_unref(tempMsg);
}


void ChatModel::unsetQuote()
{
    if (draftHasQuote()) {
        dc_msg_set_quote(currentMessageDraft, NULL);
        emit draftHasQuoteChanged();
    } else {
        // Although no quoted message could be found, it could be
        // that the draft is actually a reply, but the message that
        // is replied to is not there anymore. The draft would
        // still contain the quoted_text, so we have to delete
        // the draft in this case (it's sufficient to unref
        // currentMessageDraft). No need to create a new
        // message as this will be done when the sent icon
        // is clicked or when the page is left and the draft
        // saved. Also no need to overwrite the draft in the database.
        qDebug() << "ChatModel::unsetQuote: There is no quoted message, unsetting the current draft to delete the quoted text";
        if (currentMessageDraft && !draftHasAttachment()) {
            dc_msg_unref(currentMessageDraft);
            currentMessageDraft = nullptr;
        }
        emit draftHasQuoteChanged();
    }
}


void ChatModel::setAttachment(QString filepath, int attachType)
{
    // the url handed over by the ContentHub starts with
    // "file:///home....", so we have to remove the first 7
    // characters
    filepath.remove(0, 7);

    dc_msg_t* tempQuote {nullptr};

    if (currentMessageDraft) {
        // delete the current message draft as it may have the 
        // wrong message type (TODO: can the type of an existing
        // message be changed? Then we could avoid this)
        //
        // Save the quote if it exists; will be re-added below
        tempQuote = dc_msg_get_quoted_msg(currentMessageDraft);

        // Then delete the old currentMessageDraft
        dc_msg_unref(currentMessageDraft);
        currentMessageDraft = nullptr;

    } 

    // Get a new draft message based on the passed attachment type. This
    // should be one of DeltaHandler::msgViewType; it's int in the method
    // signature because the compiler won't take it otherwise (seems to
    // only work in the class where the enum is declared)
    switch (attachType) {
        case DeltaHandler::MsgViewType::AudioType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_AUDIO);
            break;

        case DeltaHandler::MsgViewType::FileType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_FILE);
            break;
        
        case DeltaHandler::MsgViewType::GifType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_GIF);
            break;
        
        case DeltaHandler::MsgViewType::ImageType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_IMAGE);
            break;
        
        case DeltaHandler::MsgViewType::StickerType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_STICKER);
            break;
        
        case DeltaHandler::MsgViewType::TextType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);
            break;

        case DeltaHandler::MsgViewType::VideoType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_VIDEO);
            break;
        
        case DeltaHandler::MsgViewType::VideochatInvitationType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_VIDEOCHAT_INVITATION);
            break;
        
        case DeltaHandler::MsgViewType::VoiceType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_VOICE);
            break;

        case DeltaHandler::MsgViewType::WebXdcType:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_WEBXDC);
            break;

        default:
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_FILE);
            break;
    } 

    if (tempQuote) {
        dc_msg_set_quote(currentMessageDraft, tempQuote);
        dc_msg_unref(tempQuote);
    } 

    dc_msg_set_file(currentMessageDraft, filepath.toUtf8().constData(), NULL);

    bool addCacheLocation;

    QString originalPath = filepath;

    if (filepath.startsWith(QStandardPaths::writableLocation(QStandardPaths::CacheLocation))) {
        filepath.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length() + 1);
        addCacheLocation = true;
    } else if (filepath.startsWith(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation))) {
        filepath.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length() + 1);
        addCacheLocation = false;
    }

    // create a string with the base filename, in case ChatView wants to show
    // it in the preview area
    QString filename = filepath;

    if (filename.lastIndexOf("/") != -1) {
        filename = filename.remove(0, filename.lastIndexOf("/") + 1);
    }

    // tell ChatView that an attachment has been added
    switch (attachType) {

        case DeltaHandler::MsgViewType::AudioType:
            if (!addCacheLocation) {
                filepath = copyToCache(originalPath);
            }
            emit previewAudioAttachment(filepath, filename);
            break;

        case DeltaHandler::MsgViewType::FileType:
            emit previewFileAttachment(filename);
            break;
        
        case DeltaHandler::MsgViewType::GifType:
        
        case DeltaHandler::MsgViewType::ImageType:
        
        case DeltaHandler::MsgViewType::StickerType:
            emit previewImageAttachment(filepath, addCacheLocation);
            break;
        
     //   case DeltaHandler::MsgViewType::TextType:
     //       break;

     //   case DeltaHandler::MsgViewType::VideoType:
     //       break;
     //   
     //   case DeltaHandler::MsgViewType::VideochatInvitationType:
     //       break;
     //   
     //   case DeltaHandler::MsgViewType::VoiceType:
     //       break;

     //   case DeltaHandler::MsgViewType::WebXdcType:
     //       break;

        default:
            qDebug() << "DeltaHandler::setAttachment() reached default case in switch";
            break;
    }
}


void ChatModel::emitDraftHasAttachmentSignals()
{
    if (draftHasAttachment()) {
        // get the attachment path
        char* tempText = dc_msg_get_file(currentMessageDraft);
        QString filepath = tempText; 
        dc_str_unref(tempText);

        // create a string with the base filename, in case ChatView wants to show
        // it in the preview area
        QString filename = filepath;

        if (filename.lastIndexOf("/") != -1) {
            filename = filename.remove(0, filename.lastIndexOf("/") + 1);
        }
       
        // Prepare filepath for the signal to ChatView by removing the CacheLocation.
        // Filepath could either point to .cache or to .config, we
        // have to check and a) remove the correct string and b) tell
        // the receiver what to add back (CacheLocation if addCacheLocation == true, AppConfigLocation
        // otherwise)
        bool addCacheLocation;
        QString originalPath = filepath;

        if (filepath.startsWith(QStandardPaths::writableLocation(QStandardPaths::CacheLocation))) {
            filepath.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length() + 1);
            addCacheLocation = true;
        } else if (filepath.startsWith(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation))) {
            filepath.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length() + 1);
            addCacheLocation = false;
        }

        int tempMessageType = dc_msg_get_viewtype(currentMessageDraft);
        switch (tempMessageType) {

            case DC_MSG_AUDIO:
                if (!addCacheLocation) {
                    filepath = copyToCache(originalPath);
                }
                emit previewAudioAttachment(filepath, filename);
                break;

            case DC_MSG_FILE:
                emit previewFileAttachment(filename);
                break;
            
            case DC_MSG_GIF:
            case DC_MSG_IMAGE:
            case DC_MSG_STICKER:
                emit previewImageAttachment(filepath, addCacheLocation);
                break;
            
         //   case DeltaHandler::MsgViewType::TextType:
         //       break;

         //   case DeltaHandler::MsgViewType::VideoType:
         //       break;
         //   
         //   case DeltaHandler::MsgViewType::VideochatInvitationType:
         //       break;
         //   
         //   case DeltaHandler::MsgViewType::VoiceType:
         //       break;

         //   case DeltaHandler::MsgViewType::WebXdcType:
         //       break;

            default:
                qDebug() << "DeltaHandler::emitDraftHasAttachmentSignals() reached default case in switch";
                break;
        }
    }
}


void ChatModel::unsetAttachment()
{
    if (currentMessageDraft) {
        // If there's no quote, the draft can be deleted. Any text
        // in the draft will be set again when the ChatView is left.
        if (!draftHasQuote()) {
            dc_msg_unref(currentMessageDraft);
            currentMessageDraft = nullptr;
        } else {
            dc_msg_t* tempQuote = dc_msg_get_quoted_msg(currentMessageDraft);

            // need to check because draftHasQuote == true doesn't mean
            // that there's an actual quoted message (could be only 
            // quoted text)
            if (tempQuote) {
                dc_msg_unref(currentMessageDraft);
                currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);
                dc_msg_set_quote(currentMessageDraft, tempQuote);
                dc_msg_unref(tempQuote);
            }
        }
    }
}


QString ChatModel::getDraftQuoteSummarytext()
{

    QString retval;
    char* tempText {nullptr};

    if (currentMessageDraft) {
        tempText = dc_msg_get_quoted_text(currentMessageDraft);
        if (tempText) {
            retval = tempText;
            dc_str_unref(tempText);
        } else {
            retval = "";
        }
    } else {
        retval = "";
    }

    return retval;
}


QString ChatModel::getDraftQuoteUsername()
{
    QString retval;
    char* tempText {nullptr};

    if (currentMessageDraft) {
        dc_msg_t* quotedMsg = dc_msg_get_quoted_msg(currentMessageDraft);
        if (quotedMsg) {
            tempText = dc_msg_get_override_sender_name(quotedMsg);
            if (tempText) {
                retval = "~";
                retval += tempText;
            } else {
                tempText = dc_contact_get_display_name(dc_get_contact(currentMsgContext, dc_msg_get_from_id(quotedMsg)));
                retval = tempText;
            }
            dc_msg_unref(quotedMsg);
        } else {
            retval = "";
        }
    } else {
        retval = "";
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    return retval;
}


void ChatModel::initiateQuotedMsgJump(int myindex)
{
    if (myindex < 0 || myindex >= currentMsgCount) {
        return;
    }

    dc_msg_t* tempMsg {nullptr};
    uint32_t tempMsgID {0};

    tempMsgID = msgVector[myindex];
    tempMsg = dc_get_msg(currentMsgContext, tempMsgID);

    dc_msg_t* quotedMsg {nullptr};
    quotedMsg = dc_msg_get_quoted_msg(tempMsg);

    if (quotedMsg) {
        uint32_t tempChatID = dc_msg_get_chat_id(quotedMsg);
        if (chatID != tempChatID) {
            qDebug() << "ChatModel::initiateQuotedMsgJump: Message to jump to is in different chat";
        } else {
            uint32_t quotedMsgID = dc_msg_get_id(quotedMsg);
            size_t i {0};
            for (i = 0; i < currentMsgCount; ++i) {
                if (msgVector[i] == quotedMsgID) {
                    emit jumpToMsg(i);
                    break;
                }
            } // end for
            if (i == currentMsgCount) {
                qDebug() << "ChatModel::initiateQuotedMsgJump: Could not find quoted message in the message list";
            }
        } // end else
    } else { // (quotedMsg)
        qDebug() << "ChatModel::initiateQuotedMsgJump: No quoted message attached";
    }

    if (tempMsg) {
        dc_msg_unref(tempMsg);
    }

    if (quotedMsg) {
        dc_msg_unref(quotedMsg);
    }
}


bool ChatModel::prepareForwarding(int myindex)
{
    qDebug() << "ChatModel::prepareForwarding: preparing to forward the message with index: " << myindex;

    if (myindex < 0 || myindex >= currentMsgCount) {
        return false;
    }

    // don't try to get the msg from DC if it's
    // the Unread Message bar
    if (myindex != m_unreadMessageBarIndex) {
        messageIdToForward = msgVector[myindex];
    } else {
        return false;
    }

    if (m_chatlistmodel) {
        delete m_chatlistmodel;
        m_chatlistmodel = nullptr;
    }

    m_chatlistmodel = new ChatlistModel();
    m_chatlistmodel->configure(currentMsgContext, DC_GCL_FOR_FORWARDING | DC_GCL_NO_SPECIALS);

    return true;
}


void ChatModel::forwardingFinished()
{
    if (m_chatlistmodel) {
        delete m_chatlistmodel;
        m_chatlistmodel = nullptr;
    }
}


void ChatModel::forwardMessage(uint32_t chatIdToForwardTo)
{
    qDebug() << "ChatModel::forwardMessage(): Forwarding message ID " << messageIdToForward << " to chat ID " << chatIdToForwardTo;
    dc_forward_msgs(currentMsgContext, &messageIdToForward, 1, chatIdToForwardTo);
}


void ChatModel::downloadFullMessage(int myindex)
{
    uint32_t tempMsgID = msgVector[myindex];
    dc_download_full_msg(currentMsgContext, tempMsgID);
}


ChatlistModel* ChatModel::chatlistmodel()
{
    return m_chatlistmodel;
}


void ChatModel::sendMessage(QString messageText)
{
    bool needToNotifyAboutQuote = false;

    if (!currentMessageDraft) {
        currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);

    } else {
         if (draftHasQuote()) {
             needToNotifyAboutQuote = true;
         }
    }

    dc_msg_set_text(currentMessageDraft, messageText.toUtf8().constData());

    dc_send_msg(currentMsgContext, chatID, currentMessageDraft);

    dc_msg_unref(currentMessageDraft);
    currentMessageDraft = nullptr;

    // TODO: really needed to inform that the quote has changed? Maybe
    // it could be handled like attachments, as for their preview
    // is closed upon pressing the send button by ChatView itself
    if (needToNotifyAboutQuote) {
        emit draftHasQuoteChanged();
    }
}


bool ChatModel::hasDraft() {
    if (currentMessageDraft) {
        return true;
    } else {
        return false;
    }
}


bool ChatModel::draftHasQuote()
{
    bool retval;

    if (currentMessageDraft) {
        char* tempText = dc_msg_get_quoted_text(currentMessageDraft);
        if (tempText) {
            retval = true;
            dc_str_unref(tempText);
        } else {
            retval = false;
        }
    } else {
        retval = false;
    }

    return retval;
}


bool ChatModel::draftHasAttachment()
{
    bool retval;

    if (currentMessageDraft) {
        char* tempText = dc_msg_get_file(currentMessageDraft);
        // "null is never returned"
        QString tempQString = tempText;
        dc_str_unref(tempText);
        if (tempQString != "") {
            retval = true;
        } else {
            retval = false;
        }
    } else {
        retval = false;
    }

    return retval;
}


void ChatModel::appIsActiveAgainActions() {
    // Purpose of this method: Messages that have been received for the
    // currently active chat while the app was in background are marked
    // seen and their push notifications are removed. IDs of such
    // messages are stored in msgsToMarkSeenLater.
    if (m_chatIsBeingViewed) {
        for (size_t i = 0; i < msgsToMarkSeenLater.size(); ++i) {
            dc_markseen_msgs(currentMsgContext, msgsToMarkSeenLater.data() + i, 1);
        }
        msgsToMarkSeenLater.clear();
        emit markedAllMessagesSeen();
    }
}


void ChatModel::chatViewIsOpened()
{
    m_chatIsBeingViewed = true;
}


void ChatModel::chatViewIsClosed()
{
    m_chatIsBeingViewed = false;
    disconnect(m_dhandler, SIGNAL(msgsChanged(int)), this, SLOT(newMessage(int)));
}


void ChatModel::updateQuery(QString query)
{
    if (query == m_query) {
        return;
    }

    // is used multiple times below for dataChanged()
    QVector<int> roleVector;
    roleVector.append(ChatModel::IsSearchResultRole);

    if (oldSearchMsgArray) {
        dc_array_unref(oldSearchMsgArray);
    }
    oldSearchMsgArray = currentSearchMsgArray;

    m_query = query;

    if (query == "") {
        // have to set currentSearchMsgArray to nullptr
        // before emitting dataChanged() (but NOT
        // unref it as it points to the same address
        // as oldSearchMsgArray!)
        currentSearchMsgArray = nullptr;

        if (oldSearchMsgArray) {
            // Situation: Search string has been cleared,
            // but previously, there were search results.
            // We have to invalidate them.
            for (size_t i = 0; i < dc_array_get_cnt(oldSearchMsgArray); ++i) {
                uint32_t tempOldID = dc_array_get_id(oldSearchMsgArray, i);
                for (size_t j = 0; j < currentMsgCount; ++j) {
                    if (tempOldID == msgVector[j]) {
                        emit dataChanged(index(j, 0), index(j, 0), roleVector);
                        break;
                    }
                }
            }
            dc_array_unref(oldSearchMsgArray);
            oldSearchMsgArray = nullptr;
        }
        return;
    } 
    
    // query contains a string, otherwise the method would
    // have returned above

    // must not unref currentSearchMsgArray here as it has been
    // copied to oldSearchMsgArray
    currentSearchMsgArray = dc_search_msgs(currentMsgContext, chatID, m_query.toUtf8().constData());
    m_searchCountTotal = dc_array_get_cnt(currentSearchMsgArray);
    if (m_searchCountTotal > 0) {
        m_searchCountCurrent = m_searchCountTotal - 1;
        emit searchCountUpdate(m_searchCountCurrent + 1, m_searchCountTotal);
        int tempIndex = getIndexOfMsgID(dc_array_get_id(currentSearchMsgArray, m_searchCountCurrent));
        emit jumpToMsg(tempIndex);
    } else {
        emit searchCountUpdate(0, 0);
    }

    if (!currentSearchMsgArray) {
        // currentSearchMsgArray == NULL => no results found
        if (oldSearchMsgArray) {
            // Situation: new search string did not give any results,
            // but the one before had results.
            //
            // This means that at the moment, the msgIDs in
            // oldSearchMsgArray are shown as search results in the
            // ChatView => get the index of each msgID and emit
            // dataChanged() so the messages are not shown as matching the
            // search anymore
            for (size_t i = 0; i < dc_array_get_cnt(oldSearchMsgArray); ++i) {
                uint32_t tempOldID = dc_array_get_id(oldSearchMsgArray, i);
                for (size_t j = 0; j < currentMsgCount; ++j) {
                    if (tempOldID == msgVector[j]) {
                        emit dataChanged(index(j, 0), index(j, 0), roleVector);
                        break;
                    }
                }
            } // end getting the index of each msgID and emitting dataChanged()

            // TODO: handle search counter, tell the ChatView that no
            // messages match the search string

            // all done, return
            return; 
        } else {
            // Situation: neither old nor new search gave any results,
            // nothing to do, the method can return
            return;
        }
    } else {
        // results were found, currentSearchMsgArray is not empty
        if (oldSearchMsgArray) {
            // Situation: There are  current search results and previous
            // search results. We have to unset all previous results
            // that are not in the list of the current ones, and vice
            // versa. Note that it is not guaranteed that the current
            // search results are a subset of the previous ones - the
            // user might have entered something in the middle of the
            // previous string, or something from the previous string
            // might have been deleted.
            //
            // All msgIDs that are part of the previous search, but not
            // of this one have to be unset, and the new ones that are
            // not in the previous set have to be marked.

            // First, check for message IDs that are only in the old
            // array:
            for (size_t i = 0; i < dc_array_get_cnt(oldSearchMsgArray); ++i) {
                uint32_t tempOldID = dc_array_get_id(oldSearchMsgArray, i);
                size_t j;
                for (j = 0; j < dc_array_get_cnt(currentSearchMsgArray); ++j) {
                    uint32_t tempNewID = dc_array_get_id(currentSearchMsgArray, j);
                    if (tempOldID == tempNewID) {
                        break;
                    }
                }
                if (j == dc_array_get_cnt(currentSearchMsgArray)) {
                    // if we're here it means that index i of
                    // oldSearchMsgArray is not in
                    // currentSearchMsgArray, so we have to
                    // emit dataChanged(). For this, the index
                    // of the tempOldID has to be obtained:
                    for (size_t k = 0; k < currentMsgCount; ++k) {
                        if (tempOldID == msgVector[k]) {
                            emit dataChanged(index(k, 0), index(k, 0), roleVector);
                            break;
                        }
                    }
                }
            }
            // now check for messages that are only in the new array
            for (size_t i = 0; i < dc_array_get_cnt(currentSearchMsgArray); ++i) {
                uint32_t tempNewID = dc_array_get_id(currentSearchMsgArray, i);
                size_t j;
                for (j = 0; j < dc_array_get_cnt(oldSearchMsgArray); ++j) {
                    uint32_t tempOldID = dc_array_get_id(oldSearchMsgArray, j);
                    if (tempOldID == tempNewID) {
                        break;
                    }
                }
                if (j == dc_array_get_cnt(oldSearchMsgArray)) {
                    // if we're here it means that index i of
                    // currentSearchMsgArray is not in
                    // oldSearchMsgArray, so we have to
                    // emit dataChanged(). For this, the index
                    // of the tempNewID has to be obtained:
                    for (size_t k = 0; k < currentMsgCount; ++k) {
                        if (tempNewID == msgVector[k]) {
                            emit dataChanged(index(k, 0), index(k, 0), roleVector);
                            break;
                        }
                    }
                }
            }
        } else {
            // Situation: we have new search results, but no old ones,
            // so we just have to mark all IDs in the
            // currentSearchMsgArray
            for (size_t i = 0; i < dc_array_get_cnt(currentSearchMsgArray); ++i) {
                uint32_t tempNewID = dc_array_get_id(currentSearchMsgArray, i);
                for (size_t j = 0; j < currentMsgCount; ++j) {
                    if (tempNewID == msgVector[j]) {
                        emit dataChanged(index(j, 0), index(j, 0), roleVector);
                        break;
                    }
                }
            }
        }
    }
}


void ChatModel::searchJumpSlot(int posType)
{
    if (m_searchCountTotal == 0) {
        return;
    }

    switch (posType) {
        case DeltaHandler::SearchJumpToPosition::PositionFirst:
            m_searchCountCurrent = 0;
            emit jumpToMsg(getIndexOfMsgID(dc_array_get_id(currentSearchMsgArray, 0)));
            emit searchCountUpdate(m_searchCountCurrent + 1, m_searchCountTotal);
            break;

        case DeltaHandler::SearchJumpToPosition::PositionPrev:
            if (m_searchCountCurrent > 0) {
                --m_searchCountCurrent;
            }
            emit jumpToMsg(getIndexOfMsgID(dc_array_get_id(currentSearchMsgArray, m_searchCountCurrent)));
            emit searchCountUpdate(m_searchCountCurrent + 1, m_searchCountTotal);
            break;

        case DeltaHandler::SearchJumpToPosition::PositionNext:
            if (m_searchCountCurrent + 1 < m_searchCountTotal) {
                ++m_searchCountCurrent;
            }
            emit jumpToMsg(getIndexOfMsgID(dc_array_get_id(currentSearchMsgArray, m_searchCountCurrent)));
            emit searchCountUpdate(m_searchCountCurrent + 1, m_searchCountTotal);
            break;

        case DeltaHandler::SearchJumpToPosition::PositionLast:
            m_searchCountCurrent = m_searchCountTotal - 1;
            emit searchCountUpdate(m_searchCountCurrent + 1, m_searchCountTotal);
            emit jumpToMsg(getIndexOfMsgID(dc_array_get_id(currentSearchMsgArray, m_searchCountCurrent)));
            break;

        default:
            break;
    }
}


int ChatModel::getIndexOfMsgID(uint32_t msgID)
{
    for (size_t i = 0; i < currentMsgCount; ++i) {
        if (msgID == msgVector[i]) {
            return i;
        }
    }
    // if we're here, the msgID was not found in msgVector
    return -1;
}
