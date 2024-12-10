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

#ifndef GROUPMEMBERMODEL_H
#define GROUPMEMBERMODEL_H

#include <QtCore>
#include <QtGui>
//#include <string>
#include <vector>
#include "../deltachat.h"

class GroupMemberModel : public QAbstractListModel {
    Q_OBJECT

signals:
    void groupMemberCountChanged(int mcount);

public:
    explicit GroupMemberModel(QObject *parent = 0);
    ~GroupMemberModel();

    enum { DisplayNameRole, ProfilePicRole, EmailAddressRole, AvatarColorRole, AvatarInitialRole, IsSelfRole, IsVerifiedRole};

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

    bool isMember(uint32_t contactID);

    Q_INVOKABLE void deleteMember(int myindex);

    Q_INVOKABLE QString getNameNAddrOfIndex(int myindex);

    Q_INVOKABLE int tempGroupMemberCount();

    std::vector<uint32_t> getMembersAlreadyInGroup();

    void setConfig(dc_context_t* tempContext, bool creationOfNewGroup, uint32_t tempChatID = 0);

    bool allContactsAreVerified();

public slots:
    void addMember(uint32_t contactID);

protected:
    QHash<int, QByteArray> roleNames() const;

private:
    dc_context_t* m_context;
    uint32_t m_chatID;
    std::vector<uint32_t> m_membervector;
    
};

#endif // GROUPMEMBERMODEL_H
