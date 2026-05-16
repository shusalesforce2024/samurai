public with sharing class OppContractInvoiceService {
    public class CreationResult {
        public Id contractId;
        public Id invoiceId;
        public Integer invoiceLineCount;
    }

    private static final String CLOSED_WON = 'Closed Won';
    private static final String ACCEPTED = 'Accepted';
    private static final String CONTRACT_STATUS_DRAFT = 'Draft';
    private static final String INVOICE_ACCOUNT_ITEM_SALES = 'Sales';
    private static final String QUOTATION_ACCOUNT_ITEM_SALES = 'sales';

    public static CreationResult createFromOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('取引IDが指定されていません。');
        }

        Opportunity__c opportunityRecord = getOpportunity(opportunityId);
        validateOpportunity(opportunityRecord);

        if (hasExistingContract(opportunityId)) {
            throw new AuraHandledException('この取引には既に契約が作成されています。');
        }
        if (hasExistingInvoice(opportunityId)) {
            throw new AuraHandledException('この取引には既に請求が作成されています。');
        }

        Quotation__c acceptedQuotation = getAcceptedQuotation(opportunityId);
        validateAcceptedQuotation(acceptedQuotation);

        List<QuotationLine__c> quotationLines = getQuotationLines(acceptedQuotation.Id);
        validateQuotationLines(quotationLines);

        Contract__c contractRecord = createContract(opportunityRecord);
        Invoice__c invoiceRecord = createInvoice(opportunityId, contractRecord.Id, acceptedQuotation);
        Integer lineCount = createInvoiceLines(invoiceRecord.Id, quotationLines);

        CreationResult result = new CreationResult();
        result.contractId = contractRecord.Id;
        result.invoiceId = invoiceRecord.Id;
        result.invoiceLineCount = lineCount;
        return result;
    }

    private static Opportunity__c getOpportunity(Id opportunityId) {
        List<Opportunity__c> opportunities = [
            SELECT Id,
                   Name,
                   Account__c,
                   ACV__c,
                   ARR__c,
                   Description__c,
                   ExpectedDuration__c,
                   MRR__c,
                   Pricebook2__c,
                   StageName__c,
                   StartDate__c
            FROM Opportunity__c
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (opportunities.isEmpty()) {
            throw new AuraHandledException('対象の取引が見つかりません。');
        }

        return opportunities[0];
    }

    private static void validateOpportunity(Opportunity__c opportunityRecord) {
        List<String> errors = new List<String>();

        if (opportunityRecord.StageName__c != CLOSED_WON) {
            errors.add('取引が受注状態ではありません。');
        }
        if (opportunityRecord.Account__c == null) {
            errors.add('取引先が設定されていません。');
        }
        if (opportunityRecord.StartDate__c == null) {
            errors.add('契約日として使用する開始日が設定されていません。');
        }

        throwIfErrors(errors);
    }

    private static Boolean hasExistingContract(Id opportunityId) {
        return [
            SELECT COUNT()
            FROM Contract__c
            WHERE Oppotunity__c = :opportunityId
        ] > 0;
    }

    private static Boolean hasExistingInvoice(Id opportunityId) {
        return [
            SELECT COUNT()
            FROM Invoice__c
            WHERE ParentOpportunity__c = :opportunityId
        ] > 0;
    }

    private static Quotation__c getAcceptedQuotation(Id opportunityId) {
        List<Quotation__c> quotations = [
            SELECT Id,
                   Account__c,
                   Freee_Account_Item_Picklist__c,
                   Freee_Partner_Id__c,
                   Memo__c,
                   Oppotunity__c,
                   Quotation_Status__c,
                   Subject__c
            FROM Quotation__c
            WHERE Oppotunity__c = :opportunityId
              AND Quotation_Status__c = :ACCEPTED
            ORDER BY Issue_Date__c DESC, CreatedDate DESC
            LIMIT 1
        ];

        return quotations.isEmpty() ? null : quotations[0];
    }

    private static void validateAcceptedQuotation(Quotation__c quotationRecord) {
        List<String> errors = new List<String>();

        if (quotationRecord == null) {
            errors.add('Accepted の見積が見つかりません。');
        } else {
            if (quotationRecord.Account__c == null) {
                errors.add('見積に取引先が設定されていません。');
            }
            if (String.isBlank(quotationRecord.Subject__c)) {
                errors.add('見積の件名が設定されていません。');
            }
            if (String.isBlank(quotationRecord.Freee_Account_Item_Picklist__c)) {
                errors.add('見積の Freee計上科目が設定されていません。');
            }
        }

        throwIfErrors(errors);
    }

    private static List<QuotationLine__c> getQuotationLines(Id quotationId) {
        return [
            SELECT Id,
                   Description__c,
                   Freee_Account_Item_Id__c,
                   Product2__c,
                   Quantity__c,
                   Tax_Rate__c,
                   Unit_Price__c,
                   Withholding__c
            FROM QuotationLine__c
            WHERE Quotation__c = :quotationId
            ORDER BY CreatedDate ASC
        ];
    }

    private static void validateQuotationLines(List<QuotationLine__c> quotationLines) {
        List<String> errors = new List<String>();

        if (quotationLines == null || quotationLines.isEmpty()) {
            errors.add('見積明細がありません。');
        } else {
            for (QuotationLine__c line : quotationLines) {
                if (String.isBlank(line.Description__c)) {
                    errors.add('見積明細の品名が設定されていません。');
                    break;
                }
                if (line.Quantity__c == null || line.Quantity__c <= 0) {
                    errors.add('見積明細の数量は 0 より大きくしてください。');
                    break;
                }
                if (line.Unit_Price__c == null || line.Unit_Price__c <= 0) {
                    errors.add('見積明細の単価は 0 より大きくしてください。');
                    break;
                }
                if (String.isBlank(line.Tax_Rate__c)) {
                    errors.add('見積明細の税率が設定されていません。');
                    break;
                }
            }
        }

        throwIfErrors(errors);
    }

    private static Contract__c createContract(Opportunity__c opportunityRecord) {
        Contract__c contractRecord = new Contract__c(
            Account__c = opportunityRecord.Account__c,
            ACV__c = opportunityRecord.ACV__c,
            ARR__c = opportunityRecord.ARR__c,
            ContractName__c = buildContractName(opportunityRecord),
            Description__c = opportunityRecord.Description__c,
            ExpectedDuration__c = opportunityRecord.ExpectedDuration__c,
            MRR__c = opportunityRecord.MRR__c,
            Oppotunity__c = opportunityRecord.Id,
            Pricebook2__c = opportunityRecord.Pricebook2__c,
            StartDate__c = opportunityRecord.StartDate__c,
            Status__c = CONTRACT_STATUS_DRAFT
        );
        insert contractRecord;
        return contractRecord;
    }

    private static Invoice__c createInvoice(
        Id opportunityId,
        Id contractId,
        Quotation__c acceptedQuotation
    ) {
        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = acceptedQuotation.Account__c,
            Freee_Account_Item_Picklist__c = normalizeInvoiceAccountItemPicklist(
                acceptedQuotation.Freee_Account_Item_Picklist__c
            ),
            Freee_Partner_Id__c = acceptedQuotation.Freee_Partner_Id__c,
            Memo__c = acceptedQuotation.Memo__c,
            ParentContract__c = contractId,
            ParentOpportunity__c = opportunityId,
            Subject__c = acceptedQuotation.Subject__c
        );
        insert invoiceRecord;
        return invoiceRecord;
    }

    private static Integer createInvoiceLines(
        Id invoiceId,
        List<QuotationLine__c> quotationLines
    ) {
        List<InvoiceLine__c> invoiceLinesToInsert = new List<InvoiceLine__c>();

        for (QuotationLine__c quotationLine : quotationLines) {
            invoiceLinesToInsert.add(new InvoiceLine__c(
                Description__c = quotationLine.Description__c,
                Freee_Account_Item_Id__c = quotationLine.Freee_Account_Item_Id__c,
                Invoice__c = invoiceId,
                Product2__c = quotationLine.Product2__c,
                Quantity__c = quotationLine.Quantity__c,
                Tax_Rate__c = Decimal.valueOf(quotationLine.Tax_Rate__c),
                Unit_Price__c = quotationLine.Unit_Price__c,
                Withholding__c = quotationLine.Withholding__c
            ));
        }

        if (!invoiceLinesToInsert.isEmpty()) {
            insert invoiceLinesToInsert;
        }

        return invoiceLinesToInsert.size();
    }

    private static String buildContractName(Opportunity__c opportunityRecord) {
        if (opportunityRecord.StartDate__c == null) {
            return opportunityRecord.Name;
        }

        Date contractDate = opportunityRecord.StartDate__c;
        String month = String.valueOf(contractDate.month()).leftPad(2, '0');
        String day = String.valueOf(contractDate.day()).leftPad(2, '0');
        return opportunityRecord.Name
            + '_'
            + String.valueOf(contractDate.year())
            + '-'
            + month
            + '-'
            + day;
    }

    private static String normalizeInvoiceAccountItemPicklist(String sourceValue) {
        if (String.isBlank(sourceValue)) {
            return sourceValue;
        }
        if (sourceValue == QUOTATION_ACCOUNT_ITEM_SALES) {
            return INVOICE_ACCOUNT_ITEM_SALES;
        }
        return sourceValue;
    }

    private static void throwIfErrors(List<String> errors) {
        if (!errors.isEmpty()) {
            throw new AuraHandledException(String.join(errors, '\n'));
        }
    }
}