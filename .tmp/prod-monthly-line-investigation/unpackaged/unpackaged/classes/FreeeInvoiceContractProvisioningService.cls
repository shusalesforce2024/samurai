public with sharing class FreeeInvoiceContractProvisioningService {
    private static final String STATUS_ACTIVATED = 'Activated';
    private static final String UPDATE_MONTHLY = '月';
    private static final String UPDATE_YEARLY = '年';
    private static final String CYCLE_MONTHLY = 'Monthly';
    private static final String CYCLE_YEARLY = 'Yearly';
    private static final String CYCLE_ONE_TIME = 'OneTime';
    private static final String NATURE_RECURRING = 'Recurring';
    private static final String NATURE_ONE_TIME = 'OneTime';
    private static final String BILLING_SOURCE_FREEE = 'Freee';
    private static final String CREATION_SOURCE_FREEE = 'FreeeImport';

    public static void provisionAll() {
        List<Mig_FreeeInvoiceWork__c> works = [
            SELECT Id,
                   FreeePartnerId__c,
                   Subject__c,
                   BillingDate__c,
                   TargetPeriodStartDate__c,
                   TargetPeriodEndDate__c,
                   ResolvedAccount__c,
                   ResolvedContract__c,
                   ResolvedContractPeriod__c,
                   ResolutionAction__c,
                   ProvisioningMessage__c,
                   ImportStatus__c,
                   (SELECT Id,
                           ConfirmedProductMaster__c,
                           Quantity__c,
                           LineAmount__c,
                           ImportStatus__c
                    FROM InvoiceLineWorks__r)
            FROM Mig_FreeeInvoiceWork__c
            WHERE ImportStatus__c IN :new List<String>{
                Mig_FreeeInvoiceWorkService.STATUS_FETCHED,
                Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW,
                Mig_FreeeInvoiceWorkService.STATUS_READY
            }
              AND ResolvedAccount__c != null
        ];
        if (works.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Set<Id> knownContractIds = new Set<Id>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            accountIds.add(workRecord.ResolvedAccount__c);
            if (workRecord.ResolvedContract__c != null) {
                knownContractIds.add(workRecord.ResolvedContract__c);
            }
            for (Mig_FreeeInvoiceLineWork__c line : activeLines(workRecord)) {
                if (line.ConfirmedProductMaster__c != null) {
                    productIds.add(line.ConfirmedProductMaster__c);
                }
            }
        }

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, Name
            FROM Account
            WHERE Id IN :accountIds
        ]);
        Map<Id, ProductMaster__c> productsById = productIds.isEmpty()
            ? new Map<Id, ProductMaster__c>()
            : new Map<Id, ProductMaster__c>([
                SELECT Id,
                       Name,
                       AnnualMonthlyPrice__c,
                       ARR_Target__c,
                       MRR_Target__c
                FROM ProductMaster__c
                WHERE Id IN :productIds
            ]);
        Set<Id> ambiguousExistingContractWorkIds =
            resolveExistingContractsByProduct(
                works,
                accountIds,
                productIds,
                knownContractIds
            );

        List<FreeeInvoiceContractRule__c> rules = [
            SELECT Id,
                   Name,
                   Account__c,
                   FreeePartnerId__c,
                   ProductMaster__c,
                   SubjectKeyword__c,
                   BillingCycle__c,
                   AutoCreateAllowed__c,
                   IsActive__c,
                   Contract__c,
                   ContractName__c,
                   StartDate__c,
                   EndDate__c
            FROM FreeeInvoiceContractRule__c
            WHERE IsActive__c = true
              AND (Account__c = null OR Account__c IN :accountIds)
        ];
        Map<Id, List<FreeeInvoiceContractRule__c>> rulesByAccount =
            new Map<Id, List<FreeeInvoiceContractRule__c>>();
        List<FreeeInvoiceContractRule__c> commonRules =
            new List<FreeeInvoiceContractRule__c>();
        groupRules(rules, rulesByAccount, commonRules, knownContractIds);

        Map<Id, FreeeInvoiceContractRule__c> selectedRuleByWorkId =
            new Map<Id, FreeeInvoiceContractRule__c>();
        Map<String, List<Mig_FreeeInvoiceWork__c>> worksByRuleAndAccount =
            new Map<String, List<Mig_FreeeInvoiceWork__c>>();

        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            if (workRecord.ResolvedContract__c != null) {
                workRecord.ResolutionAction__c = 'ExistingContract';
                workRecord.ProvisioningMessage__c = '既存の契約管理を使用します。';
                continue;
            }
            if (ambiguousExistingContractWorkIds.contains(workRecord.Id)) {
                continue;
            }
            if (!hasConfirmedProducts(workRecord)) {
                workRecord.ResolutionAction__c = 'NeedsReview';
                workRecord.ProvisioningMessage__c =
                    '商品マスタが確定していないため、契約管理を自動作成しません。';
                continue;
            }

            List<FreeeInvoiceContractRule__c> matches = matchingRules(
                workRecord,
                rulesByAccount.get(workRecord.ResolvedAccount__c),
                commonRules
            );
            if (matches.size() != 1) {
                workRecord.ResolutionAction__c = 'NeedsReview';
                workRecord.ProvisioningMessage__c = matches.isEmpty()
                    ? '承認済みのFreee請求契約ルールがないため、契約管理を自動作成しません。'
                    : '一致するFreee請求契約ルールが複数あるため、自動確定しません。';
                continue;
            }

            FreeeInvoiceContractRule__c selectedRule = matches[0];
            selectedRuleByWorkId.put(workRecord.Id, selectedRule);
            if (selectedRule.Contract__c != null) {
                workRecord.ResolvedContract__c = selectedRule.Contract__c;
                workRecord.ResolutionAction__c = 'ExistingContract';
                workRecord.ProvisioningMessage__c =
                    'Freee請求契約ルールに設定された契約管理を使用します。';
            } else if (selectedRule.AutoCreateAllowed__c) {
                String provisioningKey =
                    selectedRule.Id + ':' + workRecord.ResolvedAccount__c;
                if (!worksByRuleAndAccount.containsKey(provisioningKey)) {
                    worksByRuleAndAccount.put(
                        provisioningKey,
                        new List<Mig_FreeeInvoiceWork__c>()
                    );
                }
                worksByRuleAndAccount.get(provisioningKey).add(workRecord);
            } else {
                workRecord.ResolutionAction__c = 'NeedsReview';
                workRecord.ProvisioningMessage__c =
                    'Freee請求契約ルールで契約管理の自動作成が許可されていません。';
            }
        }

        createContractsForRules(
            worksByRuleAndAccount,
            selectedRuleByWorkId,
            accountsById,
            productsById,
            knownContractIds
        );

        Map<Id, Contract__c> contractsById = knownContractIds.isEmpty()
            ? new Map<Id, Contract__c>()
            : new Map<Id, Contract__c>([
                SELECT Id,
                       Account__c,
                       ContractName__c,
                       ContractUpdate__c,
                       ContractNature__c,
                       BillingControlSource__c,
                       StartDate__c,
                       EndDate__c
                FROM Contract__c
                WHERE Id IN :knownContractIds
            ]);

        provisionPeriodsAndMonthlyLines(works, contractsById, productsById);
        update works;
    }

    private static Set<Id> resolveExistingContractsByProduct(
        List<Mig_FreeeInvoiceWork__c> works,
        Set<Id> accountIds,
        Set<Id> productIds,
        Set<Id> knownContractIds
    ) {
        Set<Id> ambiguousWorkIds = new Set<Id>();
        if (accountIds.isEmpty() || productIds.isEmpty()) {
            return ambiguousWorkIds;
        }

        Map<Id, Contract__c> contractById = new Map<Id, Contract__c>();
        Map<Id, Set<Id>> productIdsByContract = new Map<Id, Set<Id>>();
        Map<Id, List<Contract__c>> contractsByAccount =
            new Map<Id, List<Contract__c>>();
        for (ContractLineItem__c contractLine : [
            SELECT MasterContract__c,
                   ProductMaster__c,
                   MasterContract__r.Id,
                   MasterContract__r.Account__c,
                   MasterContract__r.StartDate__c,
                   MasterContract__r.EndDate__c,
                   MasterContract__r.Status__c
            FROM ContractLineItem__c
            WHERE MasterContract__r.Account__c IN :accountIds
              AND MasterContract__r.Status__c = :STATUS_ACTIVATED
              AND ProductMaster__c IN :productIds
        ]) {
            Id contractId = contractLine.MasterContract__c;
            if (!contractById.containsKey(contractId)) {
                Contract__c contractRecord = contractLine.MasterContract__r;
                contractById.put(contractId, contractRecord);
                Id accountId = contractRecord.Account__c;
                if (!contractsByAccount.containsKey(accountId)) {
                    contractsByAccount.put(accountId, new List<Contract__c>());
                }
                contractsByAccount.get(accountId).add(contractRecord);
            }
            if (!productIdsByContract.containsKey(contractId)) {
                productIdsByContract.put(contractId, new Set<Id>());
            }
            productIdsByContract.get(contractId).add(contractLine.ProductMaster__c);
        }

        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            if (workRecord.ResolvedContract__c != null) {
                continue;
            }
            Set<Id> requiredProductIds = confirmedProductIds(workRecord);
            if (requiredProductIds.isEmpty()) {
                continue;
            }
            List<Contract__c> candidates = new List<Contract__c>();
            List<Contract__c> accountContracts =
                contractsByAccount.get(workRecord.ResolvedAccount__c);
            if (accountContracts != null) {
                for (Contract__c contractRecord : accountContracts) {
                    Set<Id> contractProductIds =
                        productIdsByContract.get(contractRecord.Id);
                    if (containsAllProducts(contractProductIds, requiredProductIds)
                        && contractContainsTarget(contractRecord, workRecord)) {
                        candidates.add(contractRecord);
                    }
                }
            }
            if (candidates.size() == 1) {
                workRecord.ResolvedContract__c = candidates[0].Id;
                workRecord.ResolutionAction__c = 'ExistingContract';
                workRecord.ProvisioningMessage__c =
                    '取引先・商品・対象日に一致する既存の契約管理を使用します。';
                knownContractIds.add(candidates[0].Id);
            } else if (candidates.size() > 1) {
                workRecord.ResolutionAction__c = 'NeedsReview';
                workRecord.ProvisioningMessage__c =
                    '取引先・商品・対象日に一致する既存契約が複数あるため、新しい契約を自動作成しません。';
                ambiguousWorkIds.add(workRecord.Id);
            }
        }
        return ambiguousWorkIds;
    }

    private static Boolean containsAllProducts(
        Set<Id> availableProductIds,
        Set<Id> requiredProductIds
    ) {
        if (availableProductIds == null) {
            return false;
        }
        for (Id productId : requiredProductIds) {
            if (!availableProductIds.contains(productId)) {
                return false;
            }
        }
        return true;
    }

    private static void groupRules(
        List<FreeeInvoiceContractRule__c> rules,
        Map<Id, List<FreeeInvoiceContractRule__c>> rulesByAccount,
        List<FreeeInvoiceContractRule__c> commonRules,
        Set<Id> knownContractIds
    ) {
        for (FreeeInvoiceContractRule__c rule : rules) {
            if (rule.Account__c == null) {
                commonRules.add(rule);
            } else {
                if (!rulesByAccount.containsKey(rule.Account__c)) {
                    rulesByAccount.put(
                        rule.Account__c,
                        new List<FreeeInvoiceContractRule__c>()
                    );
                }
                rulesByAccount.get(rule.Account__c).add(rule);
            }
            if (rule.Contract__c != null) {
                knownContractIds.add(rule.Contract__c);
            }
        }
    }

    private static List<FreeeInvoiceContractRule__c> matchingRules(
        Mig_FreeeInvoiceWork__c workRecord,
        List<FreeeInvoiceContractRule__c> accountRules,
        List<FreeeInvoiceContractRule__c> commonRules
    ) {
        List<FreeeInvoiceContractRule__c> accountMatches =
            matchingRulesAtScope(workRecord, accountRules);
        if (!accountMatches.isEmpty()) {
            return accountMatches;
        }
        return matchingRulesAtScope(workRecord, commonRules);
    }

    private static List<FreeeInvoiceContractRule__c> matchingRulesAtScope(
        Mig_FreeeInvoiceWork__c workRecord,
        List<FreeeInvoiceContractRule__c> candidateRules
    ) {
        List<FreeeInvoiceContractRule__c> matches =
            new List<FreeeInvoiceContractRule__c>();
        if (candidateRules == null || candidateRules.isEmpty()) {
            return matches;
        }
        Set<Id> lineProductIds = confirmedProductIds(workRecord);
        String normalizedSubject = Mig_FreeeInvoiceWorkService.normalize(workRecord.Subject__c);
        for (FreeeInvoiceContractRule__c rule : candidateRules) {
            if (!String.isBlank(rule.FreeePartnerId__c)
                && rule.FreeePartnerId__c != workRecord.FreeePartnerId__c) {
                continue;
            }
            if (rule.ProductMaster__c != null
                && !lineProductIds.contains(rule.ProductMaster__c)) {
                continue;
            }
            if (!String.isBlank(rule.SubjectKeyword__c)
                && (
                    String.isBlank(normalizedSubject)
                    || !normalizedSubject.contains(
                        Mig_FreeeInvoiceWorkService.normalize(rule.SubjectKeyword__c)
                    )
                )) {
                continue;
            }
            matches.add(rule);
        }
        return matches;
    }

    private static void createContractsForRules(
        Map<String, List<Mig_FreeeInvoiceWork__c>> worksByRuleAndAccount,
        Map<Id, FreeeInvoiceContractRule__c> selectedRuleByWorkId,
        Map<Id, Account> accountsById,
        Map<Id, ProductMaster__c> productsById,
        Set<Id> knownContractIds
    ) {
        if (worksByRuleAndAccount.isEmpty()) {
            return;
        }

        List<Contract__c> contractsToInsert = new List<Contract__c>();
        List<String> provisioningKeysInInsertOrder = new List<String>();
        for (String provisioningKey : worksByRuleAndAccount.keySet()) {
            List<Mig_FreeeInvoiceWork__c> ruleWorks =
                worksByRuleAndAccount.get(provisioningKey);
            Mig_FreeeInvoiceWork__c firstWork = ruleWorks[0];
            FreeeInvoiceContractRule__c rule =
                selectedRuleByWorkId.get(firstWork.Id);
            Id accountId = firstWork.ResolvedAccount__c;
            Boolean oneTime = rule.BillingCycle__c == CYCLE_ONE_TIME;
            String updateCycle = rule.BillingCycle__c == CYCLE_YEARLY
                ? UPDATE_YEARLY
                : UPDATE_MONTHLY;
            Date earliestStart = earliestTargetStart(ruleWorks, updateCycle);
            if (earliestStart == null) {
                for (Mig_FreeeInvoiceWork__c workRecord : ruleWorks) {
                    workRecord.ResolutionAction__c = 'NeedsReview';
                    workRecord.ProvisioningMessage__c =
                        '請求対象期間を特定できないため、契約管理を自動作成しません。';
                }
                continue;
            }
            if (rule.BillingCycle__c == CYCLE_YEARLY
                && !hasAnnualMonthlyPrices(ruleWorks, productsById)) {
                for (Mig_FreeeInvoiceWork__c workRecord : ruleWorks) {
                    workRecord.ResolutionAction__c = 'NeedsReview';
                    workRecord.ProvisioningMessage__c =
                        '年契約月額按分料金が商品マスタにないため、契約管理を自動作成しません。';
                }
                continue;
            }

            Account accountRecord = accountsById.get(accountId);
            ProductMaster__c productRecord = productsById.get(rule.ProductMaster__c);
            String contractName = String.isBlank(rule.ContractName__c)
                ? buildContractName(accountRecord, productRecord, oneTime)
                : rule.ContractName__c;

            contractsToInsert.add(new Contract__c(
                Account__c = accountId,
                AutoCreatedFromFreee__c = true,
                BillingControlSource__c = BILLING_SOURCE_FREEE,
                ContractName__c = contractName,
                ContractNature__c = oneTime ? NATURE_ONE_TIME : NATURE_RECURRING,
                ContractUpdate__c = updateCycle,
                CreationSource__c = CREATION_SOURCE_FREEE,
                EndDate__c = oneTime
                    ? effectivePeriodEnd(ruleWorks[0], updateCycle, oneTime)
                    : rule.EndDate__c,
                Payment__c = 'Invoice',
                RenewalStop__c = true,
                StartDate__c = rule.StartDate__c == null ? earliestStart : rule.StartDate__c,
                Status__c = STATUS_ACTIVATED
            ));
            provisioningKeysInInsertOrder.add(provisioningKey);
        }

        if (contractsToInsert.isEmpty()) {
            return;
        }
        insert contractsToInsert;

        List<FreeeInvoiceContractRule__c> rulesToUpdate =
            new List<FreeeInvoiceContractRule__c>();
        for (Integer index = 0; index < contractsToInsert.size(); index++) {
            String provisioningKey = provisioningKeysInInsertOrder[index];
            List<Mig_FreeeInvoiceWork__c> ruleWorks =
                worksByRuleAndAccount.get(provisioningKey);
            FreeeInvoiceContractRule__c rule =
                selectedRuleByWorkId.get(ruleWorks[0].Id);
            Id contractId = contractsToInsert[index].Id;
            knownContractIds.add(contractId);
            if (rule.Account__c != null && rule.Contract__c == null) {
                rulesToUpdate.add(new FreeeInvoiceContractRule__c(
                    Id = rule.Id,
                    Contract__c = contractId
                ));
            }
            for (Mig_FreeeInvoiceWork__c workRecord : ruleWorks) {
                workRecord.ResolvedContract__c = contractId;
                Boolean oneTime =
                    rule.BillingCycle__c == CYCLE_ONE_TIME;
                workRecord.ResolutionAction__c = oneTime
                    ? 'OneTimeContractProvisioned'
                    : 'ContractProvisioned';
                workRecord.ProvisioningMessage__c = oneTime
                    ? '更新停止済み・MRR対象外の単発契約を自動作成しました。'
                    : '承認済みルールからFreee管理の継続契約を自動作成しました。';
            }
        }
        if (!rulesToUpdate.isEmpty()) {
            update rulesToUpdate;
        }
    }

    private static void provisionPeriodsAndMonthlyLines(
        List<Mig_FreeeInvoiceWork__c> works,
        Map<Id, Contract__c> contractsById,
        Map<Id, ProductMaster__c> productsById
    ) {
        Set<Id> contractIds = new Set<Id>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            if (workRecord.ResolvedContract__c != null) {
                contractIds.add(workRecord.ResolvedContract__c);
            }
        }
        if (contractIds.isEmpty()) {
            return;
        }

        if (contractsById.size() < contractIds.size()) {
            contractsById.putAll(new Map<Id, Contract__c>([
                SELECT Id,
                       Account__c,
                       ContractName__c,
                       ContractUpdate__c,
                       ContractNature__c,
                       BillingControlSource__c,
                       StartDate__c,
                       EndDate__c
                FROM Contract__c
                WHERE Id IN :contractIds
            ]));
        }

        Map<String, ContractPeriod__c> periodByKey =
            new Map<String, ContractPeriod__c>();
        for (ContractPeriod__c periodRecord : [
            SELECT Id,
                   Contract__c,
                   PeriodStartDate__c,
                   PeriodEndDate__c
            FROM ContractPeriod__c
            WHERE Contract__c IN :contractIds
        ]) {
            periodByKey.put(
                periodKey(
                    periodRecord.Contract__c,
                    periodRecord.PeriodStartDate__c,
                    periodRecord.PeriodEndDate__c
                ),
                periodRecord
            );
        }

        List<ContractPeriod__c> periodsToInsert = new List<ContractPeriod__c>();
        Map<String, List<Mig_FreeeInvoiceWork__c>> worksByPeriodKey =
            new Map<String, List<Mig_FreeeInvoiceWork__c>>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            if (workRecord.ResolvedContract__c == null
                || workRecord.ResolvedContractPeriod__c != null
                || !hasConfirmedProducts(workRecord)) {
                continue;
            }
            Contract__c contractRecord = contractsById.get(workRecord.ResolvedContract__c);
            if (contractRecord == null || !contractContainsTarget(contractRecord, workRecord)) {
                workRecord.ResolutionAction__c = 'NeedsReview';
                workRecord.ProvisioningMessage__c =
                    '請求対象日が契約期間外のため、契約期間を自動作成しません。';
                continue;
            }

            Boolean oneTime = contractRecord.ContractNature__c == NATURE_ONE_TIME;
            if (!oneTime
                && contractRecord.ContractUpdate__c == UPDATE_YEARLY
                && !hasAnnualMonthlyPrices(
                    new List<Mig_FreeeInvoiceWork__c>{ workRecord },
                    productsById
                )) {
                workRecord.ResolutionAction__c = 'NeedsReview';
                workRecord.ProvisioningMessage__c =
                    '年契約月額按分料金が商品マスタにないため、契約期間を自動作成しません。';
                continue;
            }
            Date periodStart = effectivePeriodStart(
                workRecord,
                contractRecord.ContractUpdate__c
            );
            Date periodEnd = effectivePeriodEnd(
                workRecord,
                contractRecord.ContractUpdate__c,
                oneTime
            );
            if (periodStart == null || periodEnd == null) {
                workRecord.ResolutionAction__c = 'NeedsReview';
                workRecord.ProvisioningMessage__c =
                    '請求対象期間を特定できないため、契約期間を自動作成しません。';
                continue;
            }

            String key = periodKey(contractRecord.Id, periodStart, periodEnd);
            if (!worksByPeriodKey.containsKey(key)) {
                worksByPeriodKey.put(key, new List<Mig_FreeeInvoiceWork__c>());
            }
            worksByPeriodKey.get(key).add(workRecord);
            if (!periodByKey.containsKey(key)) {
                ContractPeriod__c newPeriod = new ContractPeriod__c(
                    Contract__c = contractRecord.Id,
                    ContractUpdate__c = contractRecord.ContractUpdate__c,
                    FreeeSyncStatus__c = '連携済',
                    InvoiceCreationStatus__c = '作成済',
                    IsInitialPeriod__c = false,
                    PeriodStartDate__c = periodStart,
                    PeriodEndDate__c = periodEnd
                );
                periodsToInsert.add(newPeriod);
                periodByKey.put(key, newPeriod);
            }
        }

        if (!periodsToInsert.isEmpty()) {
            insert periodsToInsert;
        }

        for (String key : worksByPeriodKey.keySet()) {
            ContractPeriod__c periodRecord = periodByKey.get(key);
            for (Mig_FreeeInvoiceWork__c workRecord : worksByPeriodKey.get(key)) {
                workRecord.ResolvedContractPeriod__c = periodRecord.Id;
                if (workRecord.ResolutionAction__c == 'ExistingContract') {
                    workRecord.ResolutionAction__c = 'PeriodProvisioned';
                    workRecord.ProvisioningMessage__c =
                        '既存契約に不足していた契約期間・契約月次明細を補完しました。';
                }
            }
        }

        ensureMonthlyLines(works, contractsById, productsById);
    }

    private static void ensureMonthlyLines(
        List<Mig_FreeeInvoiceWork__c> works,
        Map<Id, Contract__c> contractsById,
        Map<Id, ProductMaster__c> productsById
    ) {
        Set<Id> periodIds = new Set<Id>();
        Set<Id> requiredProductIds = new Set<Id>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            if (workRecord.ResolvedContractPeriod__c == null) {
                continue;
            }
            periodIds.add(workRecord.ResolvedContractPeriod__c);
            requiredProductIds.addAll(confirmedProductIds(workRecord));
        }
        if (periodIds.isEmpty() || requiredProductIds.isEmpty()) {
            return;
        }

        Set<String> existingKeys = new Set<String>();
        for (ContractLineItem__c line : [
            SELECT Id, ContractPeriod__c, ProductMaster__c
            FROM ContractLineItem__c
            WHERE ContractPeriod__c IN :periodIds
              AND ProductMaster__c IN :requiredProductIds
        ]) {
            existingKeys.add(line.ContractPeriod__c + ':' + line.ProductMaster__c);
        }

        Map<String, ContractLineItem__c> newLinesByKey =
            new Map<String, ContractLineItem__c>();
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            if (workRecord.ResolvedContractPeriod__c == null) {
                continue;
            }
            Contract__c contractRecord = contractsById.get(workRecord.ResolvedContract__c);
            Boolean oneTime = contractRecord != null
                && contractRecord.ContractNature__c == NATURE_ONE_TIME;
            for (Mig_FreeeInvoiceLineWork__c lineWork : activeLines(workRecord)) {
                if (lineWork.ConfirmedProductMaster__c == null) {
                    continue;
                }
                String key = workRecord.ResolvedContractPeriod__c
                    + ':'
                    + lineWork.ConfirmedProductMaster__c;
                if (existingKeys.contains(key) || newLinesByKey.containsKey(key)) {
                    continue;
                }
                ProductMaster__c product =
                    productsById.get(lineWork.ConfirmedProductMaster__c);
                Decimal quantity = lineWork.Quantity__c == null
                    || lineWork.Quantity__c == 0
                    ? 1
                    : lineWork.Quantity__c;
                Decimal monthlyRevenue = lineWork.LineAmount__c;
                if (!oneTime
                    && contractRecord != null
                    && contractRecord.ContractUpdate__c == UPDATE_YEARLY) {
                    if (product == null || product.AnnualMonthlyPrice__c == null) {
                        workRecord.ResolutionAction__c = 'NeedsReview';
                        workRecord.ProvisioningMessage__c =
                            '年契約月額按分料金が商品マスタにないため、契約月次明細を自動作成できません。';
                        continue;
                    }
                    monthlyRevenue = product.AnnualMonthlyPrice__c * quantity;
                }
                newLinesByKey.put(key, new ContractLineItem__c(
                    Account__c = workRecord.ResolvedAccount__c,
                    ARR_Target__c = !oneTime && product != null && product.ARR_Target__c,
                    ContractPeriod__c = workRecord.ResolvedContractPeriod__c,
                    InitialFee__c = oneTime,
                    MasterContract__c = workRecord.ResolvedContract__c,
                    MRR_Target__c = !oneTime && product != null && product.MRR_Target__c,
                    PeopleNumber__c = quantity,
                    PeriodStartDate__c = effectivePeriodStart(
                        workRecord,
                        contractRecord == null ? UPDATE_MONTHLY : contractRecord.ContractUpdate__c
                    ),
                    PeriodEndDate__c = effectivePeriodEnd(
                        workRecord,
                        contractRecord == null ? UPDATE_MONTHLY : contractRecord.ContractUpdate__c,
                        oneTime
                    ),
                    ProductMaster__c = lineWork.ConfirmedProductMaster__c,
                    RevenueAmount__c = monthlyRevenue,
                    Total__c = monthlyRevenue
                ));
            }
        }
        if (!newLinesByKey.isEmpty()) {
            insert newLinesByKey.values();
        }
    }

    private static Boolean hasConfirmedProducts(Mig_FreeeInvoiceWork__c workRecord) {
        List<Mig_FreeeInvoiceLineWork__c> lines = activeLines(workRecord);
        if (lines.isEmpty()) {
            return false;
        }
        for (Mig_FreeeInvoiceLineWork__c line : lines) {
            if (line.ConfirmedProductMaster__c == null) {
                return false;
            }
        }
        return true;
    }

    private static Set<Id> confirmedProductIds(Mig_FreeeInvoiceWork__c workRecord) {
        Set<Id> result = new Set<Id>();
        for (Mig_FreeeInvoiceLineWork__c line : activeLines(workRecord)) {
            if (line.ConfirmedProductMaster__c != null) {
                result.add(line.ConfirmedProductMaster__c);
            }
        }
        return result;
    }

    private static List<Mig_FreeeInvoiceLineWork__c> activeLines(
        Mig_FreeeInvoiceWork__c workRecord
    ) {
        List<Mig_FreeeInvoiceLineWork__c> result =
            new List<Mig_FreeeInvoiceLineWork__c>();
        if (workRecord.InvoiceLineWorks__r == null) {
            return result;
        }
        for (Mig_FreeeInvoiceLineWork__c line : workRecord.InvoiceLineWorks__r) {
            if (line.ImportStatus__c != Mig_FreeeInvoiceWorkService.STATUS_EXCLUDED) {
                result.add(line);
            }
        }
        return result;
    }

    private static Date earliestTargetStart(
        List<Mig_FreeeInvoiceWork__c> works,
        String updateCycle
    ) {
        Date earliest;
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            Date candidate = effectivePeriodStart(workRecord, updateCycle);
            if (candidate != null && (earliest == null || candidate < earliest)) {
                earliest = candidate;
            }
        }
        return earliest;
    }

    private static Boolean hasAnnualMonthlyPrices(
        List<Mig_FreeeInvoiceWork__c> works,
        Map<Id, ProductMaster__c> productsById
    ) {
        for (Mig_FreeeInvoiceWork__c workRecord : works) {
            for (Id productId : confirmedProductIds(workRecord)) {
                ProductMaster__c product = productsById.get(productId);
                if (product == null || product.AnnualMonthlyPrice__c == null) {
                    return false;
                }
            }
        }
        return true;
    }

    private static Date effectivePeriodStart(
        Mig_FreeeInvoiceWork__c workRecord,
        String updateCycle
    ) {
        if (workRecord.TargetPeriodStartDate__c != null) {
            return workRecord.TargetPeriodStartDate__c;
        }
        if (workRecord.BillingDate__c == null) {
            return null;
        }
        return Date.newInstance(
            workRecord.BillingDate__c.year(),
            workRecord.BillingDate__c.month(),
            1
        );
    }

    private static Date effectivePeriodEnd(
        Mig_FreeeInvoiceWork__c workRecord,
        String updateCycle,
        Boolean oneTime
    ) {
        if (workRecord.TargetPeriodEndDate__c != null) {
            return workRecord.TargetPeriodEndDate__c;
        }
        Date startDate = effectivePeriodStart(workRecord, updateCycle);
        if (startDate == null) {
            return null;
        }
        Integer months = updateCycle == UPDATE_YEARLY && !oneTime ? 12 : 1;
        return startDate.addMonths(months).addDays(-1);
    }

    private static Boolean contractContainsTarget(
        Contract__c contractRecord,
        Mig_FreeeInvoiceWork__c workRecord
    ) {
        Date target = workRecord.TargetPeriodStartDate__c == null
            ? workRecord.BillingDate__c
            : workRecord.TargetPeriodStartDate__c;
        if (target == null) {
            return false;
        }
        return (contractRecord.StartDate__c == null || contractRecord.StartDate__c <= target)
            && (contractRecord.EndDate__c == null || contractRecord.EndDate__c >= target);
    }

    private static String periodKey(Id contractId, Date startDate, Date endDate) {
        return String.valueOf(contractId)
            + ':'
            + String.valueOf(startDate)
            + ':'
            + String.valueOf(endDate);
    }

    private static String buildContractName(
        Account accountRecord,
        ProductMaster__c productRecord,
        Boolean oneTime
    ) {
        String accountName = accountRecord == null ? '取引先未設定' : accountRecord.Name;
        String productName = productRecord == null ? '商品未設定' : productRecord.Name;
        return accountName
            + ' '
            + productName
            + (oneTime ? ' 単発契約' : ' Freee自動請求契約');
    }
}