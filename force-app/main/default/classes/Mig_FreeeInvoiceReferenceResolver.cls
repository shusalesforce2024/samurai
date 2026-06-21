public with sharing class Mig_FreeeInvoiceReferenceResolver {
    public static void resolveAll() {
        List<Mig_FreeeInvoiceWork__c> works = [
            SELECT Id,
                   FreeePartnerId__c,
                   PartnerName__c,
                   BillingDate__c,
                   TargetPeriodStartDate__c,
                   TargetPeriodEndDate__c,
                   InvoiceAmount__c,
                   Subject__c,
                   ResolvedAccount__c,
                   ResolvedContract__c,
                   ResolvedContractPeriod__c,
                   ValidationMessage__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE ImportStatus__c IN :new List<String>{
                Mig_FreeeInvoiceWorkService.STATUS_FETCHED,
                Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW,
                Mig_FreeeInvoiceWorkService.STATUS_READY
            }
        ];
        if (works.isEmpty()) {
            return;
        }

        resolveAccounts(works);
        resolveContractsAndPeriods(works);
        update works;

        Mig_FreeeInvoiceProductResolver.resolveContractLineItems();
    }

    private static void resolveAccounts(List<Mig_FreeeInvoiceWork__c> works) {
        Set<Decimal> partnerIds = new Set<Decimal>();
        Set<String> partnerNames = new Set<String>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            Decimal partnerId = Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeePartnerId__c);
            if (partnerId != null) {
                partnerIds.add(partnerId);
            }
            if (!String.isBlank(workRecord.PartnerName__c)) {
                partnerNames.add(workRecord.PartnerName__c);
            }
        }

        Map<Decimal, Account> accountByPartnerId = new Map<Decimal, Account>();
        if (!partnerIds.isEmpty()) {
            for (Account acc : [
                SELECT Id, Name, Freee_Partner_Id__c
                FROM Account
                WHERE Freee_Partner_Id__c IN :partnerIds
            ]) {
                accountByPartnerId.put(acc.Freee_Partner_Id__c, acc);
            }
        }

        Map<String, List<Account>> accountsByName = new Map<String, List<Account>>();
        if (!partnerNames.isEmpty()) {
            for (Account acc : [
                SELECT Id, Name, Freee_Partner_Id__c
                FROM Account
                WHERE Name IN :partnerNames
            ]) {
                if (!accountsByName.containsKey(acc.Name)) {
                    accountsByName.put(acc.Name, new List<Account>());
                }
                accountsByName.get(acc.Name).add(acc);
            }
        }

        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            if (workRecord.ResolvedAccount__c != null) {
                continue;
            }
            Decimal partnerId = Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeePartnerId__c);
            if (partnerId != null && accountByPartnerId.containsKey(partnerId)) {
                workRecord.ResolvedAccount__c = accountByPartnerId.get(partnerId).Id;
                continue;
            }
            List<Account> nameMatches = accountsByName.get(workRecord.PartnerName__c);
            if (nameMatches != null && nameMatches.size() == 1) {
                workRecord.ResolvedAccount__c = nameMatches[0].Id;
            } else if (nameMatches != null && nameMatches.size() > 1) {
                appendMessage(workRecord, 'Multiple Accounts matched by PartnerName.');
            }
        }
    }

    private static void resolveContractsAndPeriods(List<Mig_FreeeInvoiceWork__c> works) {
        Set<Id> accountIds = new Set<Id>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            if (workRecord.ResolvedAccount__c != null) {
                accountIds.add(workRecord.ResolvedAccount__c);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, List<Contract__c>> contractsByAccount = new Map<Id, List<Contract__c>>();
        for (Contract__c contractRecord : [
            SELECT Id, Account__c, ContractName__c, StartDate__c, EndDate__c, Status__c
            FROM Contract__c
            WHERE Account__c IN :accountIds
              AND Status__c = 'Activated'
        ]) {
            if (!contractsByAccount.containsKey(contractRecord.Account__c)) {
                contractsByAccount.put(contractRecord.Account__c, new List<Contract__c>());
            }
            contractsByAccount.get(contractRecord.Account__c).add(contractRecord);
        }

        Map<Id, List<ContractPeriod__c>> periodsByContract = new Map<Id, List<ContractPeriod__c>>();
        Map<Id, List<ContractPeriod__c>> periodsByAccount = new Map<Id, List<ContractPeriod__c>>();
        Set<Id> contractIds = new Set<Id>();
        for (List<Contract__c> records : contractsByAccount.values()) {
            for (Contract__c record : records) {
                contractIds.add(record.Id);
            }
        }
        if (!contractIds.isEmpty()) {
            for (ContractPeriod__c periodRecord : [
                SELECT Id, Contract__c, Contract__r.Account__c, PeriodStartDate__c, PeriodEndDate__c
                FROM ContractPeriod__c
                WHERE Contract__c IN :contractIds
            ]) {
                if (!periodsByContract.containsKey(periodRecord.Contract__c)) {
                    periodsByContract.put(periodRecord.Contract__c, new List<ContractPeriod__c>());
                }
                periodsByContract.get(periodRecord.Contract__c).add(periodRecord);

                Id accountId = periodRecord.Contract__r.Account__c;
                if (!periodsByAccount.containsKey(accountId)) {
                    periodsByAccount.put(accountId, new List<ContractPeriod__c>());
                }
                periodsByAccount.get(accountId).add(periodRecord);
            }
        }

        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            Date targetDate = targetDate(workRecord);
            if (workRecord.ResolvedContractPeriod__c == null && workRecord.ResolvedAccount__c != null) {
                List<ContractPeriod__c> accountPeriods = periodsByAccount.get(workRecord.ResolvedAccount__c);
                List<ContractPeriod__c> accountPeriodMatches = new List<ContractPeriod__c>();
                if (accountPeriods != null) {
                    for (ContractPeriod__c periodRecord : accountPeriods) {
                        if (containsDate(periodRecord.PeriodStartDate__c, periodRecord.PeriodEndDate__c, targetDate)) {
                            accountPeriodMatches.add(periodRecord);
                        }
                    }
                }
                if (accountPeriodMatches.size() == 1) {
                    workRecord.ResolvedContractPeriod__c = accountPeriodMatches[0].Id;
                    if (workRecord.ResolvedContract__c == null) {
                        workRecord.ResolvedContract__c = accountPeriodMatches[0].Contract__c;
                    }
                } else if (accountPeriodMatches.size() > 1) {
                    appendMessage(workRecord, 'Multiple ContractPeriods matched by Account and target date.');
                }
            }

            if (workRecord.ResolvedContract__c == null) {
                List<Contract__c> candidates = new List<Contract__c>();
                List<Contract__c> accountContracts = contractsByAccount.get(workRecord.ResolvedAccount__c);
                if (accountContracts != null) {
                    for (Contract__c contractRecord : accountContracts) {
                        if (containsDate(contractRecord.StartDate__c, contractRecord.EndDate__c, targetDate)) {
                            candidates.add(contractRecord);
                        }
                    }
                }
                if (candidates.size() == 1) {
                    workRecord.ResolvedContract__c = candidates[0].Id;
                } else if (candidates.size() > 1) {
                    appendMessage(workRecord, 'Multiple Contracts matched by Account and target date.');
                }
            }

            if (workRecord.ResolvedContractPeriod__c == null && workRecord.ResolvedContract__c != null) {
                List<ContractPeriod__c> periodCandidates = periodsByContract.get(workRecord.ResolvedContract__c);
                List<ContractPeriod__c> matchedPeriods = new List<ContractPeriod__c>();
                if (periodCandidates != null) {
                    for (ContractPeriod__c periodRecord : periodCandidates) {
                        if (containsDate(periodRecord.PeriodStartDate__c, periodRecord.PeriodEndDate__c, targetDate)) {
                            matchedPeriods.add(periodRecord);
                        }
                    }
                }
                if (matchedPeriods.size() == 1) {
                    workRecord.ResolvedContractPeriod__c = matchedPeriods[0].Id;
                } else if (matchedPeriods.size() > 1) {
                    appendMessage(workRecord, 'Multiple ContractPeriods matched by Contract and target date.');
                }
            }
        }
    }

    private static Date targetDate(Mig_FreeeInvoiceWork__c workRecord) {
        if (workRecord.TargetPeriodStartDate__c != null) {
            return workRecord.TargetPeriodStartDate__c;
        }
        return workRecord.BillingDate__c;
    }

    private static Boolean containsDate(Date startDate, Date endDate, Date targetDate) {
        if (targetDate == null) {
            return false;
        }
        Boolean startsOk = startDate == null || startDate <= targetDate;
        Boolean endsOk = endDate == null || endDate >= targetDate;
        return startsOk && endsOk;
    }

    private static void appendMessage(Mig_FreeeInvoiceWork__c workRecord, String message) {
        if (String.isBlank(workRecord.ValidationMessage__c)) {
            workRecord.ValidationMessage__c = message;
        } else if (!workRecord.ValidationMessage__c.contains(message)) {
            workRecord.ValidationMessage__c += '\n' + message;
        }
    }
}
