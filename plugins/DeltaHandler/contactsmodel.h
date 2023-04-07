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
//#include <string>
#include "deltahandler.h"
#include "deltachat.h"

class DeltaHandler;

class ContactsModel : public QAbstractListModel {
    Q_OBJECT

signals:
    void chatCreationSuccess(uint32_t chatID);

public:
    explicit ContactsModel(QObject *parent = 0);
    ~ContactsModel();

    enum { DisplayNameRole, ProfilePicRole, EmailAddressRole, AvatarColorRole, AvatarInitialRole};

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

    void updateContext(dc_context_t* cContext);

public slots:
    void updateQuery(QString query);
    void selectIndex(int myindex);

protected:
    QHash<int, QByteArray> roleNames() const;

private:
    dc_context_t* m_context;
    dc_array_t* m_contactsArray;

    // Used to add a custom entry into the beginning of
    // the list. Will be 0 by default and 1 if m_contactsArray
    // is generated with a query string, in which case
    // a custom entry will be generated based on the
    // query string. Is set by updateQuery(QString) and
    // used in data(const QModelIndex, int) and rowCount(QModelIndex).
    int m_offset;

    QString m_query;
};

#endif // CONTACTSMODEL_H
