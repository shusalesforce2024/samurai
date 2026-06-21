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
            assertSuccessfulListResponse(response);
            Integer headerCount = countInvoiceHeaders(response.getBody());
            List<String> detailBodies = fetchDetailBodies(response.getBody(), startDate, endDate);
            for (String detailBody : detailBodies) {
                Mig_FreeeInvoiceWorkService.ImportResult detailResult = Mig_FreeeInvoiceWorkService.importBody(detailBody);
                if (detailResult.headerCount > 0) {
                    deleteOutOfPeriodWorks(detailBody, startDate, endDate);
                }
            }
            if (headerCount == 0 || headerCount < perPage) {
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

    private void assertSuccessfulListResponse(HttpResponse response) {
        if (response == null) {
            throw new Mig_FreeeInvoiceWorkService.Mig_FreeeInvoiceMigrationException('freee invoice list response is null.');
        }
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new Mig_FreeeInvoiceWorkService.Mig_FreeeInvoiceMigrationException(
                'freee invoice list fetch failed. status=' + response.getStatusCode() +
                ', body=' + Mig_FreeeInvoiceWorkService.left(response.getBody(), 32000)
            );
        }
    }

    private List<String> fetchDetailBodies(String listResponseBody, Date startDate, Date endDate) {
        List<String> detailBodies = new List<String>();
        for (String freeeInvoiceId : extractInvoiceIdsInPeriod(listResponseBody, startDate, endDate)) {
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

    private Integer countInvoiceHeaders(String body) {
        return extractInvoiceObjects(body).size();
    }

    private List<String> extractInvoiceIdsInPeriod(String body, Date startDate, Date endDate) {
        List<String> invoiceIds = new List<String>();
        for (Object invoiceObject : extractInvoiceObjects(body)) {
            if (!(invoiceObject instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
            Date billingDate = Mig_FreeeInvoiceWorkService.firstDate(
                invoiceMap,
                new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'}
            );
            if (!isInPeriod(billingDate, startDate, endDate)) {
                continue;
            }
            String freeeInvoiceId = Mig_FreeeInvoiceWorkService.firstString(invoiceMap, new List<String>{'id', 'invoice_id'});
            if (!String.isBlank(freeeInvoiceId)) {
                invoiceIds.add(freeeInvoiceId);
            }
        }
        return invoiceIds;
    }

    private void deleteOutOfPeriodWorks(String detailBody, Date startDate, Date endDate) {
        Set<String> outOfPeriodKeys = new Set<String>();
        FreeeConfigService.Config config = FreeeConfigService.getConfig();
        for (Object invoiceObject : extractInvoiceObjects(detailBody)) {
            if (!(invoiceObject instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
            Date billingDate = Mig_FreeeInvoiceWorkService.firstDate(
                invoiceMap,
                new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'}
            );
            if (isInPeriod(billingDate, startDate, endDate)) {
                continue;
            }
            String freeeInvoiceId = Mig_FreeeInvoiceWorkService.firstString(invoiceMap, new List<String>{'id', 'invoice_id'});
            if (!String.isBlank(freeeInvoiceId)) {
                outOfPeriodKeys.add(Mig_FreeeInvoiceWorkService.buildInvoiceExternalKey(config.companyId, freeeInvoiceId));
            }
        }
        if (outOfPeriodKeys.isEmpty()) {
            return;
        }
        delete [
            SELECT Id
            FROM Mig_FreeeInvoiceWork__c
            WHERE ExternalKey__c IN :outOfPeriodKeys
        ];
    }

    private Boolean isInPeriod(Date billingDate, Date startDate, Date endDate) {
        return billingDate != null && billingDate >= startDate && billingDate <= endDate;
    }

    private List<Object> extractInvoiceObjects(String body) {
        if (String.isBlank(body)) {
            return new List<Object>();
        }
        Object parsed = JSON.deserializeUntyped(body);
        if (parsed instanceof List<Object>) {
            return (List<Object>) parsed;
        }
        if (!(parsed instanceof Map<String, Object>)) {
            return new List<Object>();
        }
        Map<String, Object> root = (Map<String, Object>) parsed;
        for (String key : new List<String>{'invoices', 'data', 'records'}) {
            Object value = root.get(key);
            if (value instanceof List<Object>) {
                return (List<Object>) value;
            }
        }
        Object invoiceObject = root.get('invoice');
        if (invoiceObject instanceof Map<String, Object>) {
            return new List<Object>{invoiceObject};
        }
        return new List<Object>();
    }
}
