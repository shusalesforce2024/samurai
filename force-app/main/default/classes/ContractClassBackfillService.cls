public without sharing class ContractClassBackfillService {
    private static final String STATUS_ACTIVATED = 'Activated';
    private static final Set<String> EXCLUDED_LINE_TYPES = new Set<String>{ '初期費用' };

    public class Result {
        public Integer targetContracts = 0;
        public Integer invoiceLineCandidates = 0;
        public Integer updatableContracts = 0;
        public Integer updatedContracts = 0;
        public Integer unresolvedContracts = 0;
        public List<String> messages = new List<String>();
    }

    private class Candidate {
        Id contractId;
        Date billingDate;
        Datetime invoiceCreatedDate;
        String productCategory;
        String planCategory;
        Decimal accountCount;
        Decimal amountWithTax;
        String evidence;
        Integer score;
    }

    public static Result dryRun() {
        return run(true);
    }

    public static Result executeUpdate() {
        return run(false);
    }

    public static Result run(Boolean dryRun) {
        Result result = new Result();
        List<Contract__c> targets = [
            SELECT Id,
                   Name,
                   ContractName__c,
                   ProductCategory__c,
                   PlanCategory__c,
                   AccountCount__c
            FROM Contract__c
            WHERE Status__c = :STATUS_ACTIVATED
              AND (
                  ProductCategory__c = null
                  OR PlanCategory__c = null
                  OR AccountCount__c = null
              )
        ];
        result.targetContracts = targets.size();
        if (targets.isEmpty()) {
            result.messages.add('対象の有効契約はありません。');
            return result;
        }

        Set<Id> contractIds = new Map<Id, Contract__c>(targets).keySet();
        Map<Id, Candidate> bestByContractId = new Map<Id, Candidate>();
        for (InvoiceLine__c line : [
            SELECT Id,
                   Name,
                   Description__c,
                   Quantity__c,
                   AmountWithTax__c,
                   Line_Amount__c,
                   LineType__c,
                   ProductMaster__r.Name,
                   Invoice__r.ParentContract__c,
                   Invoice__r.Billing_Date__c,
                   Invoice__r.CreatedDate,
                   Invoice__r.CancelStatus__c
            FROM InvoiceLine__c
            WHERE Invoice__r.ParentContract__c IN :contractIds
              AND Invoice__r.ParentContract__c != null
            ORDER BY Invoice__r.Billing_Date__c DESC NULLS LAST,
                     Invoice__r.CreatedDate DESC,
                     AmountWithTax__c DESC NULLS LAST
        ]) {
            if (line.Invoice__r == null || line.Invoice__r.ParentContract__c == null) {
                continue;
            }
            if (EXCLUDED_LINE_TYPES.contains(line.LineType__c)) {
                continue;
            }
            if (String.valueOf(line.Invoice__r.CancelStatus__c).contains('取消')) {
                continue;
            }

            Candidate candidate = buildCandidate(line);
            result.invoiceLineCandidates++;
            if (!isUsable(candidate)) {
                continue;
            }

            Candidate currentBest = bestByContractId.get(candidate.contractId);
            if (currentBest == null || isBetter(candidate, currentBest)) {
                bestByContractId.put(candidate.contractId, candidate);
            }
        }

        List<Contract__c> updates = new List<Contract__c>();
        for (Contract__c contractRecord : targets) {
            Candidate candidate = bestByContractId.get(contractRecord.Id);
            if (candidate == null) {
                result.unresolvedContracts++;
                result.messages.add(formatMessage(contractRecord, '判定可能な請求明細なし'));
                continue;
            }

            Contract__c updateRecord = new Contract__c(Id = contractRecord.Id);
            Boolean hasChange = false;
            if (String.isBlank(contractRecord.ProductCategory__c) && candidate.productCategory != null) {
                updateRecord.ProductCategory__c = candidate.productCategory;
                hasChange = true;
            }
            if (String.isBlank(contractRecord.PlanCategory__c) && candidate.planCategory != null) {
                updateRecord.PlanCategory__c = candidate.planCategory;
                hasChange = true;
            }
            if (contractRecord.AccountCount__c == null && candidate.accountCount != null) {
                updateRecord.AccountCount__c = candidate.accountCount;
                hasChange = true;
            }

            if (hasChange) {
                updates.add(updateRecord);
                result.updatableContracts++;
                result.messages.add(formatMessage(contractRecord, candidate.evidence));
            } else {
                result.unresolvedContracts++;
                result.messages.add(formatMessage(contractRecord, '空項目を補完できる値なし'));
            }
        }

        if (!dryRun && !updates.isEmpty()) {
            Database.SaveResult[] saveResults = Database.update(updates, false);
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) {
                    result.updatedContracts++;
                } else {
                    result.messages.add(
                        '更新失敗: ' + updates[i].Id + ' / ' + saveResults[i].getErrors()[0].getMessage()
                    );
                }
            }
        }

        System.debug(LoggingLevel.INFO, JSON.serializePretty(result));
        return result;
    }

    private static Candidate buildCandidate(InvoiceLine__c line) {
        String lineText = joinText(new List<String>{
            line.Name,
            line.Description__c
        });
        String productMasterText = line.ProductMaster__r == null ? null : line.ProductMaster__r.Name;
        String evidenceText = joinText(new List<String>{ lineText, productMasterText });

        Candidate candidate = new Candidate();
        candidate.contractId = line.Invoice__r.ParentContract__c;
        candidate.billingDate = line.Invoice__r.Billing_Date__c;
        candidate.invoiceCreatedDate = line.Invoice__r.CreatedDate;
        candidate.productCategory = coalesce(
            detectProductCategory(lineText),
            detectProductCategory(productMasterText)
        );
        candidate.planCategory = coalesce(
            detectPlanCategory(lineText),
            detectPlanCategory(productMasterText)
        );
        candidate.accountCount = coalesceDecimal(parseAccountCount(lineText), line.Quantity__c);
        candidate.amountWithTax = line.AmountWithTax__c == null ? line.Line_Amount__c : line.AmountWithTax__c;
        candidate.score = calculateScore(candidate, line);
        candidate.evidence =
            '商品カテゴリ=' + nullToDash(candidate.productCategory)
            + ', プランカテゴリ=' + nullToDash(candidate.planCategory)
            + ', アカウント数=' + (candidate.accountCount == null ? '-' : String.valueOf(candidate.accountCount))
            + ', 根拠=' + evidenceText;
        return candidate;
    }

    private static Boolean isUsable(Candidate candidate) {
        return candidate.productCategory != null
            || candidate.planCategory != null
            || candidate.accountCount != null;
    }

    private static Boolean isBetter(Candidate candidate, Candidate currentBest) {
        if (candidate.score != currentBest.score) {
            return candidate.score > currentBest.score;
        }
        if (candidate.billingDate != currentBest.billingDate) {
            if (candidate.billingDate == null) {
                return false;
            }
            if (currentBest.billingDate == null) {
                return true;
            }
            return candidate.billingDate > currentBest.billingDate;
        }
        if (candidate.invoiceCreatedDate != currentBest.invoiceCreatedDate) {
            if (candidate.invoiceCreatedDate == null) {
                return false;
            }
            if (currentBest.invoiceCreatedDate == null) {
                return true;
            }
            return candidate.invoiceCreatedDate > currentBest.invoiceCreatedDate;
        }
        Decimal candidateAmount = candidate.amountWithTax == null ? 0 : candidate.amountWithTax;
        Decimal currentAmount = currentBest.amountWithTax == null ? 0 : currentBest.amountWithTax;
        return candidateAmount > currentAmount;
    }

    private static Integer calculateScore(Candidate candidate, InvoiceLine__c line) {
        Integer score = 0;
        if (candidate.productCategory != null) {
            score += 100;
        }
        if (candidate.planCategory != null) {
            score += 50;
        }
        if (candidate.accountCount != null) {
            score += 20;
        }
        if (line.ProductMaster__c != null) {
            score += 10;
        }
        if (line.LineType__c == '継続費用' || line.LineType__c == '年間利用料') {
            score += 10;
        }
        return score;
    }

    private static String detectProductCategory(String text) {
        String normalized = normalize(text);
        if (normalized.contains('knockknockai') || normalized.contains('knockknock')) {
            return 'knock knock AI';
        }
        if (normalized.contains('rendery') || normalized.contains('rendary')) {
            return 'Rendery';
        }
        if (normalized.contains('visioal') || normalized.contains('visual')) {
            return 'VISIOAL';
        }
        if (normalized.contains('受託') || normalized.contains('開発')) {
            return '受託開発';
        }
        return null;
    }

    private static String detectPlanCategory(String text) {
        String normalized = normalize(text);
        if (normalized.contains('enterprise')) {
            return 'Enterprise';
        }
        if (normalized.contains('basic')) {
            return 'Basic';
        }
        if (normalized.contains('pro')) {
            return 'Pro';
        }
        return null;
    }

    private static Decimal parseAccountCount(String text) {
        if (String.isBlank(text) || !text.contains('アカウント')) {
            return null;
        }
        Matcher matcher = Pattern.compile('(\\d+)\\s*アカウント').matcher(text);
        if (matcher.find()) {
            return Decimal.valueOf(matcher.group(1));
        }
        return null;
    }

    private static String coalesce(String firstValue, String secondValue) {
        return firstValue != null ? firstValue : secondValue;
    }

    private static Decimal coalesceDecimal(Decimal firstValue, Decimal secondValue) {
        return firstValue != null ? firstValue : secondValue;
    }

    private static String joinText(List<String> values) {
        List<String> parts = new List<String>();
        for (String value : values) {
            if (!String.isBlank(value)) {
                parts.add(value);
            }
        }
        return String.join(parts, ' / ');
    }

    private static String normalize(String value) {
        return String.isBlank(value)
            ? ''
            : value.toLowerCase().replaceAll('[\\s　_\\-・/（）()]+', '');
    }

    private static String formatMessage(Contract__c contractRecord, String message) {
        return contractRecord.Id + ' / ' + contractRecord.Name + ' / ' + message;
    }

    private static String nullToDash(String value) {
        return value == null ? '-' : value;
    }
}
