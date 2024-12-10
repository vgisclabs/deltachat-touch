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

#ifndef BLOCKEDCONTACTSMODEL_H
#define BLOCKEDCONTACTSMODEL_H

#include <QtCore>
#include <QtGui>
//#include <string>
#include "../deltachat.h"

class BlockedContactsModel : public QAbstractListModel {
    Q_OBJECT

public:
    explicit BlockedContactsModel(QObject *parent = 0);
    ~BlockedContactsModel();

    enum { DisplayNameRole, ProfilePicRole, EmailAddressRole, AvatarColorRole, AvatarInitialRole};

    Q_PROPERTY (int blockedContactsCount READ blockedContactsCount NOTIFY blockedContactsCountChanged);

    int blockedContactsCount();

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

    void updateContext(dc_context_t* cContext);

signals:
    void blockedContactsCountChanged();

public slots:
    void unblockContact(int myindex);

protected:
    QHash<int, QByteArray> roleNames() const;

private:
    dc_context_t* m_context;
    dc_array_t* m_contactsArray;
};

#endif // BLOCKEDCONTACTSMODEL_H
