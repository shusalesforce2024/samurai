public with sharing class Mig_FreeeInvoiceFetchBatch implements Database.Batchable<Integer>, Database.AllowsCallouts {
    private static final Integer DEFAULT_PER_PAGE = 50;
    private static final Integer MAX_PAGES_PER_EXECUTE = 200;

    private Integer targetYear;
    private Integer startMonth;
    private Integer endMonth;
    private Integer perPage;

    public Mig_FreeeInvoiceFetchBatch(Integer targetYear, Integer startMonth, Integer endMonth) {
        this(targetYear, startMonth, endMonth, DEFAULT_PER_PAGE);
    }

    public Mig_FreeeInvoiceFetchBatch(Integer targetYear, Integer startMonth, Integer endMonth, Integer perPage) {
        this.targetYear = targetYear;
        this.startMonth = startMonth;
        this.endMonth = endMonth;
        this.perPage = perPage == null || perPage < 1 ? DEFAULT_PER_PAGE : perPage;
    }

    public Iterable<Integer> start(Database.BatchableContext bc) {
        validateParameters();
        return new List<Integer>{1};
    }

    public void execute(Database.BatchableContext bc, List<Integer> scope) {
        Date startDate = Date.newInstance(targetYear, startMonth, 1);
        Date endDate = Date.newInstance(targetYear, endMonth, Date.daysInMonth(targetYear, endMonth));
        Integer page = 1;
        Integer emptyPages = 0;
        while (page <= MAX_PAGES_PER_EXECUTE && emptyPages == 0) {
            HttpResponse response = FreeeInvoiceService.getInvoices(startDate, endDate, page, perPage);
            List<String> detailBodies = fetchDetailBodies(response.getBody());
            Mig_FreeeInvoiceWorkService.ImportResult result = Mig_FreeeInvoiceWorkService.importResponse(response);
            for (String detailBody : detailBodies) {
                Mig_FreeeInvoiceWorkService.importBody(detailBody);
            }
            if (result.headerCount == 0 || result.headerCount < perPage) {
                emptyPages++;
            }
            page++;
        }
    }

    public void finish(Database.BatchableContext bc) {
        Mig_FreeeInvoiceReferenceResolver.resolveAll();
        Mig_FreeeInvoiceProductResolver.resolveAll();
        Mig_FreeeInvoiceValidator.validateAll();
    }

    private void validateParameters() {
        if (targetYear == null || targetYear < 2000 || targetYear > 2100) {
            throw new IllegalArgumentException('targetYear must be between 2000 and 2100.');
        }
        if (startMonth == null || endMonth == null || startMonth < 1 || endMonth > 12 || startMonth > endMonth) {
            throw new IllegalArgumentException('startMonth/endMonth must be valid month range.');
        }
    }

    private List<String> fetchDetailBodies(String listResponseBody) {
        List<String> detailBodies = new List<String>();
        for (String freeeInvoiceId : Mig_FreeeInvoiceWorkService.extractInvoiceIds(listResponseBody)) {
            Decimal invoiceId = Mig_FreeeInvoiceWorkService.toDecimal(freeeInvoiceId);
            if (invoiceId == null) {
                continue;
            }
            HttpResponse detailResponse = FreeeInvoiceService.getInvoice(invoiceId);
            if (detailResponse == null) {
                throw new Mig_FreeeInvoiceWorkService.Mig_FreeeInvoiceMigrationException('freee invoice detail response is null.');
            }
            if (detailResponse.getStatusCode() < 200 || detailResponse.getStatusCode() >= 300) {
                throw new Mig_FreeeInvoiceWorkService.Mig_FreeeInvoiceMigrationException(
                    'freee invoice detail fetch failed. invoiceId=' + freeeInvoiceId +
                    ', status=' + detailResponse.getStatusCode() +
                    ', body=' + Mig_FreeeInvoiceWorkService.left(detailResponse.getBody(), 32000)
                );
            }
            detailBodies.add(detailResponse.getBody());
        }
        return detailBodies;
    }
}
