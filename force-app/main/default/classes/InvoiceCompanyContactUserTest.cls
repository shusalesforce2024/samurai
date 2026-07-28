@IsTest
private class InvoiceCompanyContactUserTest {
    @IsTest
    static void beforeInsertDefaultsCompanyContactUser() {
        Account accountRecord = new Account(
            Name = 'Company Contact Default Account',
            Freee_Partner_Id__c = 12345
        );
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.today(),
            Payment_Date__c = Date.today().addDays(30),
            Freee_Account_Item_Picklist__c = 'Sales',
            Subject__c = 'Company contact default invoice'
        );

        insert invoiceRecord;

        Invoice__c insertedInvoice = [
            SELECT CompanyContactUser__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
        ];

        System.assertNotEquals(null, insertedInvoice.CompanyContactUser__c);
    }

    @IsTest
    static void mapperSendsCompanyContactName() {
        User currentUser = [
            SELECT Id,
                   Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];

        Account accountRecord = new Account(
            Name = 'Company Contact Mapper Account',
            Freee_Partner_Id__c = 54321
        );
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 7, 20),
            Payment_Date__c = Date.newInstance(2026, 8, 20),
            Payment_Type__c = 'transfer',
            Freee_Account_Item_Picklist__c = 'Sales',
            Subject__c = 'Company contact mapper invoice',
            CompanyContactUser__c = currentUser.Id
        );
        invoiceRecord.putSObject('Account__r', accountRecord);
        invoiceRecord.putSObject('CompanyContactUser__r', currentUser);

        insert new Freee_Account_Item_Mappings__c(
            Name = 'Sales',
            Key__c = 'Sales',
            Freee_Account_Item_Id__c = '999',
            Is_Active__c = true
        );

        FreeeConfigService.Config config = new FreeeConfigService.Config();
        config.companyId = 12345;
        config.templateId = 67890;
        config.paymentType = 'transfer';
        config.taxEntryMethod = 'exclusive';
        config.taxFraction = 'round_down';
        config.withholdingTaxEntryMethod = 'out';

        String requestBody = FreeeInvoiceMapper.toRequestBody(
            invoiceRecord,
            new List<InvoiceLine__c>{
                new InvoiceLine__c(
                    Description__c = 'Service fee',
                    Quantity__c = 1,
                    Unit_Price__c = 1000,
                    Tax_Rate__c = 10
                )
            },
            config
        );

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
        System.assertEquals(currentUser.Name, body.get('company_contact_name'));
    }
}
