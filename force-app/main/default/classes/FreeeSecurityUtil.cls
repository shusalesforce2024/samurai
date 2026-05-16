public with sharing class FreeeSecurityUtil {
    public static void checkInvoiceRead() {
        if (!Schema.sObjectType.Invoice__c.isAccessible()) {
            throw new AuraHandledException('Invoice__c の参照権限がありません。');
        }
    }

    public static void checkInvoiceUpdate() {
        if (!Schema.sObjectType.Invoice__c.isUpdateable()) {
            throw new AuraHandledException('Invoice__c の更新権限がありません。');
        }
    }

    public static void checkInvoiceLineRead() {
        if (!Schema.sObjectType.InvoiceLine__c.isAccessible()) {
            throw new AuraHandledException('InvoiceLine__c の参照権限がありません。');
        }
    }

    public static void checkSyncLogCreate() {
        if (!Schema.sObjectType.Freee_Sync_Log__c.isCreateable()) {
            throw new AuraHandledException('Freee_Sync_Log__c の作成権限がありません。');
        }
    }

    public static void checkConfigRead() {
        if (!Schema.sObjectType.Freee_Configs__c.isAccessible()) {
            throw new AuraHandledException('Freee_Configs__c の参照権限がありません。');
        }
    }
}
