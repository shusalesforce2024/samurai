public inherited sharing class OpportunityCsStageService {
    private static final String TARGET_PRODUCT = 'Rendery';
    private static final String TARGET_PLAN = 'Enterprise';
    private static final String WON_STAGE = 'Closed Won';
    private static final String INITIAL_CS_STAGE = 'S1';

    public static void initializeCsStage(List<Opportunity__c> records) {
        if (records == null) {
            return;
        }
        for (Opportunity__c record : records) {
            if (String.isBlank(record.CsStage__c)
                && record.ProductCategory__c == TARGET_PRODUCT
                && record.PlanCategory__c == TARGET_PLAN
                && record.StageName__c == WON_STAGE
            ) {
                record.CsStage__c = INITIAL_CS_STAGE;
            }
        }
    }
}
