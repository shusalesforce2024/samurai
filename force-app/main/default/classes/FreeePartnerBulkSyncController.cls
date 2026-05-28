public with sharing class FreeePartnerBulkSyncController {
    private ApexPages.StandardSetController standardSetController;

    public FreeePartnerBulkSyncService.Summary summary { get; private set; }
    public String errorMessage { get; private set; }

    public FreeePartnerBulkSyncController() {
    }

    public FreeePartnerBulkSyncController(ApexPages.StandardSetController standardSetController) {
        this.standardSetController = standardSetController;
    }

    public PageReference sync() {
        try {
            summary = FreeePartnerBulkSyncService.syncPartners(getSelectedAccountIds());
        } catch (Exception e) {
            errorMessage = e.getMessage();
        }
        return null;
    }

    public Boolean getHasError() {
        return !String.isBlank(errorMessage);
    }

    public Boolean getHasResults() {
        return summary != null && summary.results != null && !summary.results.isEmpty();
    }

    private List<Id> getSelectedAccountIds() {
        List<Id> accountIds = new List<Id>();

        if (standardSetController != null) {
            for (SObject selectedRecord : standardSetController.getSelected()) {
                Id selectedId = (Id) selectedRecord.get('Id');
                if (selectedId != null) {
                    accountIds.add(selectedId);
                }
            }
        }

        if (accountIds.isEmpty()) {
            addIdsFromParameter(accountIds, ApexPages.currentPage().getParameters().get('selected'));
            addIdsFromParameter(accountIds, ApexPages.currentPage().getParameters().get('recordKeys'));
            addIdsFromParameter(accountIds, ApexPages.currentPage().getParameters().get('ids'));
            addIdsFromParameter(accountIds, ApexPages.currentPage().getParameters().get('selectedIds'));
            addIdsFromParameter(accountIds, ApexPages.currentPage().getParameters().get('id'));
        }

        return accountIds;
    }

    private static void addIdsFromParameter(List<Id> accountIds, String rawValue) {
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
                accountIds.add((Id) candidate);
            } catch (Exception e) {
                // Ignore invalid URL parameter values and let the service report if no valid IDs remain.
            }
        }
    }
}
