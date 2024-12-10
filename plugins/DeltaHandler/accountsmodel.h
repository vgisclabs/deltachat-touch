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
#include "../deltachat.h"

#include <vector>

// Used in m_chatRequests to store the account ID
// along with the number of chat (contact) requests
// for this account
struct AccAndContactRequestList {
    uint32_t accID;
    std::vector<uint32_t> contactRequestChatIDs;
};

class DeltaHandler;

class AccountsModel : public QAbstractListModel {
    Q_OBJECT

public:
    explicit AccountsModel(QObject *parent = 0);
    ~AccountsModel();

    // IsClosedRole is for checking whether the account is an encrypted one. It
    // doesn't say whether the account has already been opened or not.
    enum { AddrRole, IsConfiguredRole, IsMutedRole, ProfilePicRole, UsernameRole, IsClosedRole, IsCurrentActiveRole, FreshMsgCountRole, ChatRequestCountRole, ColorRole };

    // TODO: reference to DeltaHandler really needed?
    void configure(dc_accounts_t* accMngr, DeltaHandler* dHandler);

    Q_INVOKABLE void configureAccount(int myindex);

    Q_INVOKABLE QString getAddressOfIndex(int myindex);

    Q_INVOKABLE int deleteAccount(int myindex);

    Q_INVOKABLE int getIdOfAccount(int myindex);

    Q_INVOKABLE QString getInfoOfAccount(int myindex);

    Q_INVOKABLE QString getLastErrorOfAccount(int myindex);

    Q_INVOKABLE int noOfChatRequestsInInactiveAccounts();

    Q_INVOKABLE int noOfFreshMsgsInInactiveAccounts();
    
    bool accountIsMuted(uint32_t accID);

    Q_INVOKABLE void muteUnmuteAccountById(uint32_t accID);

    // QAbstractListModel interface
    virtual int rowCount(const QModelIndex &parent) const;
    virtual QVariant data(const QModelIndex &index, int role) const;

signals:
    void deletedAccount(uint32_t accID);
    void inactiveFreshMsgsMayHaveChanged();

public slots:
    void reset();
    void notifyViewForAccount(uint32_t accID);
    void updateFreshMsgCountAndContactRequests(const std::vector<uint32_t> &accountsToRefresh);
    void removeChatIdFromContactRequestList(uint32_t accID, uint32_t chatID);

protected:
    QHash<int, QByteArray> roleNames() const;

private slots:
    void newAccount();
    void updatedAccount(uint32_t);

private:
    dc_accounts_t* m_accountsManager;
    dc_array_t* m_accountsArray;
    DeltaHandler* m_deltaHandler;
    std::vector<AccAndContactRequestList> m_chatRequests;

    /* Private methods */

    // Generates the entry in m_chatRequests for the passed
    // account ID. If an entry for this account is already
    // present in m_chatRequests, it is replaced.
    void generateOrRefreshChatRequestEntries(uint32_t accID);

    int getNumberOfFreshMsgs(uint32_t tempAccID) const;

    bool accountIsConfigured(uint32_t tempAccID) const;
};

#endif // ACCOUNTSMODEL_H
