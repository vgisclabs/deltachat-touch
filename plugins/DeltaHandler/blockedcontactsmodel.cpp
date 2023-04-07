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

#include "blockedcontactsmodel.h"
//#include <unistd.h> // for sleep

BlockedContactsModel::BlockedContactsModel(QObject* parent)
    : QAbstractListModel(parent), m_context {nullptr}, m_contactsArray {nullptr}
{ 
};

BlockedContactsModel::~BlockedContactsModel()
{
    if (m_contactsArray) {
        dc_array_unref(m_contactsArray);
    }
}


int BlockedContactsModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    if (!m_contactsArray) {
        return 0;
    }
    return dc_array_get_cnt(m_contactsArray);
}

QHash<int, QByteArray> BlockedContactsModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[DisplayNameRole] = "displayname";
    roles[ProfilePicRole] = "profilePic";
    roles[EmailAddressRole] = "address";
    roles[AvatarColorRole] = "avatarColor";
    roles[AvatarInitialRole] = "avatarInitial";

    return roles;
}

QVariant BlockedContactsModel::data(const QModelIndex &index, int role) const
{
    int row = index.row();
    
    if (row < 0 || row >= dc_array_get_cnt(m_contactsArray)) {
        return QVariant();
    }

    QVariant retval;
    QString tempQString;
    char* tempText {nullptr};
    uint32_t tempColor {0};
    QColor tempQColor;

    uint32_t tempContactID = dc_array_get_id(m_contactsArray, row);
    dc_contact_t* tempContact = dc_get_contact(m_context, tempContactID);

    switch(role) {
        case BlockedContactsModel::DisplayNameRole:
            tempText = dc_contact_get_display_name(tempContact);
            tempQString = tempText;
            retval = tempQString;
            break;

        case BlockedContactsModel::ProfilePicRole:
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

        case BlockedContactsModel::EmailAddressRole:
            tempText = dc_contact_get_addr(tempContact);
            tempQString = tempText;
            retval = tempQString;
            break;

        case BlockedContactsModel::AvatarColorRole:
            tempColor = dc_contact_get_color(tempContact);
            tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
            retval = QString(tempQColor.name());
            break;

        case BlockedContactsModel::AvatarInitialRole:
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
            qDebug() << "BlockedContactsModel::data switch reached default";
            break;
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    dc_contact_unref(tempContact);

    return retval;
}


void BlockedContactsModel::updateContext(dc_context_t* cContext)
{
    beginResetModel();
    m_context = cContext;
    if (m_contactsArray) {
        dc_array_unref(m_contactsArray);
    }
    m_contactsArray = dc_get_blocked_contacts(m_context);
    endResetModel();

    emit blockedContactsCountChanged();
}


void BlockedContactsModel::unblockContact(int myindex)
{
    uint32_t contactID = contactID = dc_array_get_id(m_contactsArray, myindex);
    dc_block_contact(m_context, contactID, 0);

    beginResetModel();
    if (m_contactsArray) {
        dc_array_unref(m_contactsArray);
    }
    m_contactsArray = dc_get_blocked_contacts(m_context);
    emit blockedContactsCountChanged();
    endResetModel();

    // TODO: if no more blocked contacts left, go back to the chatlist?
}


int BlockedContactsModel::blockedContactsCount()
{
    if (m_contactsArray) {
        return dc_array_get_cnt(m_contactsArray);
    } else {
        return 0;
    }
}
