for (CronTrigger triggerRecord : [
    SELECT Id
    FROM CronTrigger
    WHERE State IN ('WAITING', 'ACQUIRED', 'PAUSED')
      AND (
          CronJobDetail.Name LIKE 'FreeeInvoiceImport_202606%'
          OR CronJobDetail.Name LIKE 'FreeeInvoiceImport_202607%'
      )
]) {
    System.abortJob(triggerRecord.Id);
}

FreeeInvoiceImportService.ImportResult result = FreeeInvoiceImportService.enqueueBatchImport(
    Date.newInstance(2026, 6, 1),
    Date.newInstance(2026, 7, 31),
    90
);
System.debug('BATCH_JOB=' + result.jobId + ' range=' + result.rangeStartDate + '..' + result.rangeEndDate + ' perPage=' + result.perPage);
