public with sharing class InvoiceDefaultsService {
    @TestVisible
    private static final Id DEFAULT_COMPANY_CONTACT_USER_ID = '005RB00000eIlkbYAC';

    public static void applyBeforeInsert(List<Invoice__c> invoices) {
        if (invoices == null || invoices.isEmpty()) {
            return;
        }

        Id defaultUserId = resolveDefaultCompanyContactUserId();
        if (defaultUserId == null) {
            return;
        }

        for (Invoice__c invoiceRecord : invoices) {
            if (invoiceRecord.CompanyContactUser__c == null) {
                invoiceRecord.CompanyContactUser__c = defaultUserId;
            }
        }
    }

    private static Id resolveDefaultCompanyContactUserId() {
        List<User> users = [
            SELECT Id
            FROM User
            WHERE Id = :DEFAULT_COMPANY_CONTACT_USER_ID
            AND IsActive = true
            LIMIT 1
        ];

        if (!users.isEmpty()) {
            return users[0].Id;
        }

        return Test.isRunningTest() ? UserInfo.getUserId() : null;
    }
}
