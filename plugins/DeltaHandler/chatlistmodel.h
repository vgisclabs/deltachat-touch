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

#ifndef CHATLISTMODEL_H
#define CHATLISTMODEL_H

#include <QtCore>
#include <QtGui>
//#include <string>
#include "deltachat.h"

class ChatlistModel : public QAbstractListModel {
    Q_OBJECT

public:
    explicit ChatlistModel(QObject *parent = 0);
    ~ChatlistModel();

    enum { ChatnameRole, MsgPreviewRole, TimestampRole, ChatPicRole, AvatarColorRole, AvatarInitialRole };

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

    Q_INVOKABLE uint32_t getChatID(int myindex);

    void configure(dc_context_t* context, int flagsForChatlist);

public slots:
    void updateQuery(QString query);

protected:
    QHash<int, QByteArray> roleNames() const;

private:
    dc_context_t* currentContext;
    dc_chatlist_t* currentChatlist;
    int m_flagsForChatlist;
    QString m_query;
};
#endif // CHATLISTMODEL_H
