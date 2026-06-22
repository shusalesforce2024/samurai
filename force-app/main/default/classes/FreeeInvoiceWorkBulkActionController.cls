public with sharing class FreeeInvoiceWorkBulkActionController {
    private ApexPages.StandardSetController standardSetController;

    public Summary summary { get; private set; }
    public String errorMessage { get; private set; }

    public class Summary {
        public Integer selectedCount { get; set; }
        public Integer readyCount { get; set; }
        public Integer skippedCount { get; set; }
        public Integer importedCount { get; set; }
        public Integer needsReviewCount { get; set; }
        public Integer errorCount { get; set; }
        public String message { get; set; }

        public Summary() {
            selectedCount = 0;
            readyCount = 0;
            skippedCount = 0;
            importedCount = 0;
            needsReviewCount = 0;
            errorCount = 0;
        }
    }

    public FreeeInvoiceWorkBulkActionController() {
    }

    public FreeeInvoiceWorkBulkActionController(ApexPages.StandardSetController standardSetController) {
        this.standardSetController = standardSetController;
    }

    public PageReference finalizeSelected() {
        summary = new Summary();
        try {
            List<Id> selectedIds = getSelectedWorkIds();
            summary.selectedCount = selectedIds.size();
            if (selectedIds.isEmpty()) {
                errorMessage = '本反映対象のfreee請求書取込Workを選択してください。';
                return null;
            }

            List<Id> readyIds = getReadyWorkIds(selectedIds);
            summary.readyCount = readyIds.size();
            summary.skippedCount = selectedIds.size() - readyIds.size();
            if (readyIds.isEmpty()) {
                errorMessage = '反映可能なfreee請求書取込Workがありません。ImportStatus__c が反映可能のレコードを選択してください。';
                return null;
            }

            Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(readyIds);
            summarizeCurrentStatuses(readyIds);
            summary.message = '一括本反映が完了しました。';
        } catch (Exception e) {
            errorMessage = e.getMessage();
        }
        return null;
    }

    public PageReference validateSelected() {
        summary = new Summary();
        try {
            List<Id> selectedIds = getSelectedWorkIds();
            summary.selectedCount = selectedIds.size();
            if (selectedIds.isEmpty()) {
                errorMessage = '再検証対象のfreee請求書取込Workを選択してください。';
                return null;
            }

            Mig_FreeeInvoiceValidator.validateAll();
            summarizeCurrentStatuses(selectedIds);
            summary.message = '再検証が完了しました。';
        } catch (Exception e) {
            errorMessage = e.getMessage();
        }
        return null;
    }

    public Boolean getHasError() {
        return !String.isBlank(errorMessage);
    }

    public Boolean getHasSummary() {
        return summary != null;
    }

    private List<Id> getReadyWorkIds(List<Id> selectedIds) {
        List<Id> readyIds = new List<Id>();
        if (selectedIds == null || selectedIds.isEmpty()) {
            return readyIds;
        }
        for (Mig_FreeeInvoiceWork__c workRecord : [
            SELECT Id
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id IN :selectedIds
              AND ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
        ]) {
            readyIds.add(workRecord.Id);
        }
        return readyIds;
    }

    private void summarizeCurrentStatuses(List<Id> workIds) {
        if (workIds == null || workIds.isEmpty()) {
            return;
        }
        for (AggregateResult result : [
            SELECT ImportStatus__c statusName, COUNT(Id) recordCount
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id IN :workIds
            GROUP BY ImportStatus__c
        ]) {
            String statusName = (String) result.get('statusName');
            Integer recordCount = (Integer) result.get('recordCount');
            if (statusName == Mig_FreeeInvoiceWorkService.STATUS_IMPORTED) {
                summary.importedCount += recordCount;
            } else if (statusName == Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW) {
                summary.needsReviewCount += recordCount;
            } else if (statusName == Mig_FreeeInvoiceWorkService.STATUS_ERROR) {
                summary.errorCount += recordCount;
            }
        }
    }

    private List<Id> getSelectedWorkIds() {
        List<Id> workIds = new List<Id>();

        if (standardSetController != null) {
            for (SObject selectedRecord : standardSetController.getSelected()) {
                Id selectedId = (Id) selectedRecord.get('Id');
                if (selectedId != null) {
                    workIds.add(selectedId);
                }
            }
        }

        if (workIds.isEmpty()) {
            addIdsFromParameter(workIds, ApexPages.currentPage().getParameters().get('selected'));
            addIdsFromParameter(workIds, ApexPages.currentPage().getParameters().get('recordKeys'));
            addIdsFromParameter(workIds, ApexPages.currentPage().getParameters().get('ids'));
            addIdsFromParameter(workIds, ApexPages.currentPage().getParameters().get('selectedIds'));
            addIdsFromParameter(workIds, ApexPages.currentPage().getParameters().get('id'));
        }

        return workIds;
    }

    private static void addIdsFromParameter(List<Id> workIds, String rawValue) {
        if (String.isBlank(rawValue)) {
            return;
        }

        String normalizedValue = rawValue
            .replace('[', '')
            .replace(']', '')
            .replace('"', '')
            .replace('\'', '')
            .replace(';', ',');

        for (String rawId : normalizedValue.split(',')) {
            String candidate = rawId == null ? null : rawId.trim();
            if (String.isBlank(candidate)) {
                continue;
            }
            try {
                workIds.add((Id) candidate);
            } catch (Exception e) {
                // Ignore invalid URL parameter values and let the page report if no valid IDs remain.
            }
        }
    }
}
