@isTest
private class FreeeInvoiceContractProvisionTest {
    @testSetup
    static void setupData() {
        insert new List<Account>{
            new Account(
                Name = '契約自動作成テスト取引先',
                Freee_Partner_Id__c = 7001
            ),
            new Account(
                Name = '共通ルールテスト取引先',
                Freee_Partner_Id__c = 7002
            )
        };
        insert new List<ProductMaster__c>{
            new ProductMaster__c(
                Name = 'Rendery Pro',
                ProductType__c = '継続費用',
                BillingTiming__c = '毎月',
                UnitPrice__c = 10000,
                AnnualMonthlyPrice__c = 10000,
                MRR_Target__c = true,
                ARR_Target__c = true
            ),
            new ProductMaster__c(
                Name = 'VISIOAL 単発支援',
                ProductType__c = '初期費用',
                BillingTiming__c = '初回のみ',
                UnitPrice__c = 50000,
                MRR_Target__c = false,
                ARR_Target__c = false
            )
        };
    }

    @isTest
    static void provisionsRecurringContractPeriodAndMonthlyLineIdempotently() {
        Account accountRecord = testAccount();
        ProductMaster__c product = productByName('Rendery Pro');
        FreeeInvoiceContractRule__c rule = new FreeeInvoiceContractRule__c(
            Name = 'Rendery月額ルール',
            Account__c = accountRecord.Id,
            AutoCreateAllowed__c = true,
            BillingCycle__c = 'Monthly',
            FreeePartnerId__c = '7001',
            IsActive__c = true,
            ProductMaster__c = product.Id,
            SubjectKeyword__c = 'Rendery'
        );
        insert rule;
        Id workId = createWork(
            accountRecord.Id,
            product.Id,
            'Rendery 2026年8月利用料',
            Date.newInstance(2026, 8, 1),
            Date.newInstance(2026, 8, 31),
            10000
        );

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ResolvedContract__c,
                   ResolvedContractPeriod__c,
                   ResolutionAction__c,
                   ProvisioningMessage__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workId
        ];
        System.assertNotEquals(null, workRecord.ResolvedContract__c);
        System.assertNotEquals(null, workRecord.ResolvedContractPeriod__c);
        System.assertEquals('ExistingContract', workRecord.ResolutionAction__c);

        Contract__c contractRecord = [
            SELECT AutoCreatedFromFreee__c,
                   BillingControlSource__c,
                   ContractNature__c,
                   CreationSource__c,
                   RenewalStop__c,
                   Status__c
            FROM Contract__c
            WHERE Id = :workRecord.ResolvedContract__c
        ];
        System.assertEquals(true, contractRecord.AutoCreatedFromFreee__c);
        System.assertEquals('Freee', contractRecord.BillingControlSource__c);
        System.assertEquals('Recurring', contractRecord.ContractNature__c);
        System.assertEquals('FreeeImport', contractRecord.CreationSource__c);
        System.assertEquals(true, contractRecord.RenewalStop__c);
        System.assertEquals('Activated', contractRecord.Status__c);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM ContractPeriod__c
            WHERE Contract__c = :contractRecord.Id
        ]);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM ContractLineItem__c
            WHERE MasterContract__c = :contractRecord.Id
              AND ProductMaster__c = :product.Id
              AND MRR_Target__c = true
              AND ARR_Target__c = true
        ]);

        rule = [
            SELECT Contract__c
            FROM FreeeInvoiceContractRule__c
            WHERE Id = :rule.Id
        ];
        System.assertEquals(contractRecord.Id, rule.Contract__c);
    }

    @isTest
    static void provisionsOneTimeContractWithoutMrrOrRenewal() {
        Account accountRecord = testAccount();
        ProductMaster__c product = productByName('VISIOAL 単発支援');
        insert new FreeeInvoiceContractRule__c(
            Name = 'VISIOAL単発ルール',
            Account__c = accountRecord.Id,
            AutoCreateAllowed__c = true,
            BillingCycle__c = 'OneTime',
            FreeePartnerId__c = '7001',
            IsActive__c = true,
            ProductMaster__c = product.Id,
            SubjectKeyword__c = 'VISIOAL'
        );
        Id workId = createWork(
            accountRecord.Id,
            product.Id,
            'VISIOAL 導入支援',
            Date.newInstance(2026, 8, 1),
            Date.newInstance(2026, 8, 31),
            50000
        );

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ResolvedContract__c,
                   ResolvedContractPeriod__c,
                   ResolutionAction__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workId
        ];
        System.assertEquals('OneTimeContractProvisioned', workRecord.ResolutionAction__c);
        Contract__c contractRecord = [
            SELECT ContractNature__c, RenewalStop__c
            FROM Contract__c
            WHERE Id = :workRecord.ResolvedContract__c
        ];
        System.assertEquals('OneTime', contractRecord.ContractNature__c);
        System.assertEquals(true, contractRecord.RenewalStop__c);
        ContractLineItem__c monthlyLine = [
            SELECT MRR_Target__c, ARR_Target__c, InitialFee__c
            FROM ContractLineItem__c
            WHERE ContractPeriod__c = :workRecord.ResolvedContractPeriod__c
            LIMIT 1
        ];
        System.assertEquals(false, monthlyLine.MRR_Target__c);
        System.assertEquals(false, monthlyLine.ARR_Target__c);
        System.assertEquals(true, monthlyLine.InitialFee__c);
    }

    @isTest
    static void provisionsMissingPeriodOnExistingContract() {
        Account accountRecord = testAccount();
        ProductMaster__c product = productByName('Rendery Pro');
        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = '既存Rendery契約',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 1, 1),
            Status__c = 'Activated'
        );
        insert contractRecord;
        Id workId = createWork(
            accountRecord.Id,
            product.Id,
            'Rendery 2026年9月利用料',
            Date.newInstance(2026, 9, 1),
            Date.newInstance(2026, 9, 30),
            10000
        );
        update new Mig_FreeeInvoiceWork__c(
            Id = workId,
            ResolvedContract__c = contractRecord.Id
        );

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ResolvedContractPeriod__c, ResolutionAction__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workId
        ];
        System.assertNotEquals(null, workRecord.ResolvedContractPeriod__c);
        System.assertEquals('PeriodProvisioned', workRecord.ResolutionAction__c);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM ContractLineItem__c
            WHERE ContractPeriod__c = :workRecord.ResolvedContractPeriod__c
              AND ProductMaster__c = :product.Id
        ]);
    }

    @isTest
    static void doesNotCreateContractWithoutUniqueApprovedRule() {
        Account accountRecord = testAccount();
        ProductMaster__c product = productByName('Rendery Pro');
        insert new List<FreeeInvoiceContractRule__c>{
            new FreeeInvoiceContractRule__c(
                Name = '重複ルール1',
                Account__c = accountRecord.Id,
                AutoCreateAllowed__c = true,
                BillingCycle__c = 'Monthly',
                IsActive__c = true,
                ProductMaster__c = product.Id
            ),
            new FreeeInvoiceContractRule__c(
                Name = '重複ルール2',
                Account__c = accountRecord.Id,
                AutoCreateAllowed__c = true,
                BillingCycle__c = 'Monthly',
                IsActive__c = true,
                ProductMaster__c = product.Id
            )
        };
        Id workId = createWork(
            accountRecord.Id,
            product.Id,
            'Rendery 利用料',
            Date.newInstance(2026, 10, 1),
            Date.newInstance(2026, 10, 31),
            10000
        );

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ResolvedContract__c,
                   ResolutionAction__c,
                   ProvisioningMessage__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workId
        ];
        System.assertEquals(null, workRecord.ResolvedContract__c);
        System.assertEquals('NeedsReview', workRecord.ResolutionAction__c);
        System.assert(workRecord.ProvisioningMessage__c.contains('複数'));
    }

    @isTest
    static void commonRuleCreatesSeparateContractsForEachAccount() {
        Account firstAccount = testAccount();
        Account secondAccount = accountByName('共通ルールテスト取引先');
        ProductMaster__c product = productByName('Rendery Pro');
        FreeeInvoiceContractRule__c commonRule =
            new FreeeInvoiceContractRule__c(
                Name = 'Rendery共通月額ルール',
                AutoCreateAllowed__c = true,
                BillingCycle__c = 'Monthly',
                IsActive__c = true,
                ProductMaster__c = product.Id,
                SubjectKeyword__c = 'Rendery'
            );
        insert commonRule;
        Id firstWorkId = createWork(
            firstAccount.Id,
            product.Id,
            'Rendery 共通ルール 取引先1',
            Date.newInstance(2026, 11, 1),
            Date.newInstance(2026, 11, 30),
            10000
        );
        Id secondWorkId = createWork(
            secondAccount.Id,
            product.Id,
            'Rendery 共通ルール 取引先2',
            Date.newInstance(2026, 11, 1),
            Date.newInstance(2026, 11, 30),
            10000
        );

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Map<Id, Mig_FreeeInvoiceWork__c> workById =
            new Map<Id, Mig_FreeeInvoiceWork__c>([
                SELECT Id, ResolvedContract__c, ResolvedContract__r.Account__c
                FROM Mig_FreeeInvoiceWork__c
                WHERE Id IN :new Set<Id>{ firstWorkId, secondWorkId }
            ]);
        System.assertNotEquals(
            workById.get(firstWorkId).ResolvedContract__c,
            workById.get(secondWorkId).ResolvedContract__c
        );
        System.assertEquals(
            firstAccount.Id,
            workById.get(firstWorkId).ResolvedContract__r.Account__c
        );
        System.assertEquals(
            secondAccount.Id,
            workById.get(secondWorkId).ResolvedContract__r.Account__c
        );
        commonRule = [
            SELECT Account__c, Contract__c
            FROM FreeeInvoiceContractRule__c
            WHERE Id = :commonRule.Id
        ];
        System.assertEquals(null, commonRule.Account__c);
        System.assertEquals(null, commonRule.Contract__c);
    }

    @isTest
    static void accountRuleOverridesCommonRule() {
        Account accountRecord = testAccount();
        ProductMaster__c product = productByName('Rendery Pro');
        insert new List<FreeeInvoiceContractRule__c>{
            new FreeeInvoiceContractRule__c(
                Name = 'Rendery共通月額ルール',
                AutoCreateAllowed__c = true,
                BillingCycle__c = 'Monthly',
                IsActive__c = true,
                ProductMaster__c = product.Id,
                SubjectKeyword__c = 'Rendery'
            ),
            new FreeeInvoiceContractRule__c(
                Name = '特定取引先の単発例外ルール',
                Account__c = accountRecord.Id,
                AutoCreateAllowed__c = true,
                BillingCycle__c = 'OneTime',
                IsActive__c = true,
                ProductMaster__c = product.Id,
                SubjectKeyword__c = 'Rendery'
            )
        };
        Id workId = createWork(
            accountRecord.Id,
            product.Id,
            'Rendery 個別例外',
            Date.newInstance(2026, 12, 1),
            Date.newInstance(2026, 12, 31),
            10000
        );

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ResolvedContract__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workId
        ];
        Contract__c contractRecord = [
            SELECT ContractNature__c
            FROM Contract__c
            WHERE Id = :workRecord.ResolvedContract__c
        ];
        System.assertEquals('OneTime', contractRecord.ContractNature__c);
    }

    @isTest
    static void commonRuleUsesTheSingleExistingContractMatchingTheProduct() {
        Account accountRecord = testAccount();
        ProductMaster__c renderyProduct = productByName('Rendery Pro');
        ProductMaster__c visioalProduct = productByName('VISIOAL 単発支援');
        Contract__c matchingContract = createExistingContractWithProduct(
            accountRecord.Id,
            renderyProduct.Id,
            '既存Rendery契約'
        );
        createExistingContractWithProduct(
            accountRecord.Id,
            visioalProduct.Id,
            '既存VISIOAL契約'
        );
        insert new FreeeInvoiceContractRule__c(
            Name = 'Rendery共通月額ルール',
            AutoCreateAllowed__c = true,
            BillingCycle__c = 'Monthly',
            IsActive__c = true,
            ProductMaster__c = renderyProduct.Id
        );
        Id workId = createWork(
            accountRecord.Id,
            renderyProduct.Id,
            'Rendery 既存契約判定',
            Date.newInstance(2026, 12, 1),
            Date.newInstance(2026, 12, 31),
            10000
        );
        Integer contractCountBefore = [
            SELECT COUNT()
            FROM Contract__c
            WHERE Account__c = :accountRecord.Id
        ];

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ResolvedContract__c, ResolutionAction__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workId
        ];
        System.assertEquals(matchingContract.Id, workRecord.ResolvedContract__c);
        System.assertEquals('PeriodProvisioned', workRecord.ResolutionAction__c);
        System.assertEquals(contractCountBefore, [
            SELECT COUNT()
            FROM Contract__c
            WHERE Account__c = :accountRecord.Id
        ]);
    }

    @isTest
    static void commonRuleStopsWhenMultipleExistingContractsMatchTheProduct() {
        Account accountRecord = testAccount();
        ProductMaster__c product = productByName('Rendery Pro');
        createExistingContractWithProduct(
            accountRecord.Id,
            product.Id,
            '既存Rendery契約1'
        );
        createExistingContractWithProduct(
            accountRecord.Id,
            product.Id,
            '既存Rendery契約2'
        );
        insert new FreeeInvoiceContractRule__c(
            Name = 'Rendery共通月額ルール',
            AutoCreateAllowed__c = true,
            BillingCycle__c = 'Monthly',
            IsActive__c = true,
            ProductMaster__c = product.Id
        );
        Id workId = createWork(
            accountRecord.Id,
            product.Id,
            'Rendery 複数契約判定',
            Date.newInstance(2026, 12, 1),
            Date.newInstance(2026, 12, 31),
            10000
        );
        Integer contractCountBefore = [
            SELECT COUNT()
            FROM Contract__c
            WHERE Account__c = :accountRecord.Id
        ];

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ResolvedContract__c,
                   ResolutionAction__c,
                   ProvisioningMessage__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workId
        ];
        System.assertEquals(null, workRecord.ResolvedContract__c);
        System.assertEquals('NeedsReview', workRecord.ResolutionAction__c);
        System.assert(workRecord.ProvisioningMessage__c.contains('複数'));
        System.assertEquals(contractCountBefore, [
            SELECT COUNT()
            FROM Contract__c
            WHERE Account__c = :accountRecord.Id
        ]);
    }

    @isTest
    static void commonRuleUsesBillingMonthWhenTargetPeriodIsMissing() {
        Account accountRecord = testAccount();
        ProductMaster__c product = productByName('Rendery Pro');
        insert new FreeeInvoiceContractRule__c(
            Name = 'Rendery共通月額ルール',
            AutoCreateAllowed__c = true,
            BillingCycle__c = 'Monthly',
            IsActive__c = true,
            ProductMaster__c = product.Id
        );
        Id workId = createWork(
            accountRecord.Id,
            product.Id,
            'Rendery 対象期間なし',
            Date.newInstance(2026, 12, 1),
            Date.newInstance(2026, 12, 31),
            10000
        );
        update new Mig_FreeeInvoiceWork__c(
            Id = workId,
            BillingDate__c = Date.newInstance(2026, 12, 20),
            TargetPeriodStartDate__c = null,
            TargetPeriodEndDate__c = null
        );

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ResolvedContract__c,
                   ResolvedContractPeriod__c,
                   ResolvedContractPeriod__r.PeriodStartDate__c,
                   ResolvedContractPeriod__r.PeriodEndDate__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workId
        ];
        System.assertNotEquals(null, workRecord.ResolvedContract__c);
        System.assertNotEquals(null, workRecord.ResolvedContractPeriod__c);
        System.assertEquals(
            Date.newInstance(2026, 12, 1),
            workRecord.ResolvedContractPeriod__r.PeriodStartDate__c
        );
        System.assertEquals(
            Date.newInstance(2026, 12, 31),
            workRecord.ResolvedContractPeriod__r.PeriodEndDate__c
        );
    }

    @isTest
    static void yearlyMonthlyRevenueUsesNetInvoiceAmountWithoutMasterProration() {
        Account accountRecord = testAccount();
        ProductMaster__c product = new ProductMaster__c(
            Name = 'Annual product without monthly master',
            UnitPrice__c = 120000,
            MRR_Target__c = true,
            ARR_Target__c = true
        );
        insert product;
        insert new FreeeInvoiceContractRule__c(
            Name = 'Annual net amount rule',
            Account__c = accountRecord.Id,
            AutoCreateAllowed__c = true,
            BillingCycle__c = 'Yearly',
            FreeePartnerId__c = '7001',
            IsActive__c = true,
            ProductMaster__c = product.Id,
            SubjectKeyword__c = 'Annual net'
        );

        Mig_FreeeInvoiceWork__c workRecord =
            new Mig_FreeeInvoiceWork__c(
                ExternalKey__c = 'freee_contract_provision:annual-net',
                FreeeInvoiceId__c = '990001',
                FreeePartnerId__c = '7001',
                BillingDate__c = Date.newInstance(2026, 8, 20),
                TargetPeriodStartDate__c = Date.newInstance(2026, 8, 1),
                TargetPeriodEndDate__c = Date.newInstance(2027, 7, 31),
                Subject__c = 'Annual net contract',
                InvoiceAmount__c = 108000,
                ResolvedAccount__c = accountRecord.Id,
                ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
            );
        insert workRecord;
        insert new List<Mig_FreeeInvoiceLineWork__c>{
            new Mig_FreeeInvoiceLineWork__c(
                InvoiceWork__c = workRecord.Id,
                ExternalKey__c = workRecord.ExternalKey__c + ':1',
                Description__c = 'Annual net contract',
                Quantity__c = 1,
                LineAmount__c = 120000,
                ConfirmedProductMaster__c = product.Id,
                ProductResolveStatus__c =
                    Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED,
                ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
            ),
            new Mig_FreeeInvoiceLineWork__c(
                InvoiceWork__c = workRecord.Id,
                ExternalKey__c = workRecord.ExternalKey__c + ':2',
                Description__c = '年払い割引',
                Quantity__c = 1,
                LineAmount__c = -12000,
                ConfirmedProductMaster__c = product.Id,
                ProductResolveStatus__c =
                    Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED,
                ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
            )
        };

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        workRecord = [
            SELECT ResolvedContractPeriod__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workRecord.Id
        ];
        ContractLineItem__c monthlyLine = [
            SELECT RevenueAmount__c, Total__c
            FROM ContractLineItem__c
            WHERE ContractPeriod__c = :workRecord.ResolvedContractPeriod__c
              AND ProductMaster__c = :product.Id
            LIMIT 1
        ];
        System.assertEquals(9000, monthlyLine.RevenueAmount__c);
        System.assertEquals(9000, monthlyLine.Total__c);
    }

    @isTest
    static void doesNotCreateAnOverlappingContractPeriod() {
        Account accountRecord = testAccount();
        ProductMaster__c product = productByName('Rendery Pro');
        Contract__c contractRecord =
            createExistingContractWithProduct(
                accountRecord.Id,
                product.Id,
                'Overlap test contract'
            );
        insert new ContractPeriod__c(
            Contract__c = contractRecord.Id,
            ContractUpdate__c = contractRecord.ContractUpdate__c,
            PeriodStartDate__c = Date.newInstance(2026, 8, 15),
            PeriodEndDate__c = Date.newInstance(2026, 9, 14)
        );
        Id workId = createWork(
            accountRecord.Id,
            product.Id,
            'Overlap invoice',
            Date.newInstance(2026, 8, 1),
            Date.newInstance(2026, 8, 31),
            10000
        );
        update new Mig_FreeeInvoiceWork__c(
            Id = workId,
            ResolvedContract__c = contractRecord.Id
        );

        Test.startTest();
        FreeeInvoiceContractProvisioningService.provisionAll();
        Test.stopTest();

        Mig_FreeeInvoiceWork__c workRecord = [
            SELECT ResolvedContractPeriod__c,
                   ResolutionAction__c,
                   ProvisioningMessage__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workId
        ];
        System.assertEquals(null, workRecord.ResolvedContractPeriod__c);
        System.assertEquals('NeedsReview', workRecord.ResolutionAction__c);
        System.assert(
            workRecord.ProvisioningMessage__c.contains('重複')
        );
    }

    private static Account testAccount() {
        return accountByName('契約自動作成テスト取引先');
    }

    private static Account accountByName(String name) {
        return [SELECT Id FROM Account WHERE Name = :name LIMIT 1];
    }

    private static ProductMaster__c productByName(String name) {
        return [
            SELECT Id
            FROM ProductMaster__c
            WHERE Name = :name
            LIMIT 1
        ];
    }

    private static Contract__c createExistingContractWithProduct(
        Id accountId,
        Id productId,
        String contractName
    ) {
        Contract__c contractRecord = new Contract__c(
            Account__c = accountId,
            ContractName__c = contractName,
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 1, 1),
            Status__c = 'Activated'
        );
        insert contractRecord;
        insert new ContractLineItem__c(
            Account__c = accountId,
            MasterContract__c = contractRecord.Id,
            ProductMaster__c = productId,
            PeopleNumber__c = 1,
            PeriodStartDate__c = Date.newInstance(2026, 1, 1),
            PeriodEndDate__c = Date.newInstance(2026, 1, 31),
            RevenueAmount__c = 10000,
            Total__c = 10000
        );
        return contractRecord;
    }

    private static Id createWork(
        Id accountId,
        Id productId,
        String subject,
        Date targetStart,
        Date targetEnd,
        Decimal lineAmount
    ) {
        Mig_FreeeInvoiceWork__c workRecord = new Mig_FreeeInvoiceWork__c(
            ExternalKey__c = 'freee_contract_provision:' + subject,
            FreeeInvoiceId__c = String.valueOf(Crypto.getRandomInteger()),
            FreeePartnerId__c = '7001',
            BillingDate__c = targetStart.addDays(19),
            TargetPeriodStartDate__c = targetStart,
            TargetPeriodEndDate__c = targetEnd,
            Subject__c = subject,
            InvoiceAmount__c = lineAmount,
            ResolvedAccount__c = accountId,
            ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
        );
        insert workRecord;
        insert new Mig_FreeeInvoiceLineWork__c(
            InvoiceWork__c = workRecord.Id,
            ExternalKey__c = workRecord.ExternalKey__c + ':1',
            FreeeLineId__c = '1',
            Description__c = subject,
            Quantity__c = 1,
            UnitPrice__c = lineAmount,
            LineAmount__c = lineAmount,
            ConfirmedProductMaster__c = productId,
            ProductResolveStatus__c =
                Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED,
            ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
        );
        return workRecord.Id;
    }
}
