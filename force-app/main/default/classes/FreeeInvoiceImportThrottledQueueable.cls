public with sharing class FreeeInvoiceImportThrottledQueueable implements Queueable, Database.AllowsCallouts {
    private static final Integer RETRY_DELAY_MINUTES = 30;
    private static final Integer NEXT_PAGE_DELAY_MINUTES = 60;

    private Date rangeStartDate;
    private Date rangeEndDate;
    private Date targetDate;
    private Integer page;
    private Integer perPage;

    public FreeeInvoiceImportThrottledQueueable(
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

    public void execute(QueueableContext context) {
        try {
            Mig_FreeeInvoiceFetchService.FetchPageResult result =
                Mig_FreeeInvoiceFetchService.fetchPage(targetDate, page, perPage);

            Date nextDate = targetDate;
            Integer nextPage = page + 1;
            if (result.invoiceCount < perPage) {
                nextDate = targetDate.addDays(1);
                nextPage = 1;
            }

            if (nextDate <= rangeEndDate) {
                FreeeInvoiceImportThrottledScheduler.scheduleNextRun(
                    rangeStartDate,
                    rangeEndDate,
                    nextDate,
                    nextPage,
                    perPage,
                    NEXT_PAGE_DELAY_MINUTES
                );
            } else {
                Mig_FreeeInvoiceFetchService.runResolversAndValidation();
            }
        } catch (Mig_FreeeInvoiceFetchService.FreeeRateLimitException e) {
            Integer retryDelayMinutes = e.retryAfterMinutes == null
                ? RETRY_DELAY_MINUTES
                : Math.max(RETRY_DELAY_MINUTES, e.retryAfterMinutes);
            FreeeInvoiceImportThrottledScheduler.scheduleNextRun(
                rangeStartDate,
                rangeEndDate,
                targetDate,
                page,
                perPage,
                retryDelayMinutes
            );
        }
    }
}
