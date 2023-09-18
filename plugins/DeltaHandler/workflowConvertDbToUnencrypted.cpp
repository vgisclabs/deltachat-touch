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

#include "workflowConvertDbToUnencrypted.h"

WorkflowDbToUnencrypted::WorkflowDbToUnencrypted(dc_accounts_t* dcaccs, EmitterThread* emthread, QSettings* settings, const std::vector<uint32_t>& closedAccs, QString passphrase)
{
    m_dcAccs = dcaccs;
    m_emitterthread = emthread;
    m_settings = settings;
    m_closedAccounts = closedAccs;
    m_passphrase = passphrase;

    m_tempContext = nullptr;
    
    m_cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
}


WorkflowDbToUnencrypted::~WorkflowDbToUnencrypted()
{
    disconnect(m_emitterthread, SIGNAL(imexProgress(int)), this, SLOT(imexProgressReceiver(int)));
    disconnect(m_emitterthread, SIGNAL(imexFileWritten(QString)), this, SLOT(imexFileReceiver(QString)));
}


void WorkflowDbToUnencrypted::startWorkflow()
{
    // Fill m_accountsToConvert with the currently
    // present account IDs...
    dc_array_t* tempArray = dc_accounts_get_all(m_dcAccs);
    for (size_t i = 0; i < dc_array_get_cnt(tempArray); ++i) {
        //... but only if it's an encrypted account
        if (accountIsClosed(dc_array_get_id(tempArray, i))) {
            m_accountsToConvert.push_back(dc_array_get_id(tempArray, i));
        }
    }
    dc_array_unref(tempArray);

    m_totalAccounts = m_accountsToConvert.size();

    if (0 == m_totalAccounts) {
        // No accounts in the account manager
        // TODO: how to communicate to the caller of this method?
        qDebug() << "WorkflowDbToUnencrypted::startWorkflow(): Warning: Method called but no accounts found";
        emit workflowCompleted();
        return;
    }

    // Write the start of the workflow to the settings, so if
    // it is interrupted (app crash or closed by user), it can be
    // resumed.
    m_settings->setValue("workflowDbToUnencryptedRunning", true);

    m_currentlyExportingEncryptedAccount = true;

    bool connectSuccess = connect(m_emitterthread, SIGNAL(imexProgress(int)), this, SLOT(imexProgressReceiver(int)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal imexProgress to slot imexBackupExportProgressReceiver";
        exit(1);
    }

    connectSuccess = connect(m_emitterthread, SIGNAL(imexFileWritten(QString)), this, SLOT(imexFileReceiver(QString)));
    if (!connectSuccess) {
        qDebug() << "DeltaHandler::DeltaHandler: Could not connect signal imexFileWritten to slot imexFileReceiver";
        exit(1);
    }

    // don't get the first, but the last account so we can just
    // pop it later on
    m_tempContext = dc_accounts_get_account(m_dcAccs, m_accountsToConvert.back());

    if (!m_tempContext) {
        qDebug() << "WorkflowDbToUnencrypted::startWorkflow(): Error: Could not get context of first account, aborting.";
        m_settings->setValue("workflowDbToUnencryptedRunning", false);
        // TODO: how to notify the caller of this method?
        return;
    }

    emit statusChanged(true, 1, m_totalAccounts);

    // All set, now start the first imex progress (the first backup
    // export), the subsequent ones will be started by the slot that
    // receives the imex events.
    // Export will be imported again into an open context by the slot.
    dc_imex(m_tempContext, DC_IMEX_EXPORT_BACKUP, m_cacheDir.toUtf8().constData(), m_passphrase.toUtf8().constData());
}


void WorkflowDbToUnencrypted::imexProgressReceiver(int imProg)
{
    emit imexEvent(imProg);

    if (imProg == 1000) {
        if (m_currentlyExportingEncryptedAccount) {
            // exporting finished, start importing
            m_currentlyExportingEncryptedAccount = false;
            dc_context_unref(m_tempContext);

            // TODO: check for errors, e.g. newAccID == 0, m_tempContext ==
            // nullptr?
            uint32_t newAccID = dc_accounts_add_account(m_dcAccs);
            m_tempContext = dc_accounts_get_account(m_dcAccs, newAccID);

            // Document the still incomplete account in the settings along with
            // the original account it is a copy of. Reason: If the workflow fails
            // or is interrupted (e.g. by the user closing the app), the new account
            // will be unconfigured, and it's origin will still be there. To resume
            // the workflow, the unconfigured account should be removed.
            QString tempSettingString("");
            tempSettingString.append(QString::number(newAccID));
            tempSettingString.append(" importedFrom ");
            tempSettingString.append(QString::number(m_accountsToConvert.back()));
            m_settings->setValue("workflowDbImportingInto", tempSettingString);

            emit statusChanged(false, (m_totalAccounts - m_accountsToConvert.size()) + 1, m_totalAccounts);
            // the actual import step
            dc_imex(m_tempContext, DC_IMEX_IMPORT_BACKUP, m_writtenFile.toUtf8().constData(), m_passphrase.toUtf8().constData());
        } else {
            // Just finished creating an unencrypted account based
            // on an exported backup, delete the encrypted original account
            emit addedNewOpenAccount();

            dc_context_unref(m_tempContext);
            m_tempContext = nullptr;

            uint32_t tempAccID = m_accountsToConvert.back();
            dc_accounts_remove_account(m_dcAccs, tempAccID);
            emit removedAccount(tempAccID);
            m_accountsToConvert.pop_back();
            m_settings->remove("workflowDbImportingInto");

            // Also delete the temporary backup file
            QFile::remove(m_writtenFile);

            // Now the next encrypted account has to be exported or,
            // if none left, the workflow has to be completed
            if (m_accountsToConvert.size() == 0) {
                // finished, clean up
                m_settings->setValue("workflowDbToUnencryptedRunning", false);
                emit workflowCompleted();
            } else {
                // export the next account in the list
                m_tempContext = dc_accounts_get_account(m_dcAccs, m_accountsToConvert.back());
                if (!m_tempContext) {
                    qDebug() << "WorkflowDbToUnencrypted::startWorkflow(): Error: Could not get context of account with ID " << m_accountsToConvert.back() << ", aborting.";
                    m_settings->setValue("workflowDbToUnencryptedRunning", false);
                    // TODO: how to notify the caller of this method?
                    return;
                }

                m_currentlyExportingEncryptedAccount = true;
                emit statusChanged(true, (m_totalAccounts - m_accountsToConvert.size()) + 1, m_totalAccounts);

                qDebug() << "++++++++++++++++++++++++ workflowToUnencrypted: now trying to export acc ID " << dc_get_id(m_tempContext);
                if (m_passphrase == "") {
                    qDebug() << "++++++++++++++ passphrase is empty";
                } else {
                    qDebug() << "++++++++++++++ passphrase is NOT empty";
                }

                if (0 == dc_context_is_open(m_tempContext)) {
                    qDebug() << "+++++++++++++++++++ account is CLOSED!!!!";
                } else {
                    qDebug() << "+++++++++++++++++++ account is open!!!!";
                }

                dc_imex(m_tempContext, DC_IMEX_EXPORT_BACKUP, m_cacheDir.toUtf8().constData(), m_passphrase.toUtf8().constData());
            }
        }
    }
}


void WorkflowDbToUnencrypted::imexFileReceiver(QString writFil)
{
    m_writtenFile = writFil;
}


bool WorkflowDbToUnencrypted::accountIsClosed(uint32_t accID)
{
    bool isClosed = false;

    for (size_t i = 0; i < m_closedAccounts.size(); ++i) {
        if (accID == m_closedAccounts[i]) {
            isClosed = true;
            break;
        }
    }

    return isClosed;
}
