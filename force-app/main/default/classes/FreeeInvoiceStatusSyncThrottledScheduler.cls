public with sharing class FreeeInvoiceStatusSyncThrottledScheduler implements Schedulable {
    private static final String JOB_NAME_PREFIX = 'FreeeInvoiceStatusSyncChunk_';
    @TestVisible static Boolean skipSchedulingForTest = false;
    @TestVisible static Boolean skipActiveChainCheckForTest = false;
    @TestVisible static Integer lastRequestedDelayMinutes;

    private Date runDate;
    private List<Id> remainingInvoiceIds;
    private Integer processedCount;
    private Boolean dailyCapReached;

    public FreeeInvoiceStatusSyncThrottledScheduler(
        Date runDate,
        List<Id> remainingInvoiceIds,
        Integer processedCount,
        Boolean dailyCapReached
    ) {
        this.runDate = runDate;
        this.remainingInvoiceIds = remainingInvoiceIds;
        this.processedCount = processedCount;
        this.dailyCapReached = dailyCapReached;
    }

    public void execute(SchedulableContext context) {
        System.enqueueJob(new FreeeInvoiceStatusSyncThrottledQueueable(
            runDate,
            remainingInvoiceIds,
            processedCount,
            dailyCapReached
        ));
    }

    public static Id scheduleNextRun(
        Date runDate,
        List<Id> remainingInvoiceIds,
        Integer processedCount,
        Boolean dailyCapReached,
        Integer delayMinutes
    ) {
        Integer effectiveDelay = delayMinutes == null || delayMinutes < 1 ? 1 : delayMinutes;
        lastRequestedDelayMinutes = effectiveDelay;
        if (Test.isRunningTest() && skipSchedulingForTest) {
            return UserInfo.getUserId();
        }

        abortWaitingChunkSchedules();

        DateTime runAt = System.now().addMinutes(effectiveDelay);
        String jobName = JOB_NAME_PREFIX
            + runAt.formatGmt('yyyyMMdd_HHmmss')
            + '_'
            + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        return System.schedule(
            jobName,
            cronFor(runAt),
            new FreeeInvoiceStatusSyncThrottledScheduler(
                runDate,
                remainingInvoiceIds,
                processedCount,
                dailyCapReached
            )
        );
    }

    public static Boolean hasActiveChain() {
        if (Test.isRunningTest() && skipActiveChainCheckForTest) {
            return false;
        }

        String jobNamePattern = JOB_NAME_PREFIX + '%';
        if ([
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :jobNamePattern
              AND State IN ('WAITING', 'ACQUIRED', 'PAUSED')
        ] > 0) {
            return true;
        }

        return [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'FreeeInvoiceStatusSyncThrottledQueueable'
              AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
        ] > 0;
    }

    @TestVisible
    private static Integer abortWaitingChunkSchedules() {
        String jobNamePattern = JOB_NAME_PREFIX + '%';
        List<CronTrigger> triggers = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :jobNamePattern
              AND State IN ('WAITING', 'PAUSED')
        ];
        for (CronTrigger triggerRecord : triggers) {
            System.abortJob(triggerRecord.Id);
        }
        return triggers.size();
    }

    @TestVisible
    private static String cronFor(DateTime runAt) {
        return String.valueOf(runAt.second()) + ' '
            + String.valueOf(runAt.minute()) + ' '
            + String.valueOf(runAt.hour()) + ' '
            + String.valueOf(runAt.day()) + ' '
            + String.valueOf(runAt.month()) + ' ? '
            + String.valueOf(runAt.year());
    }
}
