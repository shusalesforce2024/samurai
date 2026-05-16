public with sharing class FreeePartnerController {
    @AuraEnabled
    public static FreeePartnerFacade.Result syncPartner(Id accountId) {
        try {
            return FreeePartnerFacade.syncPartner(accountId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('freee取引先同期に失敗しました: ' + e.getMessage());
        }
    }
}
