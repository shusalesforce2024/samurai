public with sharing class FreeeInvoiceImportManualController {
    public Date rangeStartDate { get; set; }
    public Date rangeEndDate { get; set; }
    public Integer perPage { get; set; }
    public String message { get; private set; }
    public String errorMessage { get; private set; }

    public FreeeInvoiceImportManualController() {
        FreeeInvoiceImportService.ImportRequest request =
            FreeeInvoiceImportService.buildDefaultRequest(Date.today());
        rangeStartDate = request.rangeStartDate;
        rangeEndDate = request.rangeEndDate;
        perPage = request.perPage;
    }

    public PageReference runImport() {
        message = null;
        errorMessage = null;
        try {
            FreeeInvoiceImportService.ImportResult result =
                FreeeInvoiceImportService.enqueueImport(rangeStartDate, rangeEndDate, perPage);
            message = 'freee invoice import job started. JobId=' + String.valueOf(result.jobId)
                + ', range=' + String.valueOf(result.rangeStartDate)
                + ' to ' + String.valueOf(result.rangeEndDate)
                + ', perPage=' + String.valueOf(result.perPage);
        } catch (Exception e) {
            errorMessage = e.getMessage();
        }
        return null;
    }

    public Boolean getHasMessage() {
        return !String.isBlank(message);
    }

    public Boolean getHasError() {
        return !String.isBlank(errorMessage);
    }
}
