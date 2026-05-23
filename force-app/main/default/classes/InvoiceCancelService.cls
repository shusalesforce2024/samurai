public with sharing class InvoiceCancelService {
    private static final String CANCELLED = '取消済';
    private static final String STATUS_SUCCESS = 'Success';
    private static final String STATUS_FAILED = 'Failed';
    private static final String INVOICE_STATUS_CANCELLED = '取消済';

    public static void cancelInvoice(Id invoiceId) {
        if (invoiceId == null) {
            throw new AuraHandledException('請求IDが指定されていません。');
        }

        Invoice__c invoiceRecord = getInvoice(invoiceId);
        if (invoiceRecord.CancelStatus__c == CANCELLED) {
            return;
        }

        if (invoiceRecord.Sent_To_Freee__c == true && invoiceRecord.Freee_Invoice_Id__c != null) {
            try {
                FreeeInvoiceCancelService.cancelInvoice(invoiceRecord);
            } catch (Exception e) {
                update new Invoice__c(
                    Id = invoiceRecord.Id,
                    Freee_Sync_Status__c = STATUS_FAILED,
                    Freee_Sync_Message__c = e.getMessage(),
                    Freee_Last_Synced_At__c = System.now()
                );
                throw e;
            }
        }

        update new Invoice__c(
            Id = invoiceRecord.Id,
            CancelStatus__c = CANCELLED,
            Freee_Sync_Status__c = STATUS_SUCCESS,
            Freee_Sync_Message__c = null,
            Freee_Last_Synced_At__c = System.now()
        );

        List<ContractPeriod__c> periodsToUpdate = new List<ContractPeriod__c>();
        for (ContractPeriod__c periodRecord : [
            SELECT Id
            FROM ContractPeriod__c
            WHERE RelatedInvoice__c = :invoiceId
        ]) {
            periodsToUpdate.add(new ContractPeriod__c(
                Id = periodRecord.Id,
                InvoiceCreationStatus__c = INVOICE_STATUS_CANCELLED
            ));
        }
        if (!periodsToUpdate.isEmpty()) {
            update periodsToUpdate;
        }

        List<ContractLineItem__c> linesToUpdate = new List<ContractLineItem__c>();
        for (ContractLineItem__c line : [
            SELECT Id
            FROM ContractLineItem__c
            WHERE RelatedInvoice__c = :invoiceId
        ]) {
            linesToUpdate.add(new ContractLineItem__c(
                Id = line.Id,
                InvoiceStatus__c = INVOICE_STATUS_CANCELLED
            ));
        }
        if (!linesToUpdate.isEmpty()) {
            update linesToUpdate;
        }
    }

    private static Invoice__c getInvoice(Id invoiceId) {
        List<Invoice__c> invoices = [
            SELECT Id,
                   CancelStatus__c,
                   Freee_Invoice_Id__c,
                   Sent_To_Freee__c
            FROM Invoice__c
            WHERE Id = :invoiceId
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            throw new AuraHandledException('対象の請求が見つかりません。');
        }
        return invoices[0];
    }
}
