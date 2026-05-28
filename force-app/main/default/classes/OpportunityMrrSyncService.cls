public with sharing class OpportunityMrrSyncService {
    private static final String DEFAULT_CONTRACT_UPDATE = '月';

    public static void syncFromQuotations(
        List<Quotation__c> newRecords,
        List<Quotation__c> oldRecords
    ) {
        Set<Id> opportunityIds = new Set<Id>();
        collectOpportunityIdsFromQuotations(newRecords, opportunityIds);
        collectOpportunityIdsFromQuotations(oldRecords, opportunityIds);
        syncOpportunityMrr(opportunityIds);
    }

    public static void syncFromQuotationLines(
        List<QuotationLine__c> newRecords,
        List<QuotationLine__c> oldRecords
    ) {
        Set<Id> quotationIds = new Set<Id>();
        collectQuotationIds(newRecords, quotationIds);
        collectQuotationIds(oldRecords, quotationIds);

        if (quotationIds.isEmpty()) {
            return;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (Quotation__c quotation : [
            SELECT Id, Oppotunity__c
            FROM Quotation__c
            WHERE Id IN :quotationIds
        ]) {
            if (quotation.Oppotunity__c != null) {
                opportunityIds.add(quotation.Oppotunity__c);
            }
        }

        syncOpportunityMrrFromQuotationLines(opportunityIds);
    }

    private static void syncOpportunityMrr(Set<Id> opportunityIds) {
        if (opportunityIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> totalByOpportunityId = new Map<Id, Decimal>();
        for (AggregateResult result : [
            SELECT Oppotunity__c opportunityId, SUM(TotalAmount__c) totalAmount
            FROM Quotation__c
            WHERE Oppotunity__c IN :opportunityIds
            GROUP BY Oppotunity__c
        ]) {
            totalByOpportunityId.put(
                (Id) result.get('opportunityId'),
                (Decimal) result.get('totalAmount')
            );
        }

        updateOpportunityMrr(opportunityIds, totalByOpportunityId);
    }

    private static void syncOpportunityMrrFromQuotationLines(Set<Id> opportunityIds) {
        if (opportunityIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> totalByOpportunityId = new Map<Id, Decimal>();
        for (AggregateResult result : [
            SELECT Quotation__r.Oppotunity__c opportunityId, SUM(Line_Amount__c) totalAmount
            FROM QuotationLine__c
            WHERE Quotation__r.Oppotunity__c IN :opportunityIds
            GROUP BY Quotation__r.Oppotunity__c
        ]) {
            totalByOpportunityId.put(
                (Id) result.get('opportunityId'),
                (Decimal) result.get('totalAmount')
            );
        }

        updateOpportunityMrr(opportunityIds, totalByOpportunityId);
    }

    private static void updateOpportunityMrr(
        Set<Id> opportunityIds,
        Map<Id, Decimal> totalByOpportunityId
    ) {
        if (opportunityIds.isEmpty()) {
            return;
        }

        List<Opportunity__c> opportunitiesToUpdate = new List<Opportunity__c>();
        for (Opportunity__c opportunityRecord : [
            SELECT Id, ContractUpdate__c
            FROM Opportunity__c
            WHERE Id IN :opportunityIds
        ]) {
            Opportunity__c opportunityToUpdate = new Opportunity__c(
                Id = opportunityRecord.Id,
                MRR__c = totalByOpportunityId.containsKey(opportunityRecord.Id)
                    ? totalByOpportunityId.get(opportunityRecord.Id)
                    : 0
            );
            if (String.isBlank(opportunityRecord.ContractUpdate__c)) {
                opportunityToUpdate.ContractUpdate__c = DEFAULT_CONTRACT_UPDATE;
            }
            opportunitiesToUpdate.add(opportunityToUpdate);
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(opportunitiesToUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'Opportunity MRR sync failed. OpportunityId='
                        + opportunitiesToUpdate[i].Id
                        + ', Error='
                        + summarizeDmlErrors(results[i].getErrors())
                    );
                }
            }
        }
    }

    private static String summarizeDmlErrors(Database.Error[] errors) {
        List<String> messages = new List<String>();
        for (Database.Error error : errors) {
            messages.add(error.getStatusCode() + ': ' + error.getMessage());
        }
        return String.join(messages, '\n');
    }

    private static void collectOpportunityIdsFromQuotations(
        List<Quotation__c> records,
        Set<Id> opportunityIds
    ) {
        if (records == null) {
            return;
        }

        for (Quotation__c record : records) {
            if (record.Oppotunity__c != null) {
                opportunityIds.add(record.Oppotunity__c);
            }
        }
    }

    private static void collectQuotationIds(
        List<QuotationLine__c> records,
        Set<Id> quotationIds
    ) {
        if (records == null) {
            return;
        }

        for (QuotationLine__c record : records) {
            if (record.Quotation__c != null) {
                quotationIds.add(record.Quotation__c);
            }
        }
    }
}
