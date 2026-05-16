public with sharing class OpportunityStageProbabilityService {
    private static final Map<String, Decimal> PROBABILITY_BY_STAGE = new Map<String, Decimal>{
        '初回接点' => 10,
        'Prospecting' => 10,
        '商談化' => 20,
        'Qualification' => 20,
        '課題ヒアリング' => 40,
        'NeedsAnalysis' => 40,
        '提案' => 50,
        'ValueProposition' => 50,
        '交渉' => 80,
        'Negotiation' => 80,
        '承認' => 90,
        'Approval' => 90,
        '受注' => 100,
        'Closed Won' => 100
    };

    public static void syncProbability(
        List<Opportunity__c> newRecords,
        Map<Id, Opportunity__c> oldMap
    ) {
        for (Opportunity__c record : newRecords) {
            if (!shouldSync(record, oldMap)) {
                continue;
            }

            Decimal probability = PROBABILITY_BY_STAGE.get(record.StageName__c);
            if (probability != null) {
                record.StandardProbability__c = probability;
            }
        }
    }

    private static Boolean shouldSync(
        Opportunity__c record,
        Map<Id, Opportunity__c> oldMap
    ) {
        if (String.isBlank(record.StageName__c)) {
            return false;
        }

        if (oldMap == null || !oldMap.containsKey(record.Id)) {
            return true;
        }

        return oldMap.get(record.Id).StageName__c != record.StageName__c;
    }
}
