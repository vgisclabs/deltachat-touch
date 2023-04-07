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

#include "contactsmodel.h"
//#include <unistd.h> // for sleep

ContactsModel::ContactsModel(QObject* parent)
    : QAbstractListModel(parent), m_context {nullptr}, m_contactsArray {nullptr}, m_offset {0}, m_query {""} { 
};

ContactsModel::~ContactsModel()
{
    if (m_contactsArray) {
        dc_array_unref(m_contactsArray);
    }
}


int ContactsModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return dc_array_get_cnt(m_contactsArray) + m_offset;
}

QHash<int, QByteArray> ContactsModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[DisplayNameRole] = "displayname";
    roles[ProfilePicRole] = "profilePic";
    roles[EmailAddressRole] = "address";
    roles[AvatarColorRole] = "avatarColor";
    roles[AvatarInitialRole] = "avatarInitial";

    return roles;
}

QVariant ContactsModel::data(const QModelIndex &index, int role) const
{
    int row = index.row();
    
    if(row < 0 || row >= dc_array_get_cnt(m_contactsArray) + m_offset) {
        return QVariant();
    }

    // Variables to be used both for the custom entry as well as the
    // standard ones.
    QVariant retval;
    QString tempQString;
    QColor tempQColor;

    /* ==============================================================
     * Data for custom entry at pos 0 that reflects the entered query
     * =============================================================*/

    if (1 == m_offset && 0 == row) {

        bool isEmailAddress;

        switch(role) {
            case ContactsModel::DisplayNameRole:
                // TODO: this will currently not appear in the po file
                tempQString = tr("New Contact");
                retval = tempQString;
                break;

            case ContactsModel::ProfilePicRole:
                tempQString = "replace_by_addNew";
                retval = tempQString;
                break;

            case ContactsModel::EmailAddressRole:
                isEmailAddress  = dc_may_be_valid_addr(m_query.toStdString().c_str());
                if (isEmailAddress) {
                    retval = m_query;
                } else {
                    // TODO: this will currently not appear in the po file
                    tempQString = tr("Type e-mail address above");
                    retval = tempQString;
                }
                break;

            case ContactsModel::AvatarColorRole:
                tempQColor = QColor(0, 0, 0, 0);
                retval = QString(tempQColor.name());
                break;

            case ContactsModel::AvatarInitialRole:
                tempQString = "";
                retval = tempQString;
                break;

            default:
                retval = QVariant();
                qDebug() << "ContactsModel::data switch reached default";
                break;
        }
        return retval;
    }
    /* =============== End of Data for custom entry ===============*/


    // Variables only to be used for the standard entries.
    char* tempText {nullptr};
    uint32_t tempColor {0};

    uint32_t tempContactID = dc_array_get_id(m_contactsArray, row - m_offset);
    dc_contact_t* tempContact = dc_get_contact(m_context, tempContactID);

    switch(role) {
        case ContactsModel::DisplayNameRole:
            tempText = dc_contact_get_display_name(tempContact);
            tempQString = tempText;
            retval = tempQString;
            break;

        case ContactsModel::ProfilePicRole:
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

        case ContactsModel::EmailAddressRole:
            tempText = dc_contact_get_addr(tempContact);
            tempQString = tempText;
            retval = tempQString;
            break;

        case ContactsModel::AvatarColorRole:
            tempColor = dc_contact_get_color(tempContact);
            tempQColor = QColor((tempColor >> 16) % 256, (tempColor >> 8) % 256, tempColor % 256, 0);
            retval = QString(tempQColor.name());
            break;

        case ContactsModel::AvatarInitialRole:
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
            qDebug() << "ContactsModel::data switch reached default";
            break;
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    dc_contact_unref(tempContact);

    return retval;
}


void ContactsModel::updateContext(dc_context_t* cContext)
{
    beginResetModel();
    if (m_contactsArray) {
        dc_array_unref(m_contactsArray);
    }

    m_context = cContext;
    m_contactsArray = dc_get_contacts(m_context, 0, NULL);
    endResetModel();
}


void ContactsModel::updateQuery(QString query) {
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
    dc_array_unref(m_contactsArray);
    
    const char* query_cstring {nullptr};
    if (query != "") {
        query_cstring = query.toStdString().c_str();
        m_offset = 1;
    } else {
        m_offset = 0;
    }
    
    m_contactsArray = dc_get_contacts(m_context, 0, query_cstring);

    endResetModel();
}


void ContactsModel::selectIndex(int myindex)
{
    uint32_t contactID {0};

    // Taking care of the custom entry by the user
    if (1 == m_offset && 0 == myindex) {
        if (dc_may_be_valid_addr(m_query.toStdString().c_str())) {
            contactID = dc_create_contact(m_context, NULL, m_query.toStdString().c_str());
        } else {
            // if the entry is not a valid email address, we
            // just do nothing when the user clicks the corresponding
            // list entry. TODO: display error message
            return;
        }
    } else {
        contactID = dc_array_get_id(m_contactsArray, myindex - m_offset);
    }

    uint32_t chatID = dc_create_chat_by_contact_id(m_context, contactID);
    
    if (0 != chatID) {
        emit chatCreationSuccess(chatID);
    } else {
        // TODO error: chat could not be created
    }
}
