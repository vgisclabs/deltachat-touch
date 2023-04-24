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
    : QAbstractListModel(parent), m_context {nullptr}, m_contactsArray {nullptr}, m_offset {0}, m_query {""}
{ 
    m_newMembers.resize(0);
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
    roles[IsAlreadyMemberOfGroupRole] = "isAlreadyMemberOfGroup";
    roles[IsToBeAddedToGroupRole] = "isToBeAddedToGroup";

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

            case ContactsModel::IsAlreadyMemberOfGroupRole:
                retval = false;
                break;

            case ContactsModel::IsToBeAddedToGroupRole:
                retval = false;
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

        case ContactsModel::IsAlreadyMemberOfGroupRole:
            retval = false;
            for (size_t i = 0; i < m_membersAlreadyInGroup.size(); ++i) {
                if (tempContactID == m_membersAlreadyInGroup[i]) {
                    retval = true;
                }
            }
            break;

        case ContactsModel::IsToBeAddedToGroupRole:
            retval = false;
            for (size_t i = 0; i < m_newMembers.size(); ++i) {
                if (tempContactID == m_newMembers[i]) {
                    retval = true;
                }
            }
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


void ContactsModel::resetNewMemberList()
{
    m_newMembers.resize(0);
}

void ContactsModel::setMembersAlreadyInGroup(const std::vector<uint32_t> &alreadyIn)
{
    m_membersAlreadyInGroup.resize(alreadyIn.size());

    for (size_t i = 0; i < alreadyIn.size(); ++i) {
        m_membersAlreadyInGroup[i] = alreadyIn[i];
    }
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
    
    uint32_t tempContactID {0};
    dc_contact_t* tempContact {nullptr};
    char* tempText {nullptr};
    QString tempQString {""};

    if (query != "") {
        m_contactsArray = dc_get_contacts(m_context, 0, query.toUtf8().constData());
        m_offset = 1;

        // Check whether the entered string equals any of the email
        // addresses in the array. If yes, don't show the additional
        // line with a newly to be added contact (i.e., set m_offset
        // to 0)
        for (size_t i = 0; i < dc_array_get_cnt(m_contactsArray); ++i) {
            tempContactID = dc_array_get_id(m_contactsArray, i);
            tempContact = dc_get_contact(m_context, tempContactID);
            tempText = dc_contact_get_addr(tempContact);
            tempQString = tempText;

            if (tempQString == query) {
                m_offset = 0;
                break;
            }
        }
    } else { // query is empty string
        m_contactsArray = dc_get_contacts(m_context, 0, NULL);
        m_offset = 0;
    }

    if (tempContact) {
        dc_contact_unref(tempContact);
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    endResetModel();
}


void ContactsModel::startChatWithIndex(int myindex)
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


void ContactsModel::addIndexToMemberlist(int myindex)
{
    uint32_t tempContactID {0};

    if (1 == m_offset && 0 == myindex) {
        if (dc_may_be_valid_addr(m_query.toStdString().c_str())) {
            tempContactID = dc_lookup_contact_id_by_addr(m_context, m_query.toStdString().c_str());
            if (!tempContactID) {
                // TODO: Is a check needed whether tempContactID is in m_membersAlreadyInGroup? 
                tempContactID = dc_create_contact(m_context, NULL, m_query.toStdString().c_str());
                m_newMembers.push_back(tempContactID);

            } else {
                bool isAlreadyIn = false;
                for (size_t i = 0; i < m_membersAlreadyInGroup.size(); ++i) {
                    if (tempContactID == m_membersAlreadyInGroup[i]) {
                        isAlreadyIn = true;
                    }
                }

                if (!isAlreadyIn) {
                    m_newMembers.push_back(tempContactID);
                }
                // clear the query whether the address has already
                // been in the list of group members or not
            }

            emit queryDone();

        } else {
            // most likely no valid email address, do nothing
            // TODO: display error message?
        }
         
        return;
    }

    tempContactID = dc_array_get_id(m_contactsArray, myindex - m_offset);
    
    bool isAlreadyIn = false;
    for (size_t i = 0; i < m_newMembers.size(); ++i) {
        if (tempContactID == m_newMembers[i]) {
            isAlreadyIn = true;
        }
    }

    if (!isAlreadyIn) {
        m_newMembers.push_back(tempContactID);
        emit QAbstractListModel::dataChanged(index(myindex, 0), index(myindex, 0));
    }
}


void ContactsModel::removeIndexFromMemberlist(int myindex)
{

    uint32_t tempContactID = dc_array_get_id(m_contactsArray, myindex - m_offset);

    std::vector<uint32_t>::iterator it;
    bool isInList = false;

    for (it = m_newMembers.begin(); it != m_newMembers.end(); ++it) {
        if (tempContactID == *it) {
            isInList = true;
            m_newMembers.erase(it);
            break;
        }
    }

    if (isInList) {
        emit QAbstractListModel::dataChanged(index(myindex, 0), index(myindex, 0));
    }
}


void ContactsModel::finalizeMemberChanges(bool actionRequested)
{
    if (actionRequested) {
        for (size_t i = 0; i < m_newMembers.size(); ++i) {
            emit addContactToGroup(m_newMembers[i]);
        }
    }
    resetNewMemberList();
}
