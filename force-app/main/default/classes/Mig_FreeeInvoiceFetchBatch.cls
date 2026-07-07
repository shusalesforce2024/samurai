public with sharing class Mig_FreeeInvoiceFetchBatch implements Database.Batchable<Date>, Database.AllowsCallouts {
    private static final Integer DEFAULT_PER_PAGE = 20;

    private Integer targetYear;
    private Integer startMonth;
    private Integer endMonth;
    private Date rangeStartDate;
    private Date rangeEndDate;
    private Integer perPage;

    public Mig_FreeeInvoiceFetchBatch(Integer targetYear, Integer startMonth, Integer endMonth) {
        this(targetYear, startMonth, endMonth, DEFAULT_PER_PAGE);
    }

    public Mig_FreeeInvoiceFetchBatch(Integer targetYear, Integer startMonth, Integer endMonth, Integer perPage) {
        this.targetYear = targetYear;
        this.startMonth = startMonth;
        this.endMonth = endMonth;
        if (targetYear != null && startMonth != null && endMonth != null && startMonth >= 1 && startMonth <= 12 && endMonth >= 1 && endMonth <= 12) {
            this.rangeStartDate = Date.newInstance(targetYear, startMonth, 1);
            this.rangeEndDate = Date.newInstance(targetYear, endMonth, Date.daysInMonth(targetYear, endMonth));
        }
        this.perPage = perPage == null || perPage < 1 ? DEFAULT_PER_PAGE : perPage;
    }

    public Mig_FreeeInvoiceFetchBatch(Date rangeStartDate, Date rangeEndDate) {
        this(rangeStartDate, rangeEndDate, DEFAULT_PER_PAGE);
    }

    public Mig_FreeeInvoiceFetchBatch(Date rangeStartDate, Date rangeEndDate, Integer perPage) {
        this.rangeStartDate = rangeStartDate;
        this.rangeEndDate = rangeEndDate;
        this.perPage = perPage == null || perPage < 1 ? DEFAULT_PER_PAGE : perPage;
    }

    public Iterable<Date> start(Database.BatchableContext bc) {
        validateParameters();
        return buildTargetDates(Test.isRunningTest());
    }

    @TestVisible
    private List<Date> buildTargetDates(Boolean singleDateOnly) {
        if (singleDateOnly) {
            Integer day = Math.min(20, Date.daysInMonth(rangeStartDate.year(), rangeStartDate.month()));
            Date singleDate = Date.newInstance(rangeStartDate.year(), rangeStartDate.month(), day);
            if (singleDate < rangeStartDate || singleDate > rangeEndDate) {
                singleDate = rangeStartDate;
            }
            return new List<Date>{singleDate};
        }
        List<Date> targetDates = new List<Date>();
        Date currentDate = rangeStartDate;
        while (currentDate <= rangeEndDate) {
            targetDates.add(currentDate);
            currentDate = currentDate.addDays(1);
        }
        return targetDates;
    }

    public void execute(Database.BatchableContext bc, List<Date> scope) {
        for (Date targetDate : scope) {
            Mig_FreeeInvoiceFetchService.fetchDate(targetDate, perPage);
        }
    }

    public void finish(Database.BatchableContext bc) {
        Mig_FreeeInvoiceFetchService.runResolversAndValidation();
    }

    private void validateParameters() {
        if (rangeStartDate == null || rangeEndDate == null) {
            throw new IllegalArgumentException('rangeStartDate/rangeEndDate must be set.');
        }
        if (rangeStartDate.year() < 2000 || rangeEndDate.year() > 2100) {
            throw new IllegalArgumentException('targetYear must be between 2000 and 2100.');
        }
        if (rangeStartDate > rangeEndDate) {
            throw new IllegalArgumentException('startMonth/endMonth must be valid month range.');
        }
    }

}
