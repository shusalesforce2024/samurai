public with sharing class FreeeInvoiceImportService {
    public static final Integer DEFAULT_PER_PAGE = 200;

    public class ImportRequest {
        public Date rangeStartDate;
        public Date rangeEndDate;
        public Integer perPage;

        public ImportRequest(Date rangeStartDate, Date rangeEndDate, Integer perPage) {
            this.rangeStartDate = rangeStartDate;
            this.rangeEndDate = rangeEndDate;
            this.perPage = perPage;
        }
    }

    public class ImportResult {
        public Id jobId;
        public Date rangeStartDate;
        public Date rangeEndDate;
        public Integer perPage;

        public ImportResult(Id jobId, Date rangeStartDate, Date rangeEndDate, Integer perPage) {
            this.jobId = jobId;
            this.rangeStartDate = rangeStartDate;
            this.rangeEndDate = rangeEndDate;
            this.perPage = perPage;
        }
    }

    public static ImportRequest buildDefaultRequest(Date runDate) {
        Date safeRunDate = runDate == null ? Date.today() : runDate;
        Date currentMonthStart = Date.newInstance(safeRunDate.year(), safeRunDate.month(), 1);
        Date previousMonthStart = currentMonthStart.addMonths(-1);
        Date currentMonthEnd = currentMonthStart.addMonths(1).addDays(-1);
        return new ImportRequest(previousMonthStart, currentMonthEnd, DEFAULT_PER_PAGE);
    }

    public static ImportResult enqueueDefaultImport() {
        ImportRequest request = buildDefaultRequest(Date.today());
        return enqueueImport(request.rangeStartDate, request.rangeEndDate, request.perPage);
    }

    public static ImportResult enqueueImport(Date rangeStartDate, Date rangeEndDate, Integer perPage) {
        validateRange(rangeStartDate, rangeEndDate);
        Integer normalizedPerPage = normalizePerPage(perPage);
        Id jobId = Database.executeBatch(
            new Mig_FreeeInvoiceFetchBatch(rangeStartDate, rangeEndDate, normalizedPerPage),
            1
        );
        return new ImportResult(jobId, rangeStartDate, rangeEndDate, normalizedPerPage);
    }

    public static Integer abortContractRenewalInvoiceSchedules() {
        List<CronTrigger> triggers = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'ContractRenewalInvoiceBatch%'
              AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
        ];
        for (CronTrigger triggerRecord : triggers) {
            System.abortJob(triggerRecord.Id);
        }
        return triggers.size();
    }

    private static void validateRange(Date rangeStartDate, Date rangeEndDate) {
        if (rangeStartDate == null || rangeEndDate == null) {
            throw new IllegalArgumentException('rangeStartDate and rangeEndDate are required.');
        }
        if (rangeStartDate > rangeEndDate) {
            throw new IllegalArgumentException('rangeStartDate must be before or equal to rangeEndDate.');
        }
        if (rangeStartDate.year() < 2000 || rangeEndDate.year() > 2100) {
            throw new IllegalArgumentException('range must be between 2000 and 2100.');
        }
    }

    private static Integer normalizePerPage(Integer perPage) {
        if (perPage == null || perPage < 1) {
            return DEFAULT_PER_PAGE;
        }
        return Math.min(perPage, 3000);
    }
}
