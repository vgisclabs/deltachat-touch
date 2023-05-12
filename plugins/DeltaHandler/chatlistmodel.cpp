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

#include "chatlistmodel.h"
//#include <unistd.h> // for sleep

ChatlistModel::ChatlistModel(QObject* parent)
    : QAbstractListModel(parent), currentContext {nullptr}, currentChatlist {nullptr}, m_query {""}
{
}


ChatlistModel::~ChatlistModel()
{
    if (currentChatlist) {
        dc_chatlist_unref(currentChatlist);
    }

}


int ChatlistModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);

    if (currentChatlist) {
        return dc_chatlist_get_cnt(currentChatlist);
    }
    else {
        return 0;
    }
}


QHash<int, QByteArray> ChatlistModel::roleNames() const
{
    QHash<int, QByteArray> roles;

    roles[ChatnameRole] = "chatname";
    roles[MsgPreviewRole] = "msgPreview";
    roles[TimestampRole] = "timestamp";
//    roles[StateRole] = "state";
    roles[ChatPicRole] = "chatPic";
//    roles[IsContactRequestRole] = "isContactRequest";
    roles[AvatarColorRole] = "avatarColor";
    roles[AvatarInitialRole] = "avatarInitial";
//    roles[ChatIsMutedRole] = "chatIsMuted";
//    roles[NewMsgCountRole] = "newMsgCount";
    return roles;
}


QVariant ChatlistModel::data(const QModelIndex &index, int role) const
{
    int row = index.row();

    // If row is out of bounds, an empty QVariant is returned
    if(row < 0 || row >= static_cast<int>(dc_chatlist_get_cnt(currentChatlist))) {
        return QVariant();
    }

    uint32_t tempChatID = dc_chatlist_get_chat_id(currentChatlist, row);
    dc_chat_t* tempChat = dc_get_chat(currentContext, tempChatID);
    dc_lot_t* tempLot = dc_chatlist_get_summary(currentChatlist, row, tempChat);

    QString tempQString;
    QVariant retval;
    char* tempText {nullptr};
    uint64_t timestampSecs {0};
    uint32_t tempColor {0};
    QDateTime timestampDate;
    QColor tempQColor;

    switch(role) {
        case ChatlistModel::ChatnameRole:
            tempText = dc_chat_get_name(tempChat); 
            tempQString = tempText;
            retval = tempQString;
            break;
            
        case ChatlistModel::MsgPreviewRole:
            // TODO: internationalize text1, so for example, "Me"
            // will get translated
            tempText = dc_lot_get_text1(tempLot); 

            if (tempText) {
                tempQString = tempText;
                tempQString += ": ";
                dc_str_unref(tempText);
            }

            tempText = dc_lot_get_text2(tempLot); 
            tempQString += tempText;
            retval = tempQString;
            break;

        case ChatlistModel::ChatPicRole:
            tempText = dc_chat_get_profile_image(tempChat);
            tempQString = tempText;
            tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
            retval = tempQString;
            break;

        case ChatlistModel::TimestampRole:
            timestampSecs = dc_lot_get_timestamp(tempLot);
            if (timestampSecs == 0) {
                tempQString = "n/a";
                retval = tempQString;
                break;
            }
            timestampDate = QDateTime::fromSecsSinceEpoch(timestampSecs);
            if (timestampDate.date() == QDate::currentDate()) {
                tempQString = timestampDate.toString("hh:mm");
                // TODO: if <option_for_am/pm> ...("hh:mm ap")
                // => check the QLocale Class
            }
            else if (timestampDate.date().daysTo(QDate::currentDate()) < 7) {
                // TODO: "...hh:mm ap " as above
                tempQString = timestampDate.toString("ddd hh:mm");
            }
            else {
                tempQString = timestampDate.toString("dd MMM yy" );
            }
            retval = tempQString;
            break;

//        case ChatlistModel::IsContactRequestRole:
//            if (dc_chat_is_contact_request(tempChat)) {
//                retval = true;
//            } else {
//                retval = false;
//            }
//            break;

        case ChatlistModel::AvatarColorRole:
            tempColor = dc_chat_get_color(tempChat);
            // doesn't work as it won't take care of leading zeros
            //tempQString = QString::number(tempColor, 16);
            tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
            tempQString = tempQColor.name();
            retval = tempQString;
            break;

        case ChatlistModel::AvatarInitialRole:
            tempText = dc_chat_get_name(tempChat); 
            tempQString = tempText;
            if (tempQString == "") {
                tempQString = "#";
            } else {
               tempQString = QString(tempQString.at(0)).toUpper(); 
            }
            retval = tempQString;
            break;

//        case ChatlistModel::ChatIsMutedRole:
//            if (dc_chat_is_muted(tempChat)) {
//                retval = true;
//            } else {
//                retval = false;
//            }
//
//            break;

//        case ChatlistModel::NewMsgCountRole:
//            retval = dc_get_fresh_msg_cnt(currentContext, tempChatID);
//            break;

        default:
            retval = QString("");

    }

    dc_lot_unref(tempLot);
    dc_chat_unref(tempChat);

    if (tempText) {
        dc_str_unref(tempText);
        tempText = nullptr;
    }

    return retval;

}


void ChatlistModel::configure(dc_context_t* context, int flagsForChatlist)
{
    currentContext = context;
    m_flagsForChatlist = flagsForChatlist;

    currentChatlist = dc_get_chatlist(currentContext, m_flagsForChatlist, NULL, 0);
}


uint32_t ChatlistModel::getChatID(int myindex)
{
    if(myindex < 0 || myindex >= static_cast<int>(dc_chatlist_get_cnt(currentChatlist))) {
        qDebug() << "ChatlistModel::getChatID: ERROR: index out of bounds";
        return 0;
    }

    if (currentChatlist) {
        return dc_chatlist_get_chat_id(currentChatlist, myindex);
    } else {
        qDebug() << "ChatlistModel::getChatID: ERROR: chatlist is not set";
        return 0;
    }

}

void ChatlistModel::updateQuery(QString query) {
    // need to check if something has changed and exit, if not.
    // Otherwise the app will crash because a click on an item in the
    // list will trigger onDisplayTextChanged, which is connected to
    // this method. At the same time, the click on the item will try
    // to access the index of the list via onClicked, but the list is
    // just about to reset by this method here.
    if (query == m_query) {
        return;
    }

    m_query = query;

    beginResetModel();
    dc_chatlist_unref(currentChatlist);
    
    if (m_query == "") {
        currentChatlist = dc_get_chatlist(currentContext, m_flagsForChatlist, NULL, 0);

    } else {
        const char* query_cstring = m_query.toUtf8().constData();
        currentChatlist = dc_get_chatlist(currentContext, m_flagsForChatlist, query_cstring, 0);
    }

    endResetModel();
}
