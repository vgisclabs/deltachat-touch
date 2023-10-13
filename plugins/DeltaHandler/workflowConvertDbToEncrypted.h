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

#ifndef WORKFLOWCONVERTDBTOENCRYPTED_H
#define WORKFLOWCONVERTDBTOENCRYPTED_H

#include <QObject>
#include <QString>
#include <QSettings>
#include <QStandardPaths>
#include <vector>
#include "deltachat.h"
#include "emitterthread.h"

class EmitterThread;

class WorkflowDbToEncrypted : public QObject {
    Q_OBJECT

signals:
    void imexEvent(int progress);
    // If exporting is true, an account is currently exported, otherwise
    // the exported backup file is imported into an encrypted account
    void statusChanged(bool exporting, int currentAccountNo, int totalAccountNo);

    // TODO used?
    void workflowCompleted();
    void workflowError();
    void removedAccount(uint32_t accountID);
    void addedNewClosedAccount(uint32_t newAccID);

public:
//    explicit WorkflowDbToEncrypted(QObject *parent = 0);
    explicit WorkflowDbToEncrypted(dc_accounts_t* dcaccs, EmitterThread* emthread, QSettings* settings, const std::vector<uint32_t>& closedAccs, uint32_t currentAccID, QString passphrase);
    ~WorkflowDbToEncrypted();

    Q_INVOKABLE void startWorkflow();

public slots:
    void imexProgressReceiver(int imProg);
    void imexFileReceiver(QString writFil);

private:
    // set in constructor
    dc_accounts_t* m_dcAccs;
    EmitterThread* m_emitterthread;
    QSettings* m_settings;
    std::vector<uint32_t> m_closedAccounts;
    uint32_t m_currentlySelectedAccID;
    // the user passphrase
    QString m_passphrase;
    // end set in constructor

    // a randomly generated extra passphrase for temporary exports
    QString m_exportSecret;

    // Stores the IDs of all currently present accounts
    std::vector<uint32_t> m_accountsToConvert;
    int m_totalAccounts;
    QString m_cacheDir;
    QString m_writtenFile;

    dc_context_t* m_tempContext;

    // set to true when the export of an account
    // is started
    bool m_currentlyExportingUnencryptedAccount;

    // assumes that m_accountsToConvert is correct,
    // i.e., contains the account IDs of accounts
    // that still have to be converted (and nothing else)
    void writeUnconvertedAccountsToSettings();

    // checks if accID is contained in the vector m_closedAccounts
    bool accountIsClosed(uint32_t accID);

    // the ID of the new closed account where the
    // previously generated backup is imported to
    uint32_t m_newAccID;
};

#endif // WORKFLOWCONVERTDBTOENCRYPTED_H
