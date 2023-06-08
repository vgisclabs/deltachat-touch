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

#include "groupmembermodel.h"
//#include <unistd.h> // for sleep

GroupMemberModel::GroupMemberModel(QObject* parent)
    : QAbstractListModel(parent), m_context {nullptr}
{ 
};

GroupMemberModel::~GroupMemberModel()
{
}


int GroupMemberModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_membervector.size();
}

QHash<int, QByteArray> GroupMemberModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[DisplayNameRole] = "displayname";
    roles[ProfilePicRole] = "profilePic";
    roles[EmailAddressRole] = "address";
    roles[AvatarColorRole] = "avatarColor";
    roles[AvatarInitialRole] = "avatarInitial";
    roles[IsSelfRole] = "isSelf";
    roles[IsVerifiedRole] = "isVerified";

    return roles;
}

QVariant GroupMemberModel::data(const QModelIndex &index, int role) const
{
    int row = index.row();
    
    if(row < 0 || row >= m_membervector.size()) {
        return QVariant();
    }

    QVariant retval;
    QString tempQString;
    QColor tempQColor;

    char* tempText {nullptr};
    uint32_t tempColor {0};

    uint32_t tempContactID = m_membervector[row];
    dc_contact_t* tempContact = dc_get_contact(m_context, tempContactID);

    switch(role) {
        case GroupMemberModel::DisplayNameRole:
            tempText = dc_contact_get_display_name(tempContact);
            tempQString = tempText;
            retval = tempQString;
            break;

        case GroupMemberModel::ProfilePicRole:
            tempText = dc_contact_get_profile_image(tempContact);
            tempQString = tempText;
            // see comment for ChatModel::data() in chatmodel.cpp
            if (tempQString.length() > QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length()) {
                tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
            }
            else {
                tempQString = "";
            }
            retval = tempQString;
            break;

        case GroupMemberModel::EmailAddressRole:
            tempText = dc_contact_get_addr(tempContact);
            tempQString = tempText;
            retval = tempQString;
            break;

        case GroupMemberModel::AvatarColorRole:
            tempColor = dc_contact_get_color(tempContact);
            tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
            retval = QString(tempQColor.name());
            break;

        case GroupMemberModel::AvatarInitialRole:
            tempText = dc_contact_get_display_name(tempContact);
            tempQString = tempText;
            if (tempQString == "") {
                tempQString = "#";
            } else {
                tempQString = QString(tempQString.at(0)).toUpper();
            }
            retval = tempQString;
            break;

        case GroupMemberModel::IsSelfRole:
            retval = (tempContactID == DC_CONTACT_ID_SELF);
            break;

        case GroupMemberModel::IsVerifiedRole:
            if (2 == dc_contact_is_verified(tempContact)) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        default:
            retval = QVariant();
            qDebug() << "GroupMemberModel::data switch reached default";
            break;
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    dc_contact_unref(tempContact);

    return retval;
}


bool GroupMemberModel::isMember(uint32_t contactID)
{
    for (size_t i = 0; i < m_membervector.size(); ++i) {
        if (contactID == m_membervector[i]) {
            return true;
        }
    }

    return false;
}


void GroupMemberModel::deleteMember(int myindex)
{
    std::vector<uint32_t>::iterator it = m_membervector.begin();

    beginRemoveRows(QModelIndex(), myindex, myindex);
    m_membervector.erase(it + myindex);
    endRemoveRows();
    emit groupMemberCountChanged(m_membervector.size());
}


QString GroupMemberModel::getNameOfIndex(int myindex)
{
    QString tempQString;
    dc_contact_t* tempContact = dc_get_contact(m_context, m_membervector[myindex]);
    char* tempText = dc_contact_get_addr(tempContact);
    tempQString = tempText;

    dc_str_unref(tempText);
    dc_contact_unref(tempContact);

    return tempQString;
}


std::vector<uint32_t> GroupMemberModel::getMembersAlreadyInGroup()
{
    return m_membervector;
}


void GroupMemberModel::addMember(uint32_t contactID)
{
    bool isNotAlreadyInList = true;

    for (size_t i = 0; i < m_membervector.size(); ++i) {
        if (contactID == m_membervector[i]) {
            isNotAlreadyInList = false;
        }
    }

    if (isNotAlreadyInList) {
        beginResetModel();

        // TODO: maybe add it in some sorted way?
        m_membervector.push_back(contactID);
        emit groupMemberCountChanged(m_membervector.size());

        endResetModel();
    }
}


void GroupMemberModel::setConfig(dc_context_t* tempContext, bool creationOfNewGroup, uint32_t tempChatID)
{
    m_context = tempContext;

    if (creationOfNewGroup) {
        m_membervector.resize(1);
        m_membervector[0] = DC_CONTACT_ID_SELF;

    } else {
        m_chatID = tempChatID;
        dc_array_t* tempContactsArray = dc_get_chat_contacts(m_context, m_chatID);
        size_t numberOfContacts = dc_array_get_cnt(tempContactsArray);
        m_membervector.resize(numberOfContacts);

        for (size_t i = 0; i < numberOfContacts; ++i) {
            m_membervector[i] = dc_array_get_id(tempContactsArray, i);
        }

        dc_array_unref(tempContactsArray);
    }
}

int GroupMemberModel::tempGroupMemberCount()
{
    return m_membervector.size();
}

