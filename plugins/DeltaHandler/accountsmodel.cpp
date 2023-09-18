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

#include "accountsmodel.h"
//#include <unistd.h> // for sleep

AccountsModel::AccountsModel(QObject* parent)
    : QAbstractListModel(parent), m_accountsManager {nullptr}, m_accountsArray {nullptr} { 
};

AccountsModel::~AccountsModel()
{
    if (m_accountsArray) {
        dc_array_unref(m_accountsArray);
    }
}


int AccountsModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    if (m_accountsArray) {
        return dc_array_get_cnt(m_accountsArray);
    } else {
        return 0;
    }
}

QHash<int, QByteArray> AccountsModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[AddrRole] = "address";
    roles[IsConfiguredRole] = "isConfigured";
    roles[ProfilePicRole] = "profilePic";
    roles[UsernameRole] = "username";
    // IsClosedRole is for checking whether the account is an encrypted
    // one. It doesn't say whether the account has already been opened
    // or not.
    roles[IsClosedRole] = "isClosed";

    return roles;
}

QVariant AccountsModel::data(const QModelIndex &index, int role) const
{
    if (!m_accountsArray) {
        return QVariant();
    }

    int row = index.row();

    if(row < 0 || row >= dc_array_get_cnt(m_accountsArray)) {
        return QVariant();
    }

    uint32_t accID = dc_array_get_id(m_accountsArray, row);
    dc_context_t* tempContext = dc_accounts_get_account(m_accountsManager, accID);

    if (0 == dc_context_is_open(tempContext)) {
        qDebug() << "AccountsModel::data(): ERROR: Context of account with ID " << accID << " is closed, cannot obtain data";
    }
    
    QVariant retval;
    QString tempQString;
    bool tempBool;
    char* tempText {nullptr};

    switch(role) {
        case AccountsModel::AddrRole:
            tempText = dc_get_config(tempContext, "addr");
            if (tempText) {
                tempQString = tempText;
                if (tempQString == "") {
                    tempQString = "Unconfigured";
                    tempQString.append(QString::number(accID));
                }
            }
            else {
                tempQString = "Unconfigured";
                tempQString.append(QString::number(accID));
            }
            retval = tempQString;
            break;

        case AccountsModel::IsConfiguredRole:
            tempBool = dc_is_configured(tempContext);
            retval = tempBool;
            break;

        case AccountsModel::ProfilePicRole:
            tempText = dc_get_config(tempContext, "selfavatar");
            tempQString = tempText;
            if (tempQString.length() > QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length()) {
                tempQString.remove(0, QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation).length());
            }
            else {
                tempQString = "";
            }
            retval = tempQString;
            break;

        case AccountsModel::UsernameRole:
            tempText = dc_get_config(tempContext, "displayname");
            tempQString = tempText;
            retval = tempQString;
            break;

        case AccountsModel::IsClosedRole:
            tempBool = m_deltaHandler->isClosedAccount(accID);
            retval = tempBool;
            break;

        default:
            retval = QVariant();
            qDebug() << "AccountsModel::data switch reached default";
            break;
    }

    if (tempText) {
        dc_str_unref(tempText);
    }

    if (tempContext) {
        dc_context_unref(tempContext);
    }

    return retval;
}


void AccountsModel::configure(dc_accounts_t* accMngr, DeltaHandler* dHandler)
{
    beginResetModel();

    m_accountsManager = accMngr;

    if (m_accountsArray) {
        dc_array_unref(m_accountsArray);
    }
    m_accountsArray = dc_accounts_get_all(m_accountsManager);

    endResetModel();

    m_deltaHandler = dHandler;

    // disconnect in case configure() is not called for the first time. Otherwise, multiple
    // connections would be created.
    disconnect(m_deltaHandler, SIGNAL(newUnconfiguredAccount()), this, SLOT(newAccount()));
    disconnect(m_deltaHandler, SIGNAL(newConfiguredAccount()), this, SLOT(newAccount()));
    disconnect(m_deltaHandler, SIGNAL(updatedAccountConfig(uint32_t)), this, SLOT(updatedAccount(uint32_t)));

    bool connectSuccess = connect(m_deltaHandler, SIGNAL(newUnconfiguredAccount()), this, SLOT(newAccount()));
    if (!connectSuccess) {
        qDebug() << "Chatmodel::configure: Could not connect signal newUnconfiguredAccount to slot newAccount";
    }

    connectSuccess = connect(m_deltaHandler, SIGNAL(newConfiguredAccount()), this, SLOT(newAccount()));
    if (!connectSuccess) {
        qDebug() << "Chatmodel::configure: Could not connect signal newConfiguredAccount to slot newAccount";
    }

    connectSuccess = connect(m_deltaHandler, SIGNAL(updatedAccountConfig(uint32_t)), this, SLOT(updatedAccount(uint32_t)));
    if (!connectSuccess) {
        qDebug() << "Chatmodel::configure: Could not connect signal updatedAccountConfig to slot updatedAccount";
    }
}


void AccountsModel::newAccount()
{
    // reset the model instead of inserting a row in case
    // the core inserts the new account in between existing
    // accounts
    reset();
}


void AccountsModel::reset()
{
    beginResetModel();
    if (m_accountsArray) {
        dc_array_unref(m_accountsArray);
        m_accountsArray = nullptr;
    }

    if (m_accountsManager) {
        m_accountsArray = dc_accounts_get_all(m_accountsManager);
    }
    endResetModel();
}


void AccountsModel::configureAccount(int myindex)
{
    uint32_t accID = dc_array_get_id(m_accountsArray, myindex);
    m_deltaHandler->setTempContext(accID);
}


QString AccountsModel::getAddressOfIndex(int myindex)
{

    QString tempQString;

    uint32_t accID = dc_array_get_id(m_accountsArray, myindex);
    dc_context_t* tempContext = dc_accounts_get_account(m_accountsManager, accID);
    char* tempText = dc_get_config(tempContext, "addr");

    if (tempText) {
        tempQString = tempText;
        if (tempQString == "") {
            tempQString = "Unconfigured";
            tempQString.append(QString::number(accID));
        }
    }
    else {
        tempQString = "Unconfigured";
        tempQString.append(QString::number(accID));
    }

    dc_context_unref(tempContext);
    dc_str_unref(tempText);

    return tempQString;
}


int AccountsModel::getIdOfAccount(int myindex)
{
    return dc_array_get_id(m_accountsArray, myindex);
}


QString AccountsModel::getInfoOfAccount(int myindex)
{
    QString tempQString;

    uint32_t accID = dc_array_get_id(m_accountsArray, myindex);
    dc_context_t* tempContext = dc_accounts_get_account(m_accountsManager, accID);
    char* tempText = dc_get_info(tempContext);

    if (tempText) {
        tempQString = tempText;
    }
    else {
        tempQString = "None";
    }

    dc_context_unref(tempContext);
    dc_str_unref(tempText);

    return tempQString;
}


QString AccountsModel::getLastErrorOfAccount(int myindex)
{
    QString tempQString;

    uint32_t accID = dc_array_get_id(m_accountsArray, myindex);
    dc_context_t* tempContext = dc_accounts_get_account(m_accountsManager, accID);
    char* tempText = dc_get_last_error(tempContext);

    if (tempText) {
        tempQString = tempText;
    }
    else {
        tempQString = "";
    }

    dc_context_unref(tempContext);
    dc_str_unref(tempText);

    return tempQString;

}


int AccountsModel::deleteAccount(int myindex)
{
    // check whether the account to be removed is the selected one
    // if yes, select other account
    uint32_t accID = dc_array_get_id(m_accountsArray, myindex);

    dc_context_t* tempContext = dc_accounts_get_selected_account(m_accountsManager);
    if (dc_get_id(tempContext) == accID) {
        m_deltaHandler->unselectAccount(accID);
    }

    dc_context_unref(tempContext);
    
    // use beginResetModel instead of beginRemoveRows because the account
    // removal might fail
    //beginRemoveRows(QModelIndex(), myindex, myindex);
    beginResetModel();

    qDebug() << "AccountsModel::deleteAccount: Deleting account with ID " << accID << "...";
    int success = dc_accounts_remove_account(m_accountsManager, accID);

    if(success) {
        emit deletedAccount(accID);
        qDebug() << "AccountsModel::deleteAccount: ...done.";
        dc_array_unref(m_accountsArray);
        m_accountsArray = dc_accounts_get_all(m_accountsManager);
    }
    else {
        qDebug() << "AccountsModel::deleteAccount: ...Error: Deleting account did not work.";
    }

    //endRemoveRows();
    endResetModel();

    return success;
}


void AccountsModel::updatedAccount(uint32_t accID)
{
    size_t tempIndex {0};
    bool foundAccID {false};

    for (tempIndex = 0; tempIndex < rowCount(QModelIndex()); ++tempIndex) {
        if (dc_array_get_id(m_accountsArray, tempIndex) == accID) {
            foundAccID = true;
            break;
        }
    }

    if (foundAccID) {
       dataChanged(index(tempIndex, 0), index(tempIndex, 0)); 
    }
    else {
        qDebug() << "AccountsModel::updatedAccount: ERROR: Did not find the account ID.";
    }
}
