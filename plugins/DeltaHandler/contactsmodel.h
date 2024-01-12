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

#ifndef CONTACTSMODEL_H
#define CONTACTSMODEL_H

#include <QtCore>
#include <QtGui>
#include <vector>
//#include <string>
#include "deltahandler.h"
#include "deltachat.h"

class DeltaHandler;

class ContactsModel : public QAbstractListModel {
    Q_OBJECT

signals:
    void chatCreationSuccess(uint32_t chatID);
    void queryDone();
    void addContactToGroup(uint32_t contactID);

public:
    explicit ContactsModel(QObject *parent = 0);
    ~ContactsModel();

    // IsAlreadyMemberOfGroupRole and IsToBeAddedToGroupRole
    // are used in the page to add contacts to a group chat
    enum { DisplayNameRole, ProfilePicRole, EmailAddressRole, AvatarColorRole, AvatarInitialRole, IsAlreadyMemberOfGroupRole, IsToBeAddedToGroupRole, IsVerifiedRole};

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

    Q_INVOKABLE void setVerifiedOnly(bool verifOnly);

    void updateContext(dc_context_t* cContext);

    // used for the page to add contacts to a group
    void setMembersAlreadyInGroup(const std::vector<uint32_t> &alreadyIn);
    void resetNewMemberList();

public slots:
    void updateQuery(QString query);

    // Used in the page to add members to a group
    void startChatWithIndex(int myindex);
    void addIndexToMemberlist(int myindex);
    void removeIndexFromMemberlist(int myindex);
    void finalizeMemberChanges(bool actionRequested);

    void updateContacts();


protected:
    QHash<int, QByteArray> roleNames() const;

private:
    dc_context_t* m_context;

    std::vector<uint32_t> m_contactsVector;

    // Used to add a custom entry into the beginning of
    // the list. Will be 0 by default and 1 if m_contactsArray
    // is generated with a query string, in which case
    // a custom entry will be generated based on the
    // query string. Is set by updateQuery(QString) and
    // used in data(const QModelIndex, int) and rowCount(QModelIndex).
    int m_offset;

    bool m_verifiedOnly;

    QString m_query;

    // used in the page to add contacts to a group
    // stores the contactIDs of members that are already in the group
    std::vector<uint32_t> m_membersAlreadyInGroup;
    // stores the additionally selected members
    std::vector<uint32_t> m_newMembers;
};

#endif // CONTACTSMODEL_H
