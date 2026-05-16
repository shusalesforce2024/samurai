public with sharing class OpportunityMrrSyncService {
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

        List<Opportunity__c> opportunitiesToUpdate = new List<Opportunity__c>();
        for (Id opportunityId : opportunityIds) {
            opportunitiesToUpdate.add(new Opportunity__c(
                Id = opportunityId,
                MRR__c = totalByOpportunityId.containsKey(opportunityId)
                    ? totalByOpportunityId.get(opportunityId)
                    : 0
            ));
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
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

        List<Opportunity__c> opportunitiesToUpdate = new List<Opportunity__c>();
        for (Id opportunityId : opportunityIds) {
            opportunitiesToUpdate.add(new Opportunity__c(
                Id = opportunityId,
                MRR__c = totalByOpportunityId.containsKey(opportunityId)
                    ? totalByOpportunityId.get(opportunityId)
                    : 0
            ));
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
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
