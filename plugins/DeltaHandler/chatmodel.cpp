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
    : QAbstractListModel(parent), currentMsgContext {nullptr}, chatID {0}, currentMsgCount {0}, currentMessageDraft {nullptr}, m_chatlistmodel {nullptr}, messageIdToForward {0}, data_row {std::numeric_limits<int>::max()}, data_tempMsg {nullptr}
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
    
    QVariant retval;

//    Not used for the time being because due to the ListView
//    preloading messages that are not in view yet, this also
//    marks messages that have not been presented to the user
//    yet. Currently, upon opening a chat view, all messages
//    in the chat are marked as seen directly until a better
//    solution is found.
//    Note that if this solution is brought back, it may also
//    need changes in acceptChat().
//    // Marking message as seen
//    // TODO: use different approach to mark messages as
//    // seen? Maybe mark all as seen when opening a chat?
//    // Also, place the view at the first unread message?
//    if (!m_isContactRequest && dc_msg_get_state(tempMsg) != DC_STATE_IN_SEEN && !(dc_msg_get_from_id(tempMsg) == DC_CONTACT_ID_SELF) && row != m_unreadMessageBarIndex) {
//        dc_markseen_msgs(currentMsgContext, &tempMsgID, 1);
//        emit messageMarkedSeen();
//    }

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


void ChatModel::messageStatusChangedSlot(int msgID)
{
    for (size_t i = 0; i < currentMsgCount; ++i) {
        if (msgID == msgVector[i]) {
            emit QAbstractListModel::dataChanged(index(i, 0), index(i, 0));
            break;
        }
    }
}


void ChatModel::configure(uint32_t cID, dc_context_t* context, DeltaHandler* deltaHandler, bool cIsContactRequest)
{
    beginResetModel();

    // invalidate the cached data_tempMsg
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
        
        if (!m_hasUnreadMessages) {
            dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, msgVector[currentMsgCount - (i + 1)]);
            if (dc_msg_get_state(tempMsg) != DC_STATE_IN_SEEN && !(dc_msg_get_from_id(tempMsg) == DC_CONTACT_ID_SELF)) {
                m_hasUnreadMessages = true;
                m_unreadMessageBarIndex = currentMsgCount - (i + 1);

                // needed to re-create the Unread Message bar in newMessage()
                m_firstUnreadMessageID = msgVector[currentMsgCount - (i + 1)];
                m_hasUnreadMessages = true;
            }
            dc_msg_unref(tempMsg);
        }
    }

    // Marking all unread messages as seen. For simplicity reasons,
    // all message IDs from the first unread one to the most recent one
    // are marked as seen.
    if (m_hasUnreadMessages) {
        for (int i = 0; i <= m_unreadMessageBarIndex; ++i) {
            dc_markseen_msgs(currentMsgContext, msgVector.data() + i, 1);
        }
        emit markedAllMessagesSeen();
    }


    // insert an info message "Unread messages" above the first unread message
    if (m_hasUnreadMessages) {
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

    bool connectSuccess = connect(deltaHandler, SIGNAL(newMsgReceived(int)), this, SLOT(newMessage(int)));
    if (!connectSuccess) {
        qDebug() << "Chatmodel::configure: Could not connect signal newMsgReceived to slot newMessage";
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


// TODO: remove msgID as parameter (was used in a previous implementation
// of this method)
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
                msgVector[i] = msgVector[j];

                // need to unset m_unreadMessageBarIndex in case
                // it is overwritten
                if (i == m_unreadMessageBarIndex) {
                    m_unreadMessageBarIndex = -1;
                }

                emit QAbstractItemModel::dataChanged(index(i, 0), index(i, 0));
                if (i <  currentMsgCount - 1) {
                    emit QAbstractItemModel::dataChanged(index(i+1, 0), index(i+1, 0));
                }
                break;
            }
        }
        if (j == currentMsgCount) {
            std::vector<uint32_t>::iterator it;
            it = msgVector.begin();

            beginInsertRows(QModelIndex(), i, i);
            msgVector.insert(it+i, tempNewMsgID);

            // TODO: check whether it's a self message?
            dc_markseen_msgs(currentMsgContext, &tempNewMsgID, 1);
            emit messageMarkedSeen();

            ++currentMsgCount;
            endInsertRows();
            if (i <  currentMsgCount - 1) {
                emit QAbstractItemModel::dataChanged(index(i+1, 0), index(i+1, 0));
            }
        }
    }

    if (currentMsgCount > newMsgCount) {
        beginRemoveRows(QModelIndex(), newMsgCount - 1, currentMsgCount - 1);
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
                    emit QAbstractItemModel::dataChanged(index(i+2, 0), index(i+2, 0));
                }
                m_unreadMessageBarIndex = i+1;
                ++currentMsgCount;

                endInsertRows();

                break;
            }
        }
    }

    dc_array_unref(newMsgArray);
}

void ChatModel::deleteMessage(int myindex)
{
    // Couldn't figure out how to handle the 
    // Unread Message bar re-positioning in
    // newMessage(). The latter will be called
    // via a signal because deleting messages will
    // trigger a msgs_changed event. As a temporary
    // solution, we just delete the Unread Message
    // bar when deleting messages.
    m_unreadMessageBarIndex = -1;

    uint32_t tempMsgID = msgVector[myindex];
    dc_delete_msgs(currentMsgContext, &tempMsgID, 1);
}


QString ChatModel::getMessageSummarytext(int myindex)
{
    uint32_t tempMsgID = msgVector[myindex];
    dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, tempMsgID);

    char* tempText {nullptr};
    QString summarytext = "";

    tempText = dc_msg_get_summarytext(tempMsg, 80);

    if (tempText) {
        summarytext = tempText;
        dc_str_unref(tempText);
    }

    if (tempMsg) {
        dc_msg_unref(tempMsg);
    }

    return summarytext;
}


int ChatModel::getUnreadMessageCount()
{
    return dc_get_fresh_msg_cnt(currentMsgContext, chatID);
}


int ChatModel::getUnreadMessageBarIndex()
{
    return m_unreadMessageBarIndex;
}


void ChatModel::setUrlToExport(int myindex)
{
    dc_msg_t* tempMsg {nullptr};
    uint32_t tempMsgID {0};
    char* tempText {nullptr};

    if (myindex != m_unreadMessageBarIndex) {
        tempMsgID = msgVector[myindex];
        tempMsg = dc_get_msg(currentMsgContext, tempMsgID);
    } else {
        return;
    }

    tempText = dc_msg_get_file(tempMsg);

    m_tempExportPath = tempText;
    
    // see ProfilePicRole above
    m_tempExportPath.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length() + 1);

    if (tempText) {
        dc_str_unref(tempText);
        tempText = nullptr;
    }

    if (tempMsg) {
        dc_msg_unref(tempMsg);
        tempMsg = nullptr;
    }
}


QString ChatModel::getUrlToExport()
{
    return m_tempExportPath;
}


QVariant ChatModel::callData(int myindex, QString role)
{
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
        if ("" == draftText && !draftHasQuote()) {
            dc_set_draft(currentMsgContext, chatID, NULL);
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
    if (!currentMessageDraft) {
        currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);
    }

    dc_msg_t* tempMsg {nullptr};
    uint32_t tempMsgID {0};

    tempMsgID = msgVector[myindex];
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
        if (currentMessageDraft) {
            dc_msg_unref(currentMessageDraft);
            currentMessageDraft = nullptr;
        }
        emit draftHasQuoteChanged();
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


void ChatModel::prepareForwarding(int myindex)
{
    qDebug() << "ChatModel::prepareForwarding: preparing to forward the message with index: " << myindex;

    if (m_chatlistmodel) {
        delete m_chatlistmodel;
        m_chatlistmodel = nullptr;
    }

    m_chatlistmodel = new ChatlistModel();
    m_chatlistmodel->configure(currentMsgContext, DC_GCL_FOR_FORWARDING | DC_GCL_NO_SPECIALS);

    if (myindex < 0 || myindex >= currentMsgCount) {
        return;
    }

    // don't try to get the msg from DC if it's
    // the Unread Message bar
    if (myindex != m_unreadMessageBarIndex) {
        messageIdToForward = msgVector[myindex];
    }
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
    if (currentMessageDraft) {
        dc_msg_set_text(currentMessageDraft, messageText.toUtf8().constData());
        // TODO: check return value?
        dc_send_msg(currentMsgContext, chatID, currentMessageDraft);

        bool needToNotifyAboutQuote = false;
        if (draftHasQuote()) {
            needToNotifyAboutQuote = true;
        }

        dc_msg_unref(currentMessageDraft);
        currentMessageDraft = nullptr;

        if (needToNotifyAboutQuote) {
            emit draftHasQuoteChanged();
        }
    } else {
        // TODO: check return value?
        dc_send_text_msg(currentMsgContext, chatID, messageText.toUtf8().constData());
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
