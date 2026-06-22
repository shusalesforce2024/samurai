public with sharing class FreeeInvoiceImportScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        FreeeInvoiceImportService.enqueueDefaultImport();
    }
}
