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

#include "chatmodel.h"

#include <stdio.h> // for remove()
//#include <unistd.h> // for sleep
#include <limits> // for invalidating data_row
#include <fstream>

#include <QMediaPlayer>

ChatModel::ChatModel(DeltaHandler* dhandler, QObject* parent)
    : QAbstractListModel(parent), m_dhandler {dhandler}, currentMsgContext {nullptr}, m_chatID {0}, m_chatIsBeingViewed {false}, m_settingDraftTextAllowed {true}, currentMsgCount {0}, currentMessageDraft {nullptr}, m_chatlistmodel {nullptr}, data_row {std::numeric_limits<int>::max()}, data_tempMsg {nullptr}, m_query {""}, oldSearchMsgArray {nullptr}, currentSearchMsgArray {nullptr}, m_webxdcImgProvider {nullptr}
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
    
    if (currentMessageDraft) {
        dc_msg_unref(currentMessageDraft);
    }

    if (m_chatlistmodel) {
        delete m_chatlistmodel;
    }
}


void ChatModel::setQQuickView(QQuickView* view)
{
    m_view = view;
    m_webxdcImgProvider = static_cast<WebxdcImageProvider*>(m_view->engine()->imageProvider("webxdcImageProvider"));
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
    roles[IsProtectionInfoRole] = "isProtectionInfo";
    roles[ProtectionInfoTypeRole] = "protectionInfoType";
    roles[IsDownloadedRole] = "isDownloaded";
    roles[DownloadStateRole] = "downloadState";
    roles[IsForwardedRole] = "isForwarded";
    roles[MessageSeenRole] = "messageSeen";
    roles[MessageStateRole] = "messageState";
    roles[QuotedTextRole] = "quotedText";
    roles[QuoteUserRole] = "quoteUser";
    roles[QuoteAvatarColorRole] = "quoteAvatarColor";
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
    roles[FilenameRole] = "filename";
    roles[AudioFilePathRole] = "audiofilepath";
    roles[ImageWidthRole] = "imagewidth";
    roles[ImageHeightRole] = "imageheight";
    roles[AvatarColorRole] = "avatarColor";
    roles[AvatarInitialRole] = "avatarInitial";
    roles[IsSearchResultRole] = "isSearchResult";
    roles[ContactIdRole] = "contactID";
    roles[HasHtmlRole] = "hasHtml";
    roles[ReactionsRole] = "reactions";
    roles[VcardRole] = "vcard";
    roles[WebxdcInfoRole] = "webxdcInfo";
    roles[WebxdcImageRole] = "webxdcImage";

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

    QString paramString;
    QString requestString;
    QByteArray byteArray;
    QJsonDocument jsonDoc;
    QJsonObject jsonObj;
    QJsonArray jsonArray;

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

    // for correction of wrong image file name extensions,
    // see usage below
    QImageReader imagereader;
    // needed to copy files
    QString tempQString2;
    
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

        case ChatModel::IsProtectionInfoRole:
            if (!dc_msg_is_info(tempMsg)) {
                retval = false;
            } else if (DC_INFO_PROTECTION_ENABLED == dc_msg_get_info_type(tempMsg) || DC_INFO_PROTECTION_DISABLED == dc_msg_get_info_type(tempMsg)) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        case ChatModel::ProtectionInfoTypeRole:
            if (DC_INFO_PROTECTION_ENABLED == dc_msg_get_info_type(tempMsg)) {
                retval = DeltaHandler::DcInfoType::InfoProtectionEnabled;
            } else if (DC_INFO_PROTECTION_DISABLED == dc_msg_get_info_type(tempMsg)) {
                retval = DeltaHandler::DcInfoType::InfoProtectionDisabled;
            } else {
                retval = 0;
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
                    
                default:
                    // TODO: there are more states, and also states of
                    // incoming messages
                    retval = DeltaHandler::MsgState::StateUnknown;
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

            // If the message ID is in msgIdsWithExpandedQuote, then
            // the full quoted text should be returned, otherwise
            // a truncated version of it. See initiateQuotedMsgJump()
            // for details
            // Threshold for truncation is randomly 180 chars.
            if (tempQString.length() > 180) {
                if (toggleQuoteVectorContainsId(tempMsgID)) {
                    retval = tempQString;
                } else {
                    tempQString.resize(176);
                    retval = tempQString + " […]";
                }
            } else {
                retval = tempQString;
            }

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

        case ChatModel::QuoteAvatarColorRole:
            nextMsg = dc_msg_get_quoted_msg(tempMsg);

            if (nextMsg) {
                contactID = dc_msg_get_from_id(nextMsg);
                tempContact = dc_get_contact(currentMsgContext, contactID);
                tempColor = dc_contact_get_color(tempContact);
                tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
                retval = QString(tempQColor.name());
            } else {
                retval = "";
            }
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
                    tempText = dc_msg_get_file(tempMsg);
                    tempQString = tempText;
                    // TODO: check if extension matches the actual mime type,
                    // see FilePathRole
                    if (isGif(tempQString)) {
                        retval = QVariant(DeltaHandler::MsgViewType::GifType);
                    } else {
                        retval = QVariant(DeltaHandler::MsgViewType::ImageType);
                    }
                    break;
                
                case DC_MSG_STICKER:
                    retval = QVariant(DeltaHandler::MsgViewType::StickerType);
                    break;
                
                case DC_MSG_TEXT:
                    retval = QVariant(DeltaHandler::MsgViewType::TextType);
                    break;
                
                case DC_MSG_VCARD:
                    retval = QVariant(DeltaHandler::MsgViewType::VcardType);
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
                    retval = QVariant(DeltaHandler::MsgViewType::WebxdcType);
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
                tempQString = msgDate.toString("hh:mm");
                // TODO: if <user prefers am/pm> ...("hh:mm ap")
            }
            else {
                tempQString = msgDate.toString("dd MMM yy hh:mm" );
                // TODO: "...hh:mm ap" as above
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

            // special case: Images
            tempInt = dc_msg_get_viewtype(tempMsg);
            if (DC_MSG_IMAGE == tempInt || DC_MSG_STICKER == tempInt || DC_MSG_GIF == tempInt) {
                // In case of images, if the file extension does not
                // match the actual format of the image, QML Image
                // will not display anything (e.g., the file is named
                // example_image.jpg, but it's actually a PNG). Such
                // a mismatch can be checked with QImageReader::format(),
                // which will be different depending on the setting of
                // setDecideFormatFromContent() in case of a mismatch.
                imagereader.setDecideFormatFromContent(false);
                imagereader.setFileName(tempQString);
                // save the output of format() which is NOT based 
                // on an analysis of the content
                tempQString2 = imagereader.format();

                // Now set the imagereader to determine the format based
                // on the content instead of the file name extension
                imagereader.setDecideFormatFromContent(true);
                // Then load the file again, seems to be needed
                imagereader.setFileName(tempQString);

                // If the content does not match the extension,
                // the previous output of format() should be
                // different than the output now.
                if (tempQString2 != imagereader.format()) {
                    // tempQString2 is now used for something else: the
                    // name of the destination file for copying to a new 
                    // file with the matching extension
                    tempQString2 = tempQString;
                    // Remove the extension
                    tempQString2.remove(tempQString2.lastIndexOf("."), tempQString2.length() - tempQString2.lastIndexOf("."));
                    // now add the correct extension
                    tempQString2.append(".");
                    tempQString2.append(imagereader.format());

                    // copy (renaming will probably not save anything because then the core
                    // will write out the file each time)
                    QFile::copy(tempQString, tempQString2);
                    // set tempQString to the newly copied file
                    tempQString = tempQString2;
                }
            }

            // see ProfilePicRole above
            tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length() + 1);
            retval = tempQString;
            break;

        case ChatModel::FilenameRole:
            tempText = dc_msg_get_file(tempMsg);
            tempQString = tempText;

            if (tempQString.lastIndexOf("/") != -1) {
                tempQString = tempQString.remove(0, tempQString.lastIndexOf("/") + 1);
            }
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

        case ChatModel::ImageHeightRole:
            retval = dc_msg_get_height(tempMsg);
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
                QString tempOriginal = tempQString;
                tempQString.replace(weblinkRegExp, QString("<a href=\"\\1\">\\1</a>"));
               
                // only replace \n by <br> if there's actually a link the text
                if (tempOriginal != tempQString) {
                    tempQString.replace(QString("\n"), QString("<br>"));
                }
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

        case ChatModel::HasHtmlRole:
            retval = (1 == dc_msg_has_html(tempMsg));
            break;

        case ChatModel::ReactionsRole:
            tempQString.setNum(dc_get_id(currentMsgContext));
            paramString.append(tempQString);
            paramString.append(", ");

            tempQString.setNum(tempMsgID);
            paramString.append(tempQString);

            requestString = m_dhandler->constructJsonrpcRequestString("get_message_reactions", paramString);

            // the actual object with the chatlist entry is nested in the
            // received json like this:
            // { .....,"result":{ <this is the actual entry> }}
            // so we extract it
            byteArray = m_dhandler->sendJsonrpcBlockingCall(requestString).toLocal8Bit();
            jsonDoc = QJsonDocument::fromJson(byteArray);

            jsonObj = jsonDoc.object();
            // value() returns a QJsonValue, which we directly
            // transform back to an object via toObject()
            jsonObj = jsonObj.value("result").toObject();

            retval = jsonObj;
            break;

        case ChatModel::VcardRole:
            tempText = dc_msg_get_file(tempMsg);
            tempQString = "\"";
            tempQString.append(tempText);
            tempQString.append("\"");
            // If there's no file, tempText will be an empty string (not NULL!).
            if (tempQString == "\"\"") {
                qDebug() << "ChatModel::data(): in VcardRole: Error: dc_msg_get_file() returned empty string";
                // create our own error message json in the style of dc-jsonrpc
                jsonObj = QJsonDocument::fromJson("{\"error\":{\"message\":\"no file attached to message\"}}").object();
            } else {
                // get the Vcard in parsed form to retrieve name, addr + color of contact
                tempQString = m_dhandler->constructJsonrpcRequestString("parse_vcard", tempQString);
                byteArray = m_dhandler->sendJsonrpcBlockingCall(tempQString).toLocal8Bit();
                jsonDoc = QJsonDocument::fromJson(byteArray);

                jsonObj = jsonDoc.object();
                if (jsonObj.contains("error")) {
                    jsonObj = jsonObj.value("error").toObject();
                    qDebug() << "ChatModel::data(): Error parsing vcard: " << jsonObj.value("message").toString();
                } else {
                    // "result" is an array in this case, e.g.
                    //{"id":1000000131,"jsonrpc":"2.0","result":[{"addr":"...",...}]}
                    if (jsonObj.value("result").isArray()) {
                        jsonArray = jsonObj.value("result").toArray();
                        if (jsonArray.count() > 0) {
                            if (jsonArray.at(0).isObject()) {
                                jsonObj = jsonArray.at(0).toObject();

                                if (jsonObj.contains("profileImage") && !jsonObj.value("profileImage").isNull()) {
                                    tempQString = jsonObj.value("profileImage").toString();
                                    // the image in the vcard is base64 encoded, decode it
                                    byteArray = QByteArray::fromBase64(tempQString.toLocal8Bit());
                                } else {
                                    byteArray.clear();
                                }

                                tempQString = "image://webxdcImageProvider/";
                                tempQString.append(m_webxdcImgProvider->getImageId(dc_get_id(currentMsgContext), m_chatID, dc_msg_get_id(tempMsg), byteArray));

                                // for passing the json object to the view/delegate in QML, the
                                // actual image data is replaced by the path to the imageprovider
                                jsonObj.insert("profileImage", tempQString);
                            } else {
                                qDebug() << "ChatModel::data(): in VcardRole: Error: first element in array of result of jsonrpc call is not an object";
                                jsonObj = QJsonDocument::fromJson("{\"error\":{\"message\":\"first element in array of result of jsonrpc call is not an object\"}}").object();
                            }
                        } else {
                            qDebug() << "ChatModel::data(): in VcardRole: Error: result of jsonrpc call is an empty array";
                            jsonObj = QJsonDocument::fromJson("{\"error\":{\"message\":\"result of jsonrpc call is an empty array\"}}").object();
                        }
                    } else {
                        qDebug() << "ChatModel::data(): in VcardRole: Error: result of jsonrpc call is not an array";
                        jsonObj = QJsonDocument::fromJson("{\"error\":{\"message\":\"result of jsonrpc call is not an array\"}}").object();
                    }
                }
            }

            retval = jsonObj;
            break;

        case ChatModel::WebxdcInfoRole:
            tempText = dc_msg_get_webxdc_info(tempMsg);
            tempQString = tempText;
            retval = tempQString;
            break;

        case ChatModel::WebxdcImageRole:
            tempQString = "image://webxdcImageProvider/";
            tempQString.append(m_webxdcImgProvider->getImageId(dc_get_id(currentMsgContext), m_chatID, tempMsgID, tempMsg));
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


// Returns the number of messages in the current chat,
// the unread message bar (if present) is NOT inlcuded
// in this number
int ChatModel::getMessageCount()
{
    if (m_chatIsBeingViewed) {
        if (m_unreadMessageBarIndex != -1) {
            // the unread message bar is in the 
            // message vector, return the number of
            // messages without it
            return currentMsgCount - 1;
        } else {
            // the unread message bar is not in the 
            // message vector, can use currentMsgCount
            // directly
            return currentMsgCount;
        }
    } else {
        return 0;
    }
}


bool ChatModel::isGif(QString fileToCheck) const
{
    // fileToCheck might be prepended by "file://" or "qrc:", remove it
    QString tempQString = fileToCheck;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        fileToCheck.remove(0, 7);
    }

    tempQString = fileToCheck;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        fileToCheck.remove(0, 4);
    }

    QMimeDatabase mimedb;
    QMimeType mime = mimedb.mimeTypeForFile(fileToCheck);
    if (mime.inherits("image/gif") || mime.inherits("image/webp") || mime.inherits("image/avif") || mime.inherits("image/apng")) {
        return true;
    } else {
        return false;
    }
}


void ChatModel::allowSettingDraftAgain(uint32_t chatID)
{
    if (chatID == m_chatID) {
        m_settingDraftTextAllowed = true;
    } else {
        qFatal("ChatModel::allowSettingDraftAgain(): ERROR: Chat ID passed as parameter does not match m_chatID, danger of sending messages to wrong chat, aborting.");
    }
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


QString ChatModel::getHtmlMessage(int myindex)
{
    QString tempQString = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/htmlmsg.html";
    if (QFile::exists(tempQString)) {
        QFile::remove(tempQString);
    }
    std::ofstream outfile(tempQString.toStdString());

    uint32_t tempMsgID {0};
    tempMsgID = msgVector[myindex];

    char* tempText = dc_get_msg_html(currentMsgContext, tempMsgID);
    if (tempText) {
        outfile << tempText;
    } else {
        qDebug() << "ChatModel::getHtmlMessage: Error: dc_get_msg_html returned NULL";
    }
    outfile.close();


    if (tempText) {
        dc_str_unref(tempText);
    }

    tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length() + 1);
    return tempQString;
}


QString ChatModel::getHtmlMsgSubject(int myindex)
{
    uint32_t tempMsgID = msgVector[myindex];

    dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, tempMsgID);

    char* tempText = dc_msg_get_subject(tempMsg);
    QString tempQString = tempText;

    if (tempMsg) {
        dc_msg_unref(tempMsg);
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    return tempQString;
}


void ChatModel::configure(uint32_t cID, uint32_t aID, dc_accounts_t* allAccs, std::vector<uint32_t> unreadMsgs, QString _messageBody, QString _filepathToAttach, bool cIsContactRequest)
{
    if (m_chatIsBeingViewed) {
        // check if the same chat has been clicked again, and don't do anything
        // in that case except if a new draft should be set
        if (currentMsgContext && m_chatID == cID && aID == dc_get_id(currentMsgContext) && _messageBody == "" && _filepathToAttach == "") {
            qDebug() << "ChatModel::configure(): called for already opened chat, returning";
            return;
        }

        // If ChatView.qml is active, it will set it back
        // to true again once it has updated its properties such
        // as pageChatID. In the meantime, dont' allow setting the
        // draft text as it would be set for the wrong chat ID
        m_settingDraftTextAllowed = false;

        // If the chat is already viewed, there might be a draft from the
        // currently viewed (= now previous) chat. If the chat is not viewed,
        // there should be no draft.
        // Save the draft from the previous chat.
        saveDraft();
        m_draftTextHash.clear();
    }

    beginResetModel();

    if (m_webxdcImgProvider) {
        m_webxdcImgProvider->clearImageCache();
    }
    
    msgIdsWithExpandedQuote.clear();

    // invalidate the cached data_tempMsg (see ChatModel::data())
    data_row = std::numeric_limits<int>::max();
    if (data_tempMsg) {
        dc_msg_unref(data_tempMsg);
        data_tempMsg = nullptr;
    }

    m_isContactRequest = cIsContactRequest;

    m_chatID = cID;

    if (currentMsgContext) {
        dc_context_unref(currentMsgContext);
    }
    currentMsgContext = dc_accounts_get_account(allAccs, aID);

    // update m_accIdChatIdKey
    QString tempQString;
    tempQString.setNum(aID);
    m_accIdChatIdKey = tempQString;
    m_accIdChatIdKey.append("_");
    tempQString.setNum(m_chatID);
    m_accIdChatIdKey.append(tempQString);


    dc_array_t* msgArray = dc_get_chat_msgs(currentMsgContext, m_chatID, 0, 0);
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
    } else {
        // it's a contact request, just delete possible notifications
        m_dhandler->removeActiveNotificationsOfChat(m_dhandler->getCurrentAccountId(), m_chatID);
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

    // If in two-column mode, ChatModel::configure is called repeatedly without
    // the connection below being reset. In one-column mode, the chat view is
    // actually closed and the signal/slot connection is disconnected. This can
    // be tracked via m_chatIsBeingViewed.
    if (!m_chatIsBeingViewed) {
        m_chatIsBeingViewed = true;
        bool connectSuccess = connect(m_dhandler, SIGNAL(msgsChanged(int)), this, SLOT(newMessage(int)));
        if (!connectSuccess) {
            qDebug() << "Chatmodel::configure: Could not connect signal msgsChanged to slot newMessage";
        }
    }

    endResetModel();

    // if there's a leftover of a previous visit of
    // another (or even this) chat view, unref the draf
    // message
    // TODO: handle upon leaving the chat view page?
    if (currentMessageDraft) {
        dc_msg_unref(currentMessageDraft);
    }

    // Check if a new draft has to be set for the chat, this
    // is the case if one or both of _messageBody and _filepathToAttach
    // are set
    if (_messageBody != "" || _filepathToAttach != "") {
        // TODO: check if there's already a draft for this chat, save it
        // somehow and load it after sending the message with _messageBody?
        if (_filepathToAttach == "") {
            // set a new draft with text, but no file
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);
            dc_msg_set_text(currentMessageDraft, _messageBody.toUtf8().constData());
            dc_set_draft(currentMsgContext, m_chatID, currentMessageDraft);

        } else {
            // set a new draft with a file as given in _filepathToAttach, and possibly text
            tempQString = _filepathToAttach;
            if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
                _filepathToAttach.remove(0, 7);
            }

            tempQString = _filepathToAttach;
            if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
                _filepathToAttach.remove(0, 4);
            }

            // check for the type of the file, and set the message type accordingly
            // .xdc and .vcf are detected via file extension
            if (_filepathToAttach.endsWith(".xdc")) {
                currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_WEBXDC);
            } else if (_filepathToAttach.endsWith(".vcf")) {
                currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_VCARD);
            } else {
                // Check if it is an image. Maybe this could be done via mime as
                // the check for audio below, but it seems more reliable with QImage.
                // Test for image before testing for audio as this check is currently
                // mostly relevant for Webxdc (sendToChat()), and images are
                // more likely to be send from there.
                QImage testimage(_filepathToAttach);
                if (!testimage.isNull()) {
                    // it's an image!
                    if (isGif(_filepathToAttach)) {
                        currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_GIF);
                    } else {
                        currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_IMAGE);
                    }
                } else {
                    // Not an image, now check for audio. Can't be done as easy as for
                    // images because QMediaPlayer  will return immediately after
                    // setMedia(QUrl::fromLocalFile(_filepathToAttach)), and the file
                    // will not have been loaded to the player yet, so we would have
                    // to wait for mediaStatusChanged() or such.
                    // Too complicated for now, so do it via mime type.
                    QMimeDatabase mimedb;
                    QMimeType mime = mimedb.mimeTypeForFile(_filepathToAttach);
                    if (mime.name().contains("audio", Qt::CaseInsensitive)) {
                        currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_AUDIO);
                    } else {
                        // it's none of WEBXDC, VCARD, GIF, IMAGE, AUDIO, so use FILE
                        // TODO once a delegate + attachment preview has been added for
                        // DC_MSG_VIDEO, check for video here as well.
                        currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_FILE);
                    }
                }
            }

            dc_msg_set_file(currentMessageDraft, _filepathToAttach.toUtf8().constData(), NULL);
            // Set the text just in case, it's no problem if _messageBody is empty
            dc_msg_set_text(currentMessageDraft, _messageBody.toUtf8().constData());
            dc_set_draft(currentMsgContext, m_chatID, currentMessageDraft);
        }
    } else {
        currentMessageDraft = dc_get_draft(currentMsgContext, m_chatID);
    }

    if (currentMessageDraft) {
        char* tempText = dc_msg_get_text(currentMessageDraft);
        m_draftTextHash[m_accIdChatIdKey] = tempText;
        dc_str_unref(tempText);
    }
    
    emit newChatConfigured(m_chatID);
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

    dc_array_t* newMsgArray = dc_get_chat_msgs(currentMsgContext, m_chatID, 0, 0);
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
                // mark new message as seen, but only if it is present in msgVector (it might
                // not be if it was a message draft that has been deleted)
                // It's not always a new message that is passed as parameter - take care to only mark new ones as seen
                dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, msgID);
                if (tempMsg) {
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
                }

                // notify view
                emit QAbstractItemModel::dataChanged(index(i, 0), index(i, 0));

                // the message above might have to change its appearance (edge
                // of speech bubble, avatar)
                if (i + 1 < currentMsgCount) {
                    emit QAbstractItemModel::dataChanged(index(i + 1, 0), index(i + 1, 0));
                }
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


bool ChatModel::momentaryMessageIsFromSelf()
{
    bool retval {false};

    dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, m_MomentaryMsgId);
    if (tempMsg) {
        retval = dc_msg_get_from_id(tempMsg) == DC_CONTACT_ID_SELF;
        dc_msg_unref(tempMsg);
    } else {
        qDebug() << "ChatModel::momentaryMessageIsFromSelf(): ERROR obtaining momentary message";
    }

    return retval;
}


void ChatModel::momentaryMessageReplyPrivately()
{
    dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, m_MomentaryMsgId);

    if (!tempMsg) {
        qDebug() << "ChatModel::momentaryMessageReplyPrivately(): ERROR obtaining momentary message";
        return;
    }

    uint32_t tempContactId = dc_msg_get_from_id(tempMsg);

    uint32_t tempChatId = dc_create_chat_by_contact_id(currentMsgContext, tempContactId);
    if (0 == tempChatId) {
        qDebug() << "ChatModel::momentaryMessageReplyPrivately(): ERROR creating chat for contact ID " << tempContactId;
        dc_msg_unref(tempMsg);
        return;
    }

    // For replying privately, the group chat message that is being
    // replied to should be quoted in the private chat.
    dc_msg_t* tempDraft = dc_get_draft(currentMsgContext, tempChatId);

    if (!tempDraft) {
        tempDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);
    }

    if (tempDraft) {
        dc_msg_set_quote(tempDraft, tempMsg);
        dc_set_draft(currentMsgContext, tempChatId, tempDraft);
        dc_msg_unref(tempDraft);
    } else {
        qDebug() << "ChatModel::momentaryMessageReplyPrivately(): ERROR creating creating draft, continuing without setting draft";
    }

    dc_msg_unref(tempMsg);

    m_dhandler->selectChatByChatId(tempChatId);
    m_dhandler->openChat();
}


void ChatModel::deleteAllMessagesInCurrentChat()
{
    std::vector<uint32_t> tempVector = msgVector;

    if (-1 != m_unreadMessageBarIndex) {
        // unread message bar needs to be removed
        // from the vector
        std::vector<uint32_t>::iterator it;
        it = tempVector.begin();
        
        tempVector.erase(it + m_unreadMessageBarIndex);
    }

    dc_delete_msgs(currentMsgContext, tempVector.data(), tempVector.size());
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
    return dc_get_fresh_msg_cnt(currentMsgContext, m_chatID);
}


int ChatModel::getUnreadMessageBarIndex()
{
    return m_unreadMessageBarIndex;
}


bool ChatModel::chatCanSend()
{
    dc_chat_t* tempChat = dc_get_chat(currentMsgContext, m_chatID);

    if (!tempChat) {
        qDebug() << "ChatModel::chatCanSend(): ERROR getting chat, returning false.";
        return false;
    }

    bool retval = (1 == dc_chat_can_send(tempChat));
    dc_chat_unref(tempChat);

    return retval;
}


bool ChatModel::chatIsProtectionBroken()
{
    dc_chat_t* tempChat = dc_get_chat(currentMsgContext, m_chatID);

    if (!tempChat) {
        qDebug() << "ChatModel::chatIsProtectionBroken(): ERROR getting chat, returning false.";
        return false;
    }

    bool retval = (1 == dc_chat_is_protection_broken(tempChat));
    dc_chat_unref(tempChat);

    return retval;
}


bool ChatModel::chatIsDeviceTalk()
{
    dc_chat_t* tempChat = dc_get_chat(currentMsgContext, m_chatID);

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

    dc_array_t* tempContactsArray = dc_get_chat_contacts(currentMsgContext, m_chatID);
    
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


QString ChatModel::getMomentaryFilenameToExport()
{
    QString fileBasename = m_tempExportPath.section('/', -1);
    return fileBasename;
}


QString ChatModel::exportFileToFolder(QString sourceFilePath, QString destinationFolder)
{
    QString sourceFileName = sourceFilePath.section('/', -1);

    QString tempQString = sourceFilePath;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        sourceFilePath.remove(0, 7);
    }

    tempQString = sourceFilePath;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        sourceFilePath.remove(0, 4);
    }

    tempQString = destinationFolder;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        destinationFolder.remove(0, 7);
    }

    tempQString = destinationFolder;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        destinationFolder.remove(0, 4);
    }

    QString destinationFile = destinationFolder + "/" + sourceFileName;

    int counter {1};

    while (QFile::exists(destinationFile)) {
        QString basename = sourceFileName;
        QString suffix = basename.section('.', -1);
        basename.remove(basename.length() - 4, 4);
        QString tempNumber;
        tempNumber.setNum(counter);
        basename.append("_");
        basename.append(tempNumber);
        basename.append(".");
        basename.append(suffix);
        destinationFile = destinationFolder + "/" + basename;

        ++counter;
    }

    qDebug() << "ChatModel::exportFileToFolder(): copying " << sourceFilePath << " to " << destinationFile;
    bool success = QFile::copy(sourceFilePath, destinationFile);

    // If the export was not successful, an empty string
    // is returned. In case of success, the export path
    // is returned.
    if (success) {
        return destinationFile;
    } else {
        return "";
    }
}


QString ChatModel::exportMomentaryFileToFolder(QString destinationFolder)
{
    QString sourceFile = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    sourceFile.append("/");
    sourceFile.append(m_tempExportPath);

    QString tempQString = destinationFolder;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        destinationFolder.remove(0, 7);
    }

    tempQString = destinationFolder;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        destinationFolder.remove(0, 4);
    }

    QString destinationFile = destinationFolder + "/" + getMomentaryFilenameToExport();

    unsigned int counter {1};

    while (QFile::exists(destinationFile)) {
        QString basename = getMomentaryFilenameToExport();
        QString suffix = basename.section('.', -1);
        basename.remove(basename.length() - 4, 4);
        QString tempNumber;
        tempNumber.setNum(counter);
        basename.append("_");
        basename.append(tempNumber);
        basename.append(".");
        basename.append(suffix);
        destinationFile = destinationFolder + "/" + basename;

        ++counter;
    }

    qDebug() << "ChatModel::exportMomentaryFileToFolder(): copying " << sourceFile << " to " << destinationFile;
    bool success = QFile::copy(sourceFile, destinationFile);

    // If the export was not successful, an empty string
    // is returned. In case of success, the export path
    // is returned.
    if (success) {
        return destinationFile;
    } else {
        return "";
    }
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
            retval = DeltaHandler::MsgViewType::WebxdcType;
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


void ChatModel::addVcardByIndexAndStartChat(int myindex)
{
    uint32_t tempMsgID = msgVector[myindex];
    dc_msg_t* tempMsg = dc_get_msg(currentMsgContext, tempMsgID);

    char* tempText;
    QString tempQString;

    if (tempMsg) {

        if (dc_msg_get_viewtype(tempMsg) != DC_MSG_VCARD) {
            qDebug() << "ChatModel::addVcardByIndexAndStartChat(): ERROR: Message with ID " << tempMsgID << " is not of type DC_MSG_VCARD";
            dc_msg_unref(tempMsg);
            return;
        }

        tempText = dc_msg_get_file(tempMsg);
        tempQString = tempText;
        dc_str_unref(tempText);

        if (tempQString == "") {
            qDebug() << "ChatModel::addVcardByIndexAndStartChat(): ERROR: No file attached to message with ID " << tempMsgID;
            dc_msg_unref(tempMsg);
            return;
        }

        dc_msg_unref(tempMsg);
    } else {
        qDebug() << "ChatModel::addVcardByIndexAndStartChat(): ERROR: Could not get message with ID " << tempMsgID;
        return;
    }
    
    QString paramString;
    paramString.setNum(dc_get_id(currentMsgContext));
    paramString.append(", \"");
    paramString.append(tempQString);
    paramString.append("\"");
    QString tempQString2 = m_dhandler->constructJsonrpcRequestString("import_vcard", paramString);
    QByteArray byteArray = m_dhandler->sendJsonrpcBlockingCall(tempQString2).toLocal8Bit();
    QJsonDocument jsonDoc = QJsonDocument::fromJson(byteArray);

    // upon success: {"id":1000000125,"jsonrpc":"2.0","result":[17]}
    // upon error: e.g. {"error":{"code":-32602,"message":"This method takes an array of 2 arguments"},"id":1000000125,"jsonrpc":"2.0"}
    QJsonObject jsonObj = jsonDoc.object();
    if (jsonObj.contains("error")) {
        jsonObj = jsonObj.value("error").toObject();
        qDebug() << "ChatModel::addVcardByIndexAndStartChat(): Error importing vcard: " << jsonObj.value("message").toString();
        return;
    }

    if (jsonObj.value("result").isArray()) {
        QJsonArray jsonArray = jsonObj.value("result").toArray();
        if (jsonArray.count() > 0) {
            if (jsonArray.at(0).isDouble()) {
                int tempContactId  = jsonArray.at(0).toInt();
                uint32_t tempChatId = dc_create_chat_by_contact_id(currentMsgContext, tempContactId);
                if (0 == tempChatId) {
                    qDebug() << "ChatModel::addVcardByIndexAndStartChat(): ERROR creating chat for contact ID " << tempContactId;
                } else {
                    m_dhandler->selectChatByChatId(tempChatId);
                    m_dhandler->openChat();
                }
            } else {
                qDebug() << "ChatModel::addVcardByIndexAndStartChat(): ERROR: Jsonrpc did not contain a number in the array";
            }
        } else {
            qDebug() << "ChatModel::addVcardByIndexAndStartChat(): ERROR: Jsonrpc returned an empty array instead of a contact ID";
        }
    } else {
        qDebug() << "ChatModel::addVcardByIndexAndStartChat(): ERROR: result of jsonrpc call is not an array";
    }
}


uint32_t ChatModel::getCurrentChatId()
{
    return m_chatID;
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


QString ChatModel::copyToCache(QString filepath) const
{
    // Copies the file in filepath to the CacheLocation, preferably
    // to a file with the same filename. Existing files are not
    // overwritten. If needed, _<number> will be appended to the
    // filename.
    QString sourceFileName = filepath.section('/', -1);

    QString destinationFolder(QStandardPaths::writableLocation(QStandardPaths::CacheLocation));
    destinationFolder.append("/");

    QString destinationFile = destinationFolder;
    destinationFile.append(sourceFileName);

    unsigned int counter {1};

    QString filenameInCache = sourceFileName;

    while (QFile::exists(destinationFile)) {
        QString basename = sourceFileName;
        QString suffix = basename.section('.', -1);
        basename.remove(basename.length() - 4, 4);
        QString tempNumber;
        tempNumber.setNum(counter);
        basename.append("_");
        basename.append(tempNumber);
        basename.append(".");
        basename.append(suffix);
        filenameInCache = basename;
        destinationFile = destinationFolder + basename;

        ++counter;
    }

    bool success = QFile::copy(filepath, destinationFile);
    if (success) {
        return filenameInCache;
    } else {
        qDebug() << "ChatModel::copyToCache(): ERROR: copying " << filepath << " to " << destinationFile << " failed";
        return "";
    }
}


QString ChatModel::getDraftText()
{
    dc_msg_t* tempMsg {nullptr};
    char* tempText {nullptr};
    QString tempQString("");
    
    tempMsg = dc_get_draft(currentMsgContext, m_chatID);

    if (tempMsg) {
        tempText = dc_msg_get_text(tempMsg);
        tempQString = tempText;
        dc_str_unref(tempText);
        dc_msg_unref(tempMsg);
    }

    return tempQString;
}


void ChatModel::setDraftText(QString draftText)
{
    if (!m_settingDraftTextAllowed) {
        return;
    }

    m_draftTextHash[m_accIdChatIdKey] = draftText;
    return;
}



void ChatModel::saveDraft() {
    if (!m_chatIsBeingViewed) {
        return;
    }

    QString draftText {""};
    // TODO: use m_accIdChatIdKey or build it up from m_chatID etc?
    if (m_draftTextHash.contains(m_accIdChatIdKey)) {
        draftText = m_draftTextHash[m_accIdChatIdKey];
    }

    if (currentMessageDraft) {
        if ("" == draftText && !draftHasQuote() && !draftHasAttachment()) {
            dc_set_draft(currentMsgContext, m_chatID, NULL);
            dc_msg_unref(currentMessageDraft);
            currentMessageDraft = nullptr;

        } else {
            dc_msg_set_text(currentMessageDraft, draftText.toUtf8().constData());
            dc_set_draft(currentMsgContext, m_chatID, currentMessageDraft);
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
        dc_set_draft(currentMsgContext, m_chatID, currentMessageDraft);
    }

    // TODO when do this?
    //m_draftTextHash.clear();
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
    dc_set_draft(currentMsgContext, m_chatID, currentMessageDraft);
    emit draftHasQuoteChanged();

    dc_msg_unref(tempMsg);
}


void ChatModel::unsetQuote()
{
    if (draftHasQuote()) {
        dc_msg_set_quote(currentMessageDraft, NULL);

        QString draftText;
        if (m_draftTextHash.contains(m_accIdChatIdKey)) {
            draftText = m_draftTextHash[m_accIdChatIdKey];
        }

        // if the quote was the only thing in the draft,
        // delete the draft
        if ("" == draftText && !draftHasAttachment()) {
            dc_msg_unref(currentMessageDraft);
            currentMessageDraft = nullptr;
            dc_set_draft(currentMsgContext, m_chatID, NULL);
        } else {
            // If there was no text in the draft when entering the chat, but
            // the user has entered text in the meantime, draftText will be
            // the entered string, but currentMessageDraft will not contain any
            // text. After removing the quote, currentMessageDraft may actually be
            // empty, so we have to set the text now to avoid a user visible error
            // by the core
            dc_msg_set_text(currentMessageDraft, draftText.toUtf8().constData());
            dc_set_draft(currentMsgContext, m_chatID, currentMessageDraft);
        }
        emit draftHasQuoteChanged();
    }
}


void ChatModel::setAttachment(QString filepath, int attachType)
{
    // filePath might be prepended by "file://" or "qrc:",
    // remove it
    QString tempQString = filepath;
    if (QString("file://") == tempQString.remove(7, tempQString.size() - 7)) {
        filepath.remove(0, 7);
    }

    tempQString = filepath;
    if (QString("qrc:") == tempQString.remove(4, tempQString.size() - 4)) {
        filepath.remove(0, 4);
    }

    if (DeltaHandler::MsgViewType::FileType == attachType && filepath.endsWith(".xdc")) {
        // re-write attachType if the file is a Webxdc app
        // TODO: Check for suffix sufficient?
        attachType = DeltaHandler::MsgViewType::WebxdcType;
    }

    dc_msg_t* tempQuote {nullptr};

    if (currentMessageDraft) {
        // delete the current message draft as it may have the 
        // wrong message type (TODO: can the type of an existing
        // message be changed? Then we could avoid this => looks
        // like this will come with the re-write of the composer
        // in dc-core, but it's not there yet)
        //
        // Save the quote if it exists; will be re-added below
        tempQuote = dc_msg_get_quoted_msg(currentMessageDraft);

        // Then delete the old currentMessageDraft
        dc_msg_unref(currentMessageDraft);
        currentMessageDraft = nullptr;
    } 

    int messageType; 
    
    // Get a new draft message based on the passed attachment type. This
    // should be one of DeltaHandler::msgViewType; it's int in the method
    // signature because the compiler won't take it otherwise (seems to
    // only work in the class where the enum is declared)
    switch (attachType) {
        case DeltaHandler::MsgViewType::AudioType:
            messageType = DC_MSG_AUDIO;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_AUDIO);
            break;

        case DeltaHandler::MsgViewType::FileType:
            messageType = DC_MSG_FILE;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_FILE);
            break;
        
        case DeltaHandler::MsgViewType::GifType:
            messageType = DC_MSG_GIF;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_GIF);
            break;
        
        case DeltaHandler::MsgViewType::ImageType:
            messageType = DC_MSG_IMAGE;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_IMAGE);
            break;
        
        case DeltaHandler::MsgViewType::StickerType:
            messageType = DC_MSG_STICKER;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_STICKER);
            break;
        
        case DeltaHandler::MsgViewType::TextType:
            messageType = DC_MSG_TEXT;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);
            break;

        case DeltaHandler::MsgViewType::VcardType:
            messageType = DC_MSG_VCARD;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_VCARD);
            break;
        
        case DeltaHandler::MsgViewType::VideoType:
            messageType = DC_MSG_VIDEO;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_VIDEO);
            break;
        
        case DeltaHandler::MsgViewType::VideochatInvitationType:
            messageType = DC_MSG_VIDEOCHAT_INVITATION;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_VIDEOCHAT_INVITATION);
            break;
        
        case DeltaHandler::MsgViewType::VoiceType:
            messageType = DC_MSG_VOICE;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_VOICE);
            break;

        case DeltaHandler::MsgViewType::WebxdcType:
            messageType = DC_MSG_WEBXDC;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_WEBXDC);
            break;

        default:
            messageType = DC_MSG_FILE;
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_FILE);
            break;
    } 

    if (tempQuote) {
        dc_msg_set_quote(currentMessageDraft, tempQuote);
        dc_msg_unref(tempQuote);
    } 

    dc_msg_set_file(currentMessageDraft, filepath.toUtf8().constData(), NULL);
    dc_set_draft(currentMsgContext, m_chatID, currentMessageDraft);

    emitDraftHasAttachmentSignals(filepath, messageType);
}


void ChatModel::setVcardAttachment(uint32_t contactId)
{
    if (0 == contactId) {
        return;
    }

    QString tempString{""};
    QString paramString{""};

    paramString.setNum(dc_get_id(currentMsgContext));
    paramString.append(", [");

    tempString.setNum(contactId);

    paramString.append(tempString);
    paramString.append("]");

    tempString = m_dhandler->constructJsonrpcRequestString("make_vcard", paramString);

    QByteArray byteArray = m_dhandler->sendJsonrpcBlockingCall(tempString).toLocal8Bit();

    QJsonDocument jsonDoc = QJsonDocument::fromJson(byteArray);
    QJsonObject jsonObj = jsonDoc.object();

    // create the vcard as file in the cache
    QString tempFilename = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/vcard.vcf";
    if (QFile::exists(tempFilename)) {
        QFile::remove(tempFilename);
    }
    std::ofstream outfile(tempFilename.toStdString());

    // the result directly contains the vcard as string
    outfile << jsonObj.value("result").toString().toStdString();

    outfile.close();

    setAttachment(tempFilename, DeltaHandler::MsgViewType::VcardType);
}


void ChatModel::checkDraftHasAttachment() {
    if (draftHasAttachment()) {
        // get the attachment path
        char* tempText = dc_msg_get_file(currentMessageDraft);
        QString filepath = tempText; 
        dc_str_unref(tempText);

        int messageType = dc_msg_get_viewtype(currentMessageDraft);

        emitDraftHasAttachmentSignals(filepath, messageType);
    }
}


void ChatModel::emitDraftHasAttachmentSignals(QString filepath, int messageType)
{
    bool alreadyInCache {false};

    // create a string with the base filename, in case ChatView wants to show
    // it in the preview area. Not guaranteed to be in cache.
    QString filename = filepath;

    if (filename.lastIndexOf("/") != -1) {
        filename = filename.remove(0, filename.lastIndexOf("/") + 1);
    }

    // The path to the file, guaranteed to be in the cache, without the
    // leading CacheLocation. It's the filename itself if the file is in the
    // top level cache dir, or the path in the cache dir ("exampleDir/examplefile.jpg")
    QString filenameInCache;

    if (filepath.startsWith(QStandardPaths::writableLocation(QStandardPaths::CacheLocation))) {
        filenameInCache = filepath;
        filenameInCache.remove(0, QStandardPaths::writableLocation(QStandardPaths::CacheLocation).length() + 1);
        alreadyInCache = true;
    }

    QString tempQString1 {""};
    QString tempQString2 {""};
    QString tempQString3 {""};
    QString tempQString4 {""};
    char* tempText;

    QByteArray byteArray;
    QJsonDocument jsonDoc;
    QJsonObject jsonObj;
    QJsonArray jsonArray;

    // tell ChatView.qml that an attachment has been added
    switch (messageType) {

        case DC_MSG_AUDIO:
            if (!alreadyInCache) {
                filenameInCache = copyToCache(filepath);
            } // if the file is already in cache, filenameInCache has
              // been set above
            emit previewAudioAttachment(filenameInCache, filename);
            break;
        
        case DC_MSG_VOICE:
            // should be in the cache for voice messages,
            // but just to be sure
            if (!alreadyInCache) {
                filenameInCache = copyToCache(filepath);
            } 
            emit previewVoiceAttachment(filenameInCache);
            break;

        case DC_MSG_FILE:
            emit previewFileAttachment(filename);
            break;
        
        case DC_MSG_GIF:
            // fallthrough
        
        case DC_MSG_STICKER:
            if (!alreadyInCache) {
                filenameInCache = copyToCache(filepath);
            } 
            // second parameter states whether it's animated
            emit previewImageAttachment(filenameInCache, true);
            break;
        
        case DC_MSG_IMAGE:
            if (!alreadyInCache) {
                filenameInCache = copyToCache(filepath);
            } 
            emit previewImageAttachment(filenameInCache, false);
            break;

        case DC_MSG_VCARD:
            // get the Vcard in parsed form to retrieve name, addr + color of contact
            tempQString1 = "\"" + filepath + "\"";
            tempQString2 = m_dhandler->constructJsonrpcRequestString("parse_vcard", tempQString1);
            byteArray = m_dhandler->sendJsonrpcBlockingCall(tempQString2).toLocal8Bit();
            jsonDoc = QJsonDocument::fromJson(byteArray);
            jsonObj = jsonDoc.object();

            if (jsonObj.contains("error")) {
                jsonObj = jsonObj.value("error").toObject();
                qDebug() << "ChatModel::emitDraftHasAttachmentSignals(): Error importing vcard: " << jsonObj.value("message").toString();
            } else {
                // "result" is an array in this case:
                //{"id":1000000131,"jsonrpc":"2.0","result":[{"addr":"...",...}]}
                if (jsonObj.value("result").isArray()) {
                    jsonArray = jsonObj.value("result").toArray();
                    if (jsonArray.count() > 0) {
                        if (jsonArray.at(0).isObject()) {
                            jsonObj = jsonArray.at(0).toObject();

                            tempQString4 = "image://webxdcImageProvider/";

                            if (jsonObj.contains("profileImage") && !jsonObj.value("profileImage").isNull()) {
                                tempQString1 = jsonObj.value("profileImage").toString();
                                // the image in the vcard is base64 encoded, decode it
                                byteArray = QByteArray::fromBase64(tempQString1.toLocal8Bit());
                            } else {
                                byteArray.clear();
                            }
                            tempQString4.append(m_webxdcImgProvider->getImageId(dc_get_id(currentMsgContext), m_chatID, dc_msg_get_id(currentMessageDraft), byteArray));

                            tempQString1 = jsonObj.value("addr").toString();
                            tempQString2 = jsonObj.value("displayName").toString();
                            tempQString3 = jsonObj.value("color").toString();

                            emit previewVcardAttachment(tempQString1, tempQString2, tempQString3, tempQString4);
                        } else {
                            qDebug() << "ChatModel::emitDraftHasAttachmentSignals(): ERROR reading vcard at " << filepath << ": index 0 in array is not an object";
                        }
                    } else {
                        qDebug() << "ChatModel::emitDraftHasAttachmentSignals(): ERROR reading vcard at " << filepath << ": empty array returned by jsonrpc call";
                    }
                } else {
                    qDebug() << "ChatModel::emitDraftHasAttachmentSignals(): ERROR reading vcard at " << filepath << ": no array returned by jsonrpc call";
                }
            }
            break;

        case DC_MSG_WEBXDC:
            // the icon of the Webxdc app
            tempQString1 = "image://webxdcImageProvider/";
            tempQString1.append(m_webxdcImgProvider->getImageId(dc_get_id(currentMsgContext), m_chatID, dc_msg_get_id(currentMessageDraft), currentMessageDraft));

            // the info JSON of the Webxdc app
            tempText = dc_msg_get_webxdc_info(currentMessageDraft);
            if (tempText) {
                tempQString2 = tempText;
                dc_str_unref(tempText);
            } else {
                // TODO: how to handle this situation?
            }
            
            emit previewWebxdcAttachment(tempQString1, tempQString2);
            break;
        
        // add more when implemented

        default:
            qDebug() << "ChatModel::emitDraftHasAttachmentSignals() reached default case in switch";
            break;
    }
}


void ChatModel::unsetAttachment()
{
    // TODO don't get the text of the draft, but use m_draftTextHash?
    if (currentMessageDraft) {
        QString tempQString {""};
        char* tempText = dc_msg_get_text(currentMessageDraft);
        if (tempText) {
            tempQString = tempText;
            dc_str_unref(tempText);
        }

        dc_msg_t* tempQuote = dc_msg_get_quoted_msg(currentMessageDraft);

        dc_msg_unref(currentMessageDraft);
        currentMessageDraft = nullptr;

        if (tempQString != "" || tempQuote) {
            currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);
            dc_msg_set_text(currentMessageDraft, tempQString.toUtf8().constData());

            // need to check because draftHasQuote == true doesn't mean
            // that there's an actual quoted message (could be only 
            // quoted text, in that case the quote will be lost (TODO, but
            // maybe that can only be solved once the core implements
            // viewtype changes of drafts))
            if (tempQuote) {
                dc_msg_set_quote(currentMessageDraft, tempQuote);
                dc_msg_unref(tempQuote);
            }

            dc_set_draft(currentMsgContext, m_chatID, currentMessageDraft);
        } else {
            dc_set_draft(currentMsgContext, m_chatID, NULL);
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
    
    bool toggleQuoteExpandedState {false};

    if (quotedMsg) {
        uint32_t tempChatID = dc_msg_get_chat_id(quotedMsg);
        if (m_chatID != tempChatID) {
            qDebug() << "ChatModel::initiateQuotedMsgJump: Message to jump to is in different chat";
            toggleQuoteExpandedState = true;
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
                toggleQuoteExpandedState = true;
            }
        } // end else
    } else { // (quotedMsg)
        qDebug() << "ChatModel::initiateQuotedMsgJump: No quoted message attached";
        toggleQuoteExpandedState = true;
    }

    if (tempMsg) {
        dc_msg_unref(tempMsg);
    }

    if (quotedMsg) {
        dc_msg_unref(quotedMsg);
    }

    // The jump to the quoted message could not be
    // initiated for one of the reasons above, so
    // the quote will be expanded (or collapsed,
    // if it's already expanded).
    if (toggleQuoteExpandedState) {
        if (toggleQuoteVectorContainsId(tempMsgID)) {
            toggleQuoteVectorRemoveId(tempMsgID);
        } else {
            msgIdsWithExpandedQuote.push_back(tempMsgID);
        }
        emit QAbstractItemModel::dataChanged(index(myindex, 0), index(myindex, 0));
    }
}


bool ChatModel::toggleQuoteVectorContainsId(const uint32_t tempID) const
{
    bool found = false;

    for (size_t i = 0; i < msgIdsWithExpandedQuote.size(); ++i) {
        if (msgIdsWithExpandedQuote[i] == tempID) {
            found = true;
            break;
        }
    }
    return found;
}


void ChatModel::toggleQuoteVectorRemoveId(uint32_t tempID)
{
    for (size_t i = 0; i < msgIdsWithExpandedQuote.size(); ++i) {
        if (msgIdsWithExpandedQuote[i] == tempID) {
            msgIdsWithExpandedQuote.erase(msgIdsWithExpandedQuote.begin() + i);
            break;
        }
    }
}


void ChatModel::newChatlistmodel()
{
    if (m_chatlistmodel) {
        delete m_chatlistmodel;
        m_chatlistmodel = nullptr;
    }

    m_chatlistmodel = new ChatlistModel();
    m_chatlistmodel->configure(currentMsgContext, DC_GCL_FOR_FORWARDING | DC_GCL_NO_SPECIALS);
}


void ChatModel::deleteChatlistmodel()
{
    if (m_chatlistmodel) {
        delete m_chatlistmodel;
        m_chatlistmodel = nullptr;
    }
}


void ChatModel::forwardMessage(uint32_t chatIdToForwardTo, uint32_t msgId)
{
    qDebug() << "ChatModel::forwardMessage(): Forwarding message ID " << msgId << " to chat ID " << chatIdToForwardTo;
    dc_forward_msgs(currentMsgContext, &msgId, 1, chatIdToForwardTo);
}


int ChatModel::indexToMessageId(int myindex)
{
    if (-1 != m_unreadMessageBarIndex && myindex == m_unreadMessageBarIndex) {
        return -1;
    } else {
        return msgVector[myindex];
    }
}


uint32_t ChatModel::setWebxdcInstance(int myindex)
{
    if (-1 == myindex) {
        if (currentMessageDraft) {
            m_webxdcInstanceMsgId = dc_msg_get_id(currentMessageDraft);
        } else {
            qDebug() << "ChatModel::setWebxdcInstance(): Error: called with -1 as param, but currentMessageDraft is null";
            m_webxdcInstanceMsgId = 0;
        }
    } else {
        m_webxdcInstanceMsgId = msgVector[myindex];
    }
    return m_webxdcInstanceMsgId;
}


void ChatModel::sendWebxdcInstanceData()
{
    // update the dc_msg_t* used in the scheme handler and the
    // id used for the storage name in the engine profile (both
    // updated via WebxdcEngineProfile::configureNewInstance()
    dc_msg_t* tempmsg = dc_get_msg(currentMsgContext, m_webxdcInstanceMsgId);
    if (tempmsg) {
        // assemble the id
        QString id = m_accIdChatIdKey;
        id.append("_");
        QString tempQString;
        tempQString.setNum(m_webxdcInstanceMsgId);
        id.append(tempQString);

        emit newWebxdcInstanceData(id, tempmsg);
    } else {
        qDebug() << "ChatModel::setWebxdcInstance(): ERROR: tempmsg is null";
        // TODO show error?
    }
}


void ChatModel::sendWebxdcUpdate(QString update, QString description)
{
    // TODO check return value?
    int success = dc_send_webxdc_status_update(currentMsgContext, m_webxdcInstanceMsgId, update.toUtf8().constData(), description.toUtf8().constData());
    if (!success) {
        qDebug() << "ChatModel::sendWebxdcUpdate(): ERROR: dc_send_webxdc_status_update() failed";
    }
}


QString ChatModel::getWebxdcUpdate(int last_serial)
{
    char* tempText = dc_get_webxdc_status_updates(currentMsgContext, m_webxdcInstanceMsgId, last_serial);
    QString retval;
    if (tempText) {
        retval = tempText;
        dc_str_unref(tempText);
    } else {
        retval = "";
    }

    return retval;
}


void ChatModel::sendToChat(uint32_t _chatId, QString _data)
{
    QString tempMsgText {""};
    QString tempFilename {""};

    QJsonDocument jsonDoc = QJsonDocument::fromJson(_data.toLocal8Bit());
    QJsonObject jsonObj = jsonDoc.object();

    if (jsonObj.contains("text")) {
        tempMsgText = jsonObj.value("text").toString();
    }

    if (jsonObj.contains("name")) {
        tempFilename = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/" + jsonObj.value("name").toString();
        if (QFile::exists(tempFilename)) {
            QFile::remove(tempFilename);
        }
        std::ofstream outfile(tempFilename.toStdString());

        QByteArray filedata = QByteArray::fromBase64(jsonObj.value("base64").toString().toLocal8Bit());
        outfile << filedata.toStdString();
    }

    if (tempMsgText == "" && tempFilename == "") {
        qDebug() << "ChatModel::sendToChat(): ERROR: Parameter _data had neither text nor a file";
        return;
    }

    m_dhandler->selectChatByChatId(_chatId);
    m_dhandler->openChat(tempMsgText, tempFilename);
}


QString ChatModel::getWebxdcId()
{
    QString id = m_accIdChatIdKey;
    id.append("_");
    QString tempQString;
    tempQString.setNum(m_webxdcInstanceMsgId);
    id.append(tempQString);

    return id;
}


QString ChatModel::getWebxdcJs(QString scriptname)
{
    if (scriptname == "qwebchannel.js") {
        scriptname.prepend(":/qtwebchannel/");
    } else {
        scriptname.prepend(":/assets/webxdc/");
    }
    QFile jsfile(scriptname);

    if (!jsfile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "ChatModel::getWebxdcJs(): Could not open " << scriptname;
        scriptname.prepend("console.log(\"ChatModel::getWebxdcJs() could not get the script ");
        scriptname.append("\")");
        return scriptname;
    }

    QTextStream in(&jsfile);
    QString retval = in.readAll();
    // not sure if this is needed
    in.flush();
    jsfile.close();
    return retval;
}


void ChatModel::webxdcSendRealtimeData(QString _rtData)
{
    QString tempQString;
    QString paramString;

    tempQString.setNum(dc_get_id(currentMsgContext));
    paramString.append(tempQString);
    paramString.append(", ");

    tempQString.setNum(m_webxdcInstanceMsgId);
    paramString.append(tempQString);

    paramString.append(", ");
    paramString.append(_rtData);

    QString requestString = m_dhandler->constructJsonrpcRequestString("send_webxdc_realtime_data", paramString);
    m_dhandler->sendJsonrpcRequest(requestString);
}


void ChatModel::webxdcSendRealtimeAdvertisement()
{
    QString tempQString;
    QString paramString;

    tempQString.setNum(dc_get_id(currentMsgContext));
    paramString.append(tempQString);
    paramString.append(", ");

    tempQString.setNum(m_webxdcInstanceMsgId);
    paramString.append(tempQString);

    QString requestString = m_dhandler->constructJsonrpcRequestString("send_webxdc_realtime_advertisement", paramString);
    m_dhandler->sendJsonrpcRequest(requestString);
}


void ChatModel::webxdcLeaveRealtimeChannel()
{
    QString tempQString;
    QString paramString;

    tempQString.setNum(dc_get_id(currentMsgContext));
    paramString.append(tempQString);
    paramString.append(", ");

    tempQString.setNum(m_webxdcInstanceMsgId);
    paramString.append(tempQString);

    QString requestString = m_dhandler->constructJsonrpcRequestString("leave_webxdc_realtime", paramString);
    m_dhandler->sendJsonrpcRequest(requestString);
}


void ChatModel::webxdcUpdateReceiver(uint32_t accID, int msgID)
{
    if (m_dhandler && m_dhandler->getCurrentAccountId() == accID && msgID == m_webxdcInstanceMsgId) {
        emit updateCurrentWebxdc();
    } 
}


void ChatModel::webxdcDeleteLocalStorage(uint32_t accID, int msgID)
{
    // This method deletes the local storage of a Webxdc app. Local
    // storagae is located in a separate directory per app named
    // <accID>_<chatID>_<msgID> in 
    // QStandardPaths::writableLocation(QStandardPaths::DataLocation) + "/QtWebEngine/"
    //
    // The method is triggered by DC_EVENT_WEBXDC_INSTANCE_DELETED. This event
    // only has the msgID as parameter, but not the chatID. As the event
    // is emitted after the deletion of the corresponding message,
    // it is not possible to query the core for the chatID anymore;
    // dc_msg_get_chat_id() will always return 0. It's therefore
    // not possible to assemble the string with the path to the
    // directory to remove by just stringify the accID, chatID and msgID.
    //
    // Instead, the string with the path of the directory to be deleted is
    // obtained by checking all subdirectories of dataLocation/QtWebEngine/
    // whether one of these matches the accID and the msgID. This is
    // possible because msgID is unique across a specific account.

    QDir localStorageDir(QStandardPaths::writableLocation(QStandardPaths::DataLocation) + "/QtWebEngine/");

    // get the list of all directories in <cache>/QtWebEngine/
    QStringList allfolders = localStorageDir.entryList(QDir::AllDirs | QDir::NoSymLinks);

    // will contain the directory to be deleted, if it exists
    QString dirToDeleteString {""};

    QString accString;
    QString msgString;
    accString.setNum(accID);
    msgString.setNum(msgID);

    for (int i = 0; i < allfolders.size(); ++i) {
        // Split, e.g., "14_5_523" in three separate strings "14", "5" and "523".
        // separatedString[0] will then contain the accID part and [2] the msgID
        // part
        QStringList separatedString = allfolders[i].split("_");
        if (separatedString.size() == 3) {
            if (separatedString[0] == accString && separatedString[2] == msgString) {
                dirToDeleteString = localStorageDir.absolutePath() + "/" + allfolders[i];
                break;
            }
        }
    }

    if (dirToDeleteString != "") {
        QDir dirToDelete(dirToDeleteString);
        bool success = dirToDelete.removeRecursively();
        if (success) {
            qDebug() << "DeltaHandler::webxdcDeleteLocalStorage(): Successfully removed Webxdc local storage dir " << dirToDeleteString;
        } else {
            qDebug() << "DeltaHandler::webxdcDeleteLocalStorage(): ERROR: could not (completely) remove Webxdc local storage dir " << dirToDeleteString;
        }
    } else {
        qDebug() << "DeltaHandler::webxdcDeleteLocalStorage(): No directory found to delete for Webxdc instance with accID " << accID << " and msgID " << msgID;
    }
}


void ChatModel::checkAndJumpToWebxdcParent(int myindex)
{
    uint32_t msgID = msgVector[myindex];
    dc_msg_t* tempmsg = dc_get_msg(currentMsgContext, msgID);

    if (tempmsg) {
        // if a message has a parent, the parent could be a quote, or,
        // if it's an info message, the parent could be a webxdc
        // message.
        dc_msg_t* parentmsg = dc_msg_get_parent(tempmsg);

        // NULL if no parent
        if (parentmsg) {
            // In this method, only Webxdc parents are considered
            if (dc_msg_get_viewtype(parentmsg) == DC_MSG_WEBXDC) {
                uint32_t parentID = dc_msg_get_id(parentmsg);

                // should be size_t, but the jump signal has an int
                // parameter anyway
                int parentIndex {-1};

                for (size_t i = 0; i < msgVector.size(); ++i) {
                    if (msgVector[i] == parentID) {
                        parentIndex = static_cast<int>(i);
                        break;
                    }
                }

                if (parentIndex > 0) {
                    emit jumpToMsg(parentIndex);
                }
            }

            dc_msg_unref(parentmsg);
        }

        dc_msg_unref(tempmsg);
    }
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


void ChatModel::sendMessage(QString messageText, int accID, int chatID, int cursorPosition)
{
    if (accID != dc_get_id(currentMsgContext)) {
        qFatal("ChatModel::sendMessage(): accID passed to method does not match with the ID of currentMsgContext, aborting");
    }

    if (chatID != m_chatID) {
        qFatal("ChatModel::sendMessage(): chatID passed to method does not match with m_chatID, aborting");
    }

    // If the message has been sent with the Enter key (or Ctrl-Enter), the
    // extra Return will be present in messageText, and cursorPosition is != 0.
    // Remove the extra Return.
    if (cursorPosition > 0 && cursorPosition <= messageText.length() && messageText[cursorPosition - 1] == QChar::LineFeed) {
        messageText.remove(cursorPosition - 1, 1);
    }

    bool needToNotifyAboutQuote = false;

    if (!currentMessageDraft) {
        currentMessageDraft = dc_msg_new(currentMsgContext, DC_MSG_TEXT);

    } else {
         if (draftHasQuote()) {
             needToNotifyAboutQuote = true;
         }
    }

    dc_msg_set_text(currentMessageDraft, messageText.toUtf8().constData());

    dc_send_msg(currentMsgContext, m_chatID, currentMessageDraft);

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


// unusedParam is only there so the signal from ChatView.qml
// can be connected to both a slot in DeltaHandler (which
// needs this parameter) and here (where the parameter
// is not needed)
void ChatModel::chatViewIsClosed(bool unusedParam)
{
    saveDraft();
    m_draftTextHash.clear();
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
    currentSearchMsgArray = dc_search_msgs(currentMsgContext, m_chatID, m_query.toUtf8().constData());
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
