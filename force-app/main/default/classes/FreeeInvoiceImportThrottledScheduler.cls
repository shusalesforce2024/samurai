public with sharing class FreeeInvoiceImportThrottledScheduler implements Schedulable {
    @TestVisible private static Boolean skipSchedulingForTest = false;

    private Date rangeStartDate;
    private Date rangeEndDate;
    private Date targetDate;
    private Integer page;
    private Integer perPage;

    public FreeeInvoiceImportThrottledScheduler(
        Date rangeStartDate,
        Date rangeEndDate,
        Date targetDate,
        Integer page,
        Integer perPage
    ) {
        this.rangeStartDate = rangeStartDate;
        this.rangeEndDate = rangeEndDate;
        this.targetDate = targetDate;
        this.page = page == null || page < 1 ? 1 : page;
        this.perPage = Mig_FreeeInvoiceFetchService.normalizeThrottledPerPage(perPage);
    }

    public void execute(SchedulableContext context) {
        System.enqueueJob(new FreeeInvoiceImportThrottledQueueable(
            rangeStartDate,
            rangeEndDate,
            targetDate,
            page,
            perPage
        ));
    }

    public static Id scheduleImport(Date rangeStartDate, Date rangeEndDate, Integer perPage) {
        validateRange(rangeStartDate, rangeEndDate);
        return scheduleNextRun(
            rangeStartDate,
            rangeEndDate,
            rangeStartDate,
            1,
            Mig_FreeeInvoiceFetchService.normalizeThrottledPerPage(perPage),
            1
        );
    }

    public static Id scheduleNextRun(
        Date rangeStartDate,
        Date rangeEndDate,
        Date targetDate,
        Integer page,
        Integer perPage,
        Integer delayMinutes
    ) {
        if (Test.isRunningTest() && skipSchedulingForTest) {
            return UserInfo.getUserId();
        }

        abortWaitingInvoiceImportSchedules();

        DateTime runAt = DateTime.now().addMinutes(delayMinutes == null || delayMinutes < 1 ? 1 : delayMinutes);
        String jobName = 'FreeeInvoiceImport_' +
            String.valueOf(targetDate).replace('-', '') +
            '_p' + String.valueOf(page) +
            '_' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        return System.schedule(
            jobName,
            cronFor(runAt),
            new FreeeInvoiceImportThrottledScheduler(rangeStartDate, rangeEndDate, targetDate, page, perPage)
        );
    }

    private static String cronFor(DateTime runAt) {
        return String.valueOf(runAt.second()) + ' ' +
            String.valueOf(runAt.minute()) + ' ' +
            String.valueOf(runAt.hour()) + ' ' +
            String.valueOf(runAt.day()) + ' ' +
            String.valueOf(runAt.month()) + ' ? ' +
            String.valueOf(runAt.year());
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

    @TestVisible
    private static Integer abortWaitingInvoiceImportSchedules() {
        List<CronTrigger> triggers = [
            SELECT Id,
                   CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'FreeeInvoiceImport%'
              AND State IN ('WAITING', 'PAUSED')
        ];
        Integer abortedCount = 0;
        for (CronTrigger triggerRecord : triggers) {
            if (!isThrottledOneTimeImportJob(triggerRecord.CronJobDetail.Name)) {
                continue;
            }
            System.abortJob(triggerRecord.Id);
            abortedCount++;
        }
        return abortedCount;
    }

    private static Boolean isThrottledOneTimeImportJob(String jobName) {
        return !String.isBlank(jobName) &&
            jobName.startsWith('FreeeInvoiceImport_') &&
            jobName.contains('_p');
    }
}
