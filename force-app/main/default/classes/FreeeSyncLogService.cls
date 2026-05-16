public with sharing class FreeeSyncLogService {
    public class LogRequest {
        public Id invoiceId;
        public String requestBody;
        public String responseBody;
        public Integer statusCode;
        public String result;
        public String errorMessage;
    }

    public static void saveLog(LogRequest req) {
        if (!Schema.sObjectType.Freee_Sync_Log__c.isCreateable()) {
            throw new AuraHandledException('Freee_Sync_Log__c の作成権限がありません。');
        }

        Freee_Sync_Log__c log = new Freee_Sync_Log__c();
        log.Target_Record_Id__c = String.valueOf(req.invoiceId);
        log.Request_Body__c = req.requestBody;
        log.Response_Body__c = req.responseBody;
        log.Status_Code__c = req.statusCode;
        log.Result__c = req.result;
        log.Error_Message__c = req.errorMessage;

        insert log;
    }
}