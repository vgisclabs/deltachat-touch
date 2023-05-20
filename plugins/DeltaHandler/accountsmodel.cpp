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
    return dc_array_get_cnt(m_accountsArray);
}

QHash<int, QByteArray> AccountsModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[AddrRole] = "address";
    roles[IsConfiguredRole] = "isConfigured";
    roles[ProfilePicRole] = "profilePic";
    roles[UsernameRole] = "username";

    return roles;
}

QVariant AccountsModel::data(const QModelIndex &index, int role) const
{
    int row = index.row();

    if(row < 0 || row >= dc_array_get_cnt(m_accountsArray)) {
        return QVariant();
    }

    uint32_t accID = dc_array_get_id(m_accountsArray, row);
    dc_context_t* tempContext = dc_accounts_get_account(m_accountsManager, accID);
    
    QVariant retval;
    // TODO: If a char* is assigned to a QVariant, does this automatically
    // make a QString? If yes, the QString below is not needed.
    QString tempQString;
    bool isConfigured;
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
            isConfigured = dc_is_configured(tempContext);
            retval = isConfigured;
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

    m_accountsManager = accMngr;
    m_accountsArray = dc_accounts_get_all(m_accountsManager);
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
    int tempCount = dc_array_get_cnt(m_accountsArray);
    beginInsertRows(QModelIndex(), tempCount, tempCount);
    dc_array_unref(m_accountsArray);
    m_accountsArray = dc_accounts_get_all(m_accountsManager);
    endInsertRows();
    
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
    
    beginRemoveRows(QModelIndex(), myindex, myindex);

    qDebug() << "AccountsModel::deleteAccount: Deleting account with ID " << accID << "...";
    int success = dc_accounts_remove_account(m_accountsManager, accID);

    if(success) {
        qDebug() << "AccountsModel::deleteAccount: ...done.";
        dc_array_unref(m_accountsArray);
        m_accountsArray = dc_accounts_get_all(m_accountsManager);
    }
    else {
        qDebug() << "AccountsModel::deleteAccount: ...Error: Deleting account did not work.";
    }

    endRemoveRows();

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
