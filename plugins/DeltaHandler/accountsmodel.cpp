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
    : QAbstractListModel(parent), m_accountsManager {nullptr}, m_accountsArray {nullptr}
{
}


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
    roles[IsMutedRole] = "isMuted";
    roles[ProfilePicRole] = "profilePic";
    roles[UsernameRole] = "username";
    roles[FreshMsgCountRole] = "freshMsgCount";
    roles[ChatRequestCountRole] = "chatRequestCount";
    // IsClosedRole is for checking whether the account is an encrypted
    // one. It doesn't say whether the account has already been opened
    // or not.
    roles[IsClosedRole] = "isClosed";
    roles[IsCurrentActiveRole] = "isCurrentActiveAccount";
    roles[ColorRole] = "color";

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
    size_t i;

    // for jsonrpc
    QString paramString;
    QString requestString;
    QByteArray jsonResponseByteArray;
    QJsonObject jsonObj;

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

        case AccountsModel::IsMutedRole:
            tempText = dc_get_config(tempContext, "ui.desktop.muted");
            tempQString = tempText;
            if (tempQString == "1") {
                retval = true;
            } else {
                retval = false;
            }
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

        case AccountsModel::IsCurrentActiveRole:
            if (m_deltaHandler->getCurrentAccountId() == accID) {
                retval = true;
            } else {
                retval = false;
            }
            break;

        case AccountsModel::ColorRole:
            // looks like the color of an account can only be obtained via jsonrpc
            paramString.setNum(accID);

            requestString = m_deltaHandler->constructJsonrpcRequestString("get_account_info", paramString);
            jsonResponseByteArray = m_deltaHandler->sendJsonrpcBlockingCall(requestString).toLocal8Bit();

            jsonObj = QJsonDocument::fromJson(jsonResponseByteArray).object();

            jsonObj = jsonObj.value("result").toObject();
            if (jsonObj.value("kind").toString() == "Configured") {
                retval = jsonObj.value("color").toString();
            } else {
                retval = "#000000";
            }
            break;

        case AccountsModel::FreshMsgCountRole:
            if (dc_is_configured(tempContext)) {
                retval = getNumberOfFreshMsgs(accID);
            } else {
                retval = 0;
            }
            break;

        case AccountsModel::ChatRequestCountRole:
            retval = 0;
            if (dc_is_configured(tempContext)) {
                for (i = 0; i < m_chatRequests.size(); ++i) {
                    if (m_chatRequests[i].accID == accID) {
                        retval = static_cast<int>(m_chatRequests[i].contactRequestChatIDs.size());
                        break;
                    }
                }
            }
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
    m_deltaHandler = dHandler;

    beginResetModel();

    m_accountsManager = accMngr;

    if (m_accountsArray) {
        dc_array_unref(m_accountsArray);
    }
    m_accountsArray = dc_accounts_get_all(m_accountsManager);

    {
        // build up m_chatRequests
        m_chatRequests.resize(0);

        // Check for chat requests in the chatlist entries for each
        // account.
        if (m_accountsArray) {
            // call generateOrRefreshChatRequestEntries for each account
            for (size_t i = 0; i < dc_array_get_cnt(m_accountsArray); ++i) {
                uint32_t tempAccID = dc_array_get_id(m_accountsArray, i);
                generateOrRefreshChatRequestEntries(tempAccID);
            }
        }
    }

    endResetModel();

    // disconnect in case configure() is not called for the first time. Otherwise, multiple
    // connections would be created.
    disconnect(m_deltaHandler, SIGNAL(newUnconfiguredAccount()), this, SLOT(newAccount()));
    disconnect(m_deltaHandler, SIGNAL(newConfiguredAccount()), this, SLOT(newAccount()));
    disconnect(m_deltaHandler, SIGNAL(accountIsConfiguredChanged(uint32_t)), this, SLOT(updatedAccount(uint32_t)));
    disconnect(m_deltaHandler, SIGNAL(accountChanged()), this, SLOT(reset()));

    bool connectSuccess = connect(m_deltaHandler, SIGNAL(newUnconfiguredAccount()), this, SLOT(newAccount()));
    if (!connectSuccess) {
        qDebug() << "AccountsModel::configure(): Could not connect signal newUnconfiguredAccount to slot newAccount";
    }

    connectSuccess = connect(m_deltaHandler, SIGNAL(newConfiguredAccount()), this, SLOT(newAccount()));
    if (!connectSuccess) {
        qDebug() << "AccountsModel::configure(): Could not connect signal newConfiguredAccount to slot newAccount";
    }

    connectSuccess = connect(m_deltaHandler, SIGNAL(accountIsConfiguredChanged(uint32_t)), this, SLOT(updatedAccount(uint32_t)));
    if (!connectSuccess) {
        qDebug() << "AccountsModel::configure(): Could not connect signal accountIsConfiguredChanged to slot updatedAccount";
    }

    connectSuccess = connect(m_deltaHandler, SIGNAL(accountChanged()), this, SLOT(reset()));
    if (!connectSuccess) {
        qDebug() << "AccountsModel::configure(): ERROR: Could not connect signal accountChanged of m_deltaHandler with slot reset";
    }  

    emit inactiveFreshMsgsMayHaveChanged();
}


void AccountsModel::newAccount()
{
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

    // recreate m_chatRequests
    if (m_accountsArray) {
        for (size_t i = 0; i < dc_array_get_cnt(m_accountsArray); ++i) {
            uint32_t tempAccID = dc_array_get_id(m_accountsArray, i);
            generateOrRefreshChatRequestEntries(tempAccID);
        }
    }

    endResetModel();

    emit inactiveFreshMsgsMayHaveChanged();
}


void AccountsModel::notifyViewForAccount(uint32_t accID)
{
    if (m_accountsArray) {
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
        } else {
            qDebug() << "AccountsModel::updateFreshMsgCount: ERROR: Did not find the account ID.";
        }
    }
}


// Parameter passed by reference, the queue will be empty after calling this method!
void AccountsModel::updateFreshMsgCountAndContactRequests(const std::vector<uint32_t>& accountsToRefresh)
{
    for (size_t i = 0; i < accountsToRefresh.size(); ++i) {
        uint32_t accID = accountsToRefresh[i];
        generateOrRefreshChatRequestEntries(accID);

        // notify the view that the model has changed for this accID
        notifyViewForAccount(accID);
    }
    
    emit inactiveFreshMsgsMayHaveChanged();
}


// Removes the chat ID from the list of contact requests for this accID.
void AccountsModel::removeChatIdFromContactRequestList(uint32_t accID, uint32_t chatID)
{
    // find the account
    for (size_t i = 0; i < m_chatRequests.size(); ++i) {
        if (m_chatRequests[i].accID == accID) {

            // find the chat ID and remove the chat from the vector
            std::vector<uint32_t>::iterator it;
            for (it = m_chatRequests[i].contactRequestChatIDs.begin(); it != m_chatRequests[i].contactRequestChatIDs.end(); ++it) {
                if (*it == chatID) {
                    m_chatRequests[i].contactRequestChatIDs.erase(it);
                    // TODO: remove the complete entry from m_chatRequests if contactRequestChatIDs is empty?
                    break;
                }
            }
            break;
        }
    }

    // notify the view that the model has changed
    if (m_accountsArray) {
        for (size_t i = 0; i < dc_array_get_cnt(m_accountsArray); ++i) {
            if (accID == dc_array_get_id(m_accountsArray, i)) {
                dataChanged(index(i, 0), index(i, 0)); 
                break;
            }
        }
    }

    emit inactiveFreshMsgsMayHaveChanged();
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


int AccountsModel::noOfChatRequestsInInactiveAccounts()
{
    int retval {0};
    uint32_t currentAccID = m_deltaHandler->getCurrentAccountId();

    for (size_t i = 0; i < m_chatRequests.size(); ++i) {
        uint32_t tempAccId = m_chatRequests[i].accID;
        if (tempAccId != currentAccID && !accountIsMuted(tempAccId)) {
            retval += static_cast<int>(m_chatRequests[i].contactRequestChatIDs.size());
        }
    }

    return retval;
}


int AccountsModel::noOfFreshMsgsInInactiveAccounts()
{
    int retval {0};
    uint32_t currentAccID = m_deltaHandler->getCurrentAccountId();

    for (size_t i = 0; i < dc_array_get_cnt(m_accountsArray); ++i) {
        uint32_t tempAccID = dc_array_get_id(m_accountsArray, i);
        if (tempAccID != currentAccID && !accountIsMuted(tempAccID) && accountIsConfigured(tempAccID)) {
            retval += getNumberOfFreshMsgs(tempAccID);
        }
    }

    return retval;
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

    emit inactiveFreshMsgsMayHaveChanged();

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


void AccountsModel::generateOrRefreshChatRequestEntries(uint32_t accID)
{
    // remove the old entry
    std::vector<AccAndContactRequestList>::iterator it;
    for (it = m_chatRequests.begin(); it != m_chatRequests.end(); ++it) {
        if (it->accID == accID) {
            m_chatRequests.erase(it);
            break;
        }
    }

    // create the entry
    std::vector<uint32_t> tempContactRequList;

    // check if the account is configured; if not, add empty vector for this account
    if (!accountIsConfigured(accID)) {
        m_chatRequests.push_back({accID, tempContactRequList});
        return;
    }

    QString paramString = "";

    // First get the chatlist entries as array of numbers by using the Jsonrpc call
    // get_chatlist_entries(accountId: number, listFlags: null | number, queryString: null | string, queryContactId: null | number)
    QString tempString;
    tempString.setNum(accID);
    paramString.append(tempString);
    paramString.append(", null, null, null");

    // create a request string and send it as blocking Jsonrpc call
    QString requestString = m_deltaHandler->constructJsonrpcRequestString("get_chatlist_entries", paramString);
    QByteArray jsonResponseByteArray = m_deltaHandler->sendJsonrpcBlockingCall(requestString).toLocal8Bit();

    // the actual object with the chat IDs is an array nested in the
    // received json like this:
    // { .....,,\"result\":[22,12,13,38,10,37]}
    // so we extract it
    QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonResponseByteArray);
    QJsonObject jsonObj = jsonDoc.object();
    // value() returns a QJsonValue of type array, which we 
    // transform to an QJsonArray
    QJsonArray jsonArray = jsonObj.value("result").toArray();
    
    // With the array containing chat IDs, retrieve
    // the actual chatlist items by using the Jsonrpc call
    // get_chalist_items_by_entries(accountId: number, entries: number[])
    paramString = "";
    // tempString still contains the account ID
    paramString.append(tempString);
    paramString.append(", ");
    // convert jsonArray to a QByteArray via an unnamed QJsonDocument
    paramString.append(QJsonDocument(jsonArray).toJson());

    requestString = m_deltaHandler->constructJsonrpcRequestString("get_chatlist_items_by_entries", paramString);
    jsonResponseByteArray = m_deltaHandler->sendJsonrpcBlockingCall(requestString).toLocal8Bit();

    // jsonResponseByteArray now has a huge JSON with chatlist entries for each chat ID.
    // The actual object with the chatlist entry is nested in the received json like this:
    // { .....,"result":{"<chatID>":{ <this is the actual entry per chat ID> }}}
    jsonDoc = QJsonDocument::fromJson(jsonResponseByteArray);
    jsonObj = jsonDoc.object();
    QJsonObject jsonResultObj = jsonObj.value("result").toObject();

    // Go through all chats by looping through the array with chat IDs.
    // Add each chat that is a contact request to tempContactRequList.

    std::vector<int> listOfChatIDs;
    QVariantList tempVariantList = jsonArray.toVariantList();
    // Copying the entries of jsonArray to a vector first
    // because when looping through jsonArray directly, there
    // was some strange error where it would crash mid-loop
    for (QVariant temp : tempVariantList) {
        listOfChatIDs.push_back(temp.toInt());
    }

    for (size_t i = 0; i < listOfChatIDs.size(); ++i) {
        int tempChatID = listOfChatIDs[i];

        tempString.setNum(tempChatID);
        jsonObj = jsonResultObj.value(tempString).toObject();

        // if it's a contact request, then add it to the vector
        QJsonValue tempValue = jsonObj.value("isContactRequest");
        if (tempValue != QJsonValue::Undefined) {
            if (tempValue.toBool()) {
                tempContactRequList.push_back(tempChatID);
            }
        }
    }

    // save the account ID along with the vector that contains
    // chat IDs which are contact requests
    m_chatRequests.push_back({accID, tempContactRequList});

    // Not needed here: Will be emitted at the end of each
    // block that calls generateOrRefreshChatRequestEntries
    //emit inactiveFreshMsgsMayHaveChanged();
}


int AccountsModel::getNumberOfFreshMsgs(uint32_t tempAccID) const
{
    QString tempString;
    tempString.setNum(tempAccID);
    QString paramString;
    paramString.append(tempString);

    // create a request string and send it as blocking Jsonrpc call
    QString requestString = m_deltaHandler->constructJsonrpcRequestString("get_fresh_msgs", paramString);
    QByteArray jsonResponseByteArray = m_deltaHandler->sendJsonrpcBlockingCall(requestString).toLocal8Bit();

    // the actual object with the IDs of the fresh msgs is an array nested in the
    // received json like this:
    // { .....,,\"result\":[125,204]}
    // so we extract it
    QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonResponseByteArray);
    QJsonObject jsonObj = jsonDoc.object();
    // value() returns a QJsonValue of type array, which we 
    // transform to an QJsonArray
    QJsonArray jsonArray = jsonObj.value("result").toArray();

    return jsonArray.size();
}


bool AccountsModel::accountIsMuted(uint32_t accID)
{
    dc_context_t* tempContext = dc_accounts_get_account(m_accountsManager, accID);

    if (!tempContext) {
        return false;
    }

    char* tempText = dc_get_config(tempContext, "ui.desktop.muted");
    QString tempQString = tempText;

    dc_context_unref(tempContext);
    dc_str_unref(tempText);

    if (tempQString == "1") {
        return true;
    } else {
        return false;
    }
}


void AccountsModel::muteUnmuteAccountById(uint32_t accID)
{
    dc_context_t* tempContext = dc_accounts_get_account(m_accountsManager, accID);

    if (!tempContext) {
        return;
    }

    char* tempText = dc_get_config(tempContext, "ui.desktop.muted");
    QString tempQString = tempText;

    dc_str_unref(tempText);

    if (tempQString == "1") {
        dc_set_config(tempContext, "ui.desktop.muted", "0");
    } else {
        dc_set_config(tempContext, "ui.desktop.muted", "1");
    }

    dc_context_unref(tempContext);


    // notify the view that the model has changed
    if (m_accountsArray) {
        for (size_t i = 0; i < dc_array_get_cnt(m_accountsArray); ++i) {
            if (accID == dc_array_get_id(m_accountsArray, i)) {
                dataChanged(index(i, 0), index(i, 0)); 
                break;
            }
        }
    }

    emit inactiveFreshMsgsMayHaveChanged();
}


bool AccountsModel::accountIsConfigured(uint32_t tempAccID) const
{
    dc_context_t* tempContext = dc_accounts_get_account(m_accountsManager, tempAccID);
    bool retval = dc_is_configured(tempContext);
    dc_context_unref(tempContext);
    return retval;
}
