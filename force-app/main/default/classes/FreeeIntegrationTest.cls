@isTest
private class FreeeIntegrationTest {
    private class FreeeMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        FreeeMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assertEquals('application/json', req.getHeader('Content-Type'));
            System.assert(String.isNotBlank(req.getBody()));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @testSetup
    static void setupConfigAndMappings() {
        insert new Freee_Configs__c(
            Name = 'Default',
            Company_Id__c = '12345',
            Invoice_Base_Url__c = 'https://secure.freee.co.jp/invoices/',
            Payment_Type__c = 'transfer',
            Quotation_Template_Id__c = '98765',
            Tax_Entry_Method__c = 'exclusive',
            Tax_Fraction__c = 'round_down',
            Template_Id__c = '67890',
            Withholding__c = 'false',
            Withholding_Tax_Entry_Method__c = 'IN'
        );

        insert new Freee_Account_Item_Mappings__c(
            Name = 'Sales mapping',
            Key__c = 'Sales',
            Freee_Account_Item_Id__c = '4001',
            Is_Active__c = true
        );
    }

    @isTest
    static void configServiceReturnsTypedConfig() {
        FreeeConfigService.Config config = FreeeConfigService.getConfig();

        System.assertEquals(Long.valueOf('12345'), config.companyId);
        System.assertEquals(Long.valueOf('67890'), config.templateId);
        System.assertEquals(Long.valueOf('98765'), config.quotationTemplateId);
        System.assertEquals('transfer', config.paymentType);
        System.assertEquals('exclusive', config.taxEntryMethod);
        System.assertEquals('round_down', config.taxFraction);
        System.assertEquals('IN', config.withholdingTaxEntryMethod);
        System.assertEquals(
            Long.valueOf('98765'),
            FreeeConfigService.requireQuotationTemplateId(config)
        );
    }

    @isTest
    static void invoiceMapperBuildsExpectedJson() {
        Account accountRecord = new Account(Freee_Partner_Id__c = 555);
        Invoice__c invoiceRecord = new Invoice__c(
            Account__r = accountRecord,
            Billing_Date__c = Date.newInstance(2026, 5, 1),
            Payment_Date__c = Date.newInstance(2026, 5, 31),
            Payment_Type__c = 'DIRECT_DEBIT',
            Subject__c = 'Invoice subject',
            Memo__c = 'Invoice memo',
            Freee_Account_Item_Picklist__c = 'Sales'
        );
        List<InvoiceLine__c> lines = new List<InvoiceLine__c>{
            new InvoiceLine__c(
                Description__c = 'Service fee',
                Quantity__c = 2,
                Unit_Price__c = 1500,
                Tax_Rate__c = 10,
                Reduced_Tax__c = false,
                Withholding__c = true
            )
        };

        String body = FreeeInvoiceMapper.toRequestBody(
            invoiceRecord,
            lines,
            FreeeConfigService.getConfig()
        );
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> parsedLines = (List<Object>) parsed.get('lines');
        Map<String, Object> firstLine = (Map<String, Object>) parsedLines[0];

        System.assertEquals('12345', String.valueOf(parsed.get('company_id')));
        System.assertEquals('555', String.valueOf(parsed.get('partner_id')));
        System.assertEquals('direct_debit', parsed.get('payment_type'));
        System.assertEquals('in', parsed.get('withholding_tax_entry_method'));
        System.assertEquals('4001', String.valueOf(firstLine.get('account_item_id')));
        System.assertEquals('1500', firstLine.get('unit_price'));
    }

    @isTest
    static void quotationMapperBuildsExpectedJson() {
        Quotation__c quotationRecord = new Quotation__c(
            Account__r = new Account(Freee_Partner_Id__c = 777),
            Issue_Date__c = Date.newInstance(2026, 5, 2),
            Expiration_Date__c = Date.newInstance(2026, 6, 2),
            Subject__c = 'Quotation subject',
            Memo__c = 'Quotation memo'
        );
        List<QuotationLine__c> lines = new List<QuotationLine__c>{
            new QuotationLine__c(
                Description__c = 'Quoted service',
                Quantity__c = 3,
                Unit_Price__c = 2000,
                Tax_Rate__c = '10',
                Withholding__c = false
            )
        };

        String body = FreeeQuotationMapper.toRequestBody(
            quotationRecord,
            lines,
            FreeeConfigService.getConfig()
        );
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> parsedLines = (List<Object>) parsed.get('lines');
        Map<String, Object> firstLine = (Map<String, Object>) parsedLines[0];

        System.assertEquals('12345', String.valueOf(parsed.get('company_id')));
        System.assertEquals('98765', String.valueOf(parsed.get('template_id')));
        System.assertEquals('777', String.valueOf(parsed.get('partner_id')));
        System.assertEquals('2026-05-02', parsed.get('quotation_date'));
        System.assertEquals('2000', firstLine.get('unit_price'));
    }

    @isTest
    static void invoiceControllerSyncsSuccessAndWritesLog() {
        Account accountRecord = createAccountWithPartner();
        Invoice__c invoiceRecord = createInvoice(accountRecord.Id, 'Sales');
        createInvoiceLine(invoiceRecord.Id);

        Test.setMock(
            HttpCalloutMock.class,
            new FreeeMock(201, '{"invoice":{"id":24680,"invoice_number":"INV-FREEE"}}')
        );

        Test.startTest();
        String message = FreeeInvoiceController.createInvoice(invoiceRecord.Id);
        Test.stopTest();

        Invoice__c synced = [
            SELECT Freee_Invoice_Id__c,
                   Freee_Invoice_Number__c,
                   Freee_Invoice_Url__c,
                   Freee_Partner_Id__c,
                   Freee_Sync_Status__c,
                   Sent_To_Freee__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
        ];
        System.assert(String.isNotBlank(message));
        System.assertEquals(Decimal.valueOf(24680), synced.Freee_Invoice_Id__c);
        System.assertEquals('INV-FREEE', synced.Freee_Invoice_Number__c);
        System.assertEquals('https://secure.freee.co.jp/invoices/24680', synced.Freee_Invoice_Url__c);
        System.assertEquals(Decimal.valueOf(333), synced.Freee_Partner_Id__c);
        System.assertEquals('Success', synced.Freee_Sync_Status__c);
        System.assertEquals(true, synced.Sent_To_Freee__c);
        String targetRecordId = String.valueOf(invoiceRecord.Id);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Freee_Sync_Log__c WHERE Target_Record_Id__c = :targetRecordId]
        );
    }

    @isTest
    static void invoiceFacadeStoresFailureDetails() {
        Account accountRecord = createAccountWithPartner();
        Invoice__c invoiceRecord = createInvoice(accountRecord.Id, 'Sales');
        createInvoiceLine(invoiceRecord.Id);

        Test.setMock(
            HttpCalloutMock.class,
            new FreeeMock(422, '{"errors":[{"messages":["Invalid invoice"]}]}')
        );

        try {
            FreeeInvoiceFacade.createInvoice(invoiceRecord.Id);
            System.assert(false, 'Expected sync failure');
        } catch (FreeeInvoiceFacade.FreeeInvoiceDebugException e) {
            System.assert(e.getMessage().contains('Invalid invoice'));
        }

        Invoice__c failed = [
            SELECT Freee_Sync_Status__c, Freee_Sync_Message__c, Retry_Count__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
        ];
        System.assertEquals('Failed', failed.Freee_Sync_Status__c);
        System.assert(failed.Freee_Sync_Message__c.contains('Invalid invoice'));
        System.assertEquals(Decimal.valueOf(1), failed.Retry_Count__c);
    }

    @isTest
    static void quotationControllerSyncsSuccessAndWritesLog() {
        Account accountRecord = createAccountWithPartner();
        Quotation__c quotationRecord = createQuotation(accountRecord.Id);
        createQuotationLine(quotationRecord.Id);

        Test.setMock(
            HttpCalloutMock.class,
            new FreeeMock(201, '{"quotation":{"id":13579,"quotation_number":"QT-FREEE"}}')
        );

        Test.startTest();
        String message = FreeeQuotationController.createQuotation(quotationRecord.Id);
        Test.stopTest();

        Quotation__c synced = [
            SELECT Freee_Quotation_Id__c,
                   Freee_Quotation_Number__c,
                   Freee_Quotation_URL__c,
                   Freee_Partner_Id__c,
                   Freee_Sync_Status__c,
                   Sent_To_Freee__c
            FROM Quotation__c
            WHERE Id = :quotationRecord.Id
        ];
        System.assert(String.isNotBlank(message));
        System.assertEquals(Decimal.valueOf(13579), synced.Freee_Quotation_Id__c);
        System.assertEquals('QT-FREEE', synced.Freee_Quotation_Number__c);
        System.assertEquals('https://secure.freee.co.jp/quotations/13579', synced.Freee_Quotation_URL__c);
        System.assertEquals(Decimal.valueOf(333), synced.Freee_Partner_Id__c);
        System.assertEquals('Success', synced.Freee_Sync_Status__c);
        System.assertEquals(true, synced.Sent_To_Freee__c);
    }

    @isTest
    static void quotationFacadeStoresFailureDetails() {
        Account accountRecord = createAccountWithPartner();
        Quotation__c quotationRecord = createQuotation(accountRecord.Id);
        createQuotationLine(quotationRecord.Id);

        Test.setMock(
            HttpCalloutMock.class,
            new FreeeMock(400, '{"message":"Invalid quotation"}')
        );

        try {
            FreeeQuotationFacade.createQuotation(quotationRecord.Id);
            System.assert(false, 'Expected sync failure');
        } catch (FreeeQuotationFacade.FreeeQuotationDebugException e) {
            System.assert(e.getMessage().contains('Invalid quotation'));
        }

        Quotation__c failed = [
            SELECT Freee_Sync_Status__c, Freee_Sync_Message__c, Retry_Count__c
            FROM Quotation__c
            WHERE Id = :quotationRecord.Id
        ];
        System.assertEquals('Failed', failed.Freee_Sync_Status__c);
        System.assert(failed.Freee_Sync_Message__c.contains('Invalid quotation'));
        System.assertEquals(Decimal.valueOf(1), failed.Retry_Count__c);
    }

    @isTest
    static void partnerControllerCreatesPartnerAndUpdatesAccount() {
        Account accountRecord = new Account(Name = 'Partner Account');
        insert accountRecord;

        Test.setMock(
            HttpCalloutMock.class,
            new FreeeMock(201, '{"partner":{"id":999001}}')
        );

        Test.startTest();
        FreeePartnerFacade.Result result = FreeePartnerController.syncPartner(accountRecord.Id);
        Test.stopTest();

        Account updatedAccount = [
            SELECT Freee_Partner_Id__c
            FROM Account
            WHERE Id = :accountRecord.Id
        ];
        System.assertEquals(true, result.success);
        System.assertEquals('999001', result.freeePartnerId);
        System.assertEquals(Decimal.valueOf(999001), updatedAccount.Freee_Partner_Id__c);
    }

    @isTest
    static void serviceClassesSendCallouts() {
        Test.setMock(HttpCalloutMock.class, new FreeeMock(200, '{"ok":true}'));

        Test.startTest();
        HttpResponse invoiceResponse = FreeeInvoiceService.createInvoice('{"invoice":true}');
        HttpResponse quotationResponse = FreeeQuotationService.createQuotation('{"quotation":true}');
        HttpResponse partnerResponse = FreeePartnerService.createPartner('{"partner":true}');
        Test.stopTest();

        System.assertEquals(200, invoiceResponse.getStatusCode());
        System.assertEquals(200, quotationResponse.getStatusCode());
        System.assertEquals(200, partnerResponse.getStatusCode());
    }

    @isTest
    static void contextAndLogSupportClassesWorkDirectly() {
        Account accountRecord = createAccountWithPartner();
        Invoice__c invoiceRecord = createInvoice(accountRecord.Id, 'Sales');
        createInvoiceLine(invoiceRecord.Id);

        FreeeInvoiceContext invoiceContext = new FreeeInvoiceContext();
        invoiceContext.invoice = invoiceRecord;
        invoiceContext.lines = new List<InvoiceLine__c>();
        invoiceContext.config = FreeeConfigService.getConfig();
        invoiceContext.requestBody = '{"invoice":true}';
        invoiceContext.response = new HttpResponse();
        invoiceContext.response.setStatusCode(200);
        invoiceContext.response.setBody('{"invoice":{"id":1}}');

        FreeeQuotationContext quotationContext = new FreeeQuotationContext();
        quotationContext.quotation = new Quotation__c(Subject__c = 'Context quotation');
        quotationContext.lines = new List<QuotationLine__c>();
        quotationContext.config = invoiceContext.config;
        quotationContext.requestBody = '{"quotation":true}';
        quotationContext.response = new HttpResponse();
        quotationContext.response.setStatusCode(201);
        quotationContext.response.setBody('{"quotation":{"id":2}}');

        FreeeSyncLogService.LogRequest logReq = new FreeeSyncLogService.LogRequest();
        logReq.invoiceId = invoiceRecord.Id;
        logReq.requestBody = invoiceContext.requestBody;
        logReq.responseBody = invoiceContext.response.getBody();
        logReq.statusCode = invoiceContext.response.getStatusCode();
        logReq.result = 'Success';

        Test.startTest();
        FreeeSyncLogService.saveLog(logReq);
        Test.stopTest();

        String targetRecordId = String.valueOf(invoiceRecord.Id);
        Freee_Sync_Log__c logRecord = [
            SELECT Target_Record_Id__c,
                   Request_Body__c,
                   Response_Body__c,
                   Status_Code__c,
                   Result__c
            FROM Freee_Sync_Log__c
            WHERE Target_Record_Id__c = :targetRecordId
            LIMIT 1
        ];
        System.assertEquals(targetRecordId, logRecord.Target_Record_Id__c);
        System.assertEquals('{"invoice":true}', logRecord.Request_Body__c);
        System.assertEquals('{"invoice":{"id":1}}', logRecord.Response_Body__c);
        System.assertEquals(Decimal.valueOf(200), logRecord.Status_Code__c);
        System.assertEquals('Success', logRecord.Result__c);
    }

    @isTest
    static void configServiceRejectsMissingQuotationTemplateId() {
        FreeeConfigService.Config config = new FreeeConfigService.Config();

        try {
            FreeeConfigService.requireQuotationTemplateId(config);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    @isTest
    static void controllersRejectNullIds() {
        assertThrowsAuraForInvoice();
        assertThrowsAuraForQuotation();
        assertThrowsAuraForPartner();
    }

    private static void assertThrowsAuraForInvoice() {
        try {
            FreeeInvoiceController.createInvoice(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    private static void assertThrowsAuraForQuotation() {
        try {
            FreeeQuotationController.createQuotation(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    private static void assertThrowsAuraForPartner() {
        try {
            FreeePartnerController.syncPartner(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    private static Account createAccountWithPartner() {
        Account accountRecord = new Account(
            Name = 'Freee Account',
            Freee_Partner_Id__c = 333
        );
        insert accountRecord;
        return accountRecord;
    }

    private static Invoice__c createInvoice(Id accountId, String accountItemKey) {
        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountId,
            Billing_Date__c = Date.newInstance(2026, 5, 1),
            Payment_Date__c = Date.newInstance(2026, 5, 31),
            Freee_Account_Item_Picklist__c = accountItemKey,
            Subject__c = 'Invoice subject',
            Memo__c = 'Invoice memo'
        );
        insert invoiceRecord;
        return invoiceRecord;
    }

    private static InvoiceLine__c createInvoiceLine(Id invoiceId) {
        InvoiceLine__c line = new InvoiceLine__c(
            Invoice__c = invoiceId,
            Description__c = 'Invoice line',
            Quantity__c = 2,
            Unit_Price__c = 1000,
            Tax_Rate__c = 10,
            Withholding__c = false
        );
        insert line;
        return line;
    }

    private static Quotation__c createQuotation(Id accountId) {
        Quotation__c quotationRecord = new Quotation__c(
            Account__c = accountId,
            Issue_Date__c = Date.newInstance(2026, 5, 2),
            Expiration_Date__c = Date.newInstance(2026, 6, 2),
            Subject__c = 'Quotation subject',
            Memo__c = 'Quotation memo'
        );
        insert quotationRecord;
        return quotationRecord;
    }

    private static QuotationLine__c createQuotationLine(Id quotationId) {
        QuotationLine__c line = new QuotationLine__c(
            Quotation__c = quotationId,
            Description__c = 'Quotation line',
            Quantity__c = 1,
            Unit_Price__c = 1200,
            Tax_Rate__c = '10',
            Withholding__c = false
        );
        insert line;
        return line;
    }
}
