public with sharing class FreeeInvoiceCreateQueueable
    implements Queueable, Database.AllowsCallouts {
    private List<Id> invoiceIds;

    public FreeeInvoiceCreateQueueable(List<Id> invoiceIds) {
        this.invoiceIds = invoiceIds == null ? new List<Id>() : new List<Id>(invoiceIds);
    }

    public void execute(QueueableContext context) {
        for (Id invoiceId : invoiceIds) {
            try {
                FreeeInvoiceFacade.createInvoice(invoiceId);
            } catch (Exception e) {
                System.debug('freee請求書自動作成に失敗しました。InvoiceId='
                    + String.valueOf(invoiceId)
                    + ', Error='
                    + e.getMessage());
            }
        }
    }
}
