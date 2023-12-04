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

#ifndef ACCOUNTSMODEL_H
#define ACCOUNTSMODEL_H

#include <QtCore>
#include <QtGui>
//#include <string>
#include "deltahandler.h"
#include "deltachat.h"

class DeltaHandler;

class AccountsModel : public QAbstractListModel {
    Q_OBJECT

public:
    explicit AccountsModel(QObject *parent = 0);
    ~AccountsModel();

    // IsClosedRole is for checking whether the account is an encrypted one. It
    // doesn't say whether the account has already been opened or not.
    enum { AddrRole, IsConfiguredRole, ProfilePicRole, UsernameRole, IsClosedRole, FreshMsgCountRole };

    // TODO: reference to DeltaHandler really needed?
    void configure(dc_accounts_t* accMngr, DeltaHandler* dHandler);

    Q_INVOKABLE void configureAccount(int myindex);

    Q_INVOKABLE QString getAddressOfIndex(int myindex);

    Q_INVOKABLE int deleteAccount(int myindex);

    Q_INVOKABLE int getIdOfAccount(int myindex);

    Q_INVOKABLE QString getInfoOfAccount(int myindex);

    Q_INVOKABLE QString getLastErrorOfAccount(int myindex);
    
    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

signals:
    void deletedAccount(uint32_t accID);

public slots:
    void reset();
    void updateFreshMsgCount(uint32_t accID, int unused1, int unused2);

protected:
    QHash<int, QByteArray> roleNames() const;

private slots:
    void newAccount();
    void updatedAccount(uint32_t);

private:
    dc_accounts_t* m_accountsManager;
    dc_array_t* m_accountsArray;
    DeltaHandler* m_deltaHandler;
};

#endif // ACCOUNTSMODEL_H
