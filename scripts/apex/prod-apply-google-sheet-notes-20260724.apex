// Applies the accounting team's decisions recorded in the 2026-07-24 review sheet.
Set<String> workNames = new Set<String>{
    'MFIW-000126', 'MFIW-000154', 'MFIW-000174', 'MFIW-000206',
    'MFIW-000211', 'MFIW-000230', 'MFIW-000259', 'MFIW-000260',
    'MFIW-000264', 'MFIW-000268', 'MFIW-000275', 'MFIW-000277',
    'MFIW-000280', 'MFIW-000292', 'MFIW-000296', 'MFIW-000327',
    'MFIW-000329', 'MFIW-000330', 'MFIW-000359', 'MFIW-000388',
    'MFIW-000410', 'MFIW-000414', 'MFIW-000422'
};

Map<String, Mig_FreeeInvoiceWork__c> workByName = new Map<String, Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, Name, InvoiceAmount__c, ResolvedAccount__c, ResolvedContract__c,
           ResolvedContractPeriod__c, ImportStatus__c, ValidationMessage__c,
           CreatedInvoice__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Name IN :workNames
    FOR UPDATE
]) {
    workByName.put(workRecord.Name, workRecord);
}
System.assertEquals(23, workByName.size(), '対象Workが23件揃っていません。');

Map<String, ProductMaster__c> productByName = new Map<String, ProductMaster__c>();
Set<String> requiredProductNames = new Set<String>{
    'knock knock AI Basicプラン(50クレジット)',
    'Rendery Proプラン',
    '[代理販売20%] Rendery Proプラン',
    '[代理販売20%] Rendery Enterpriseプラン',
    '[年払] Rendery Enterpriseプラン',
    '[OLD] Rendery Enterpriseプラン(2025年9月まで)',
    '[月払] knock knock AI Enterpriseプラン 1100クレジット'
};
for (ProductMaster__c productRecord : [
    SELECT Id, Name, UnitPrice__c, BillingTiming__c, ProductType__c
    FROM ProductMaster__c
    WHERE Name IN :requiredProductNames
]) {
    System.assert(!productByName.containsKey(productRecord.Name),
        '商品マスタ名が重複しています: ' + productRecord.Name);
    productByName.put(productRecord.Name, productRecord);
}

if (!productByName.containsKey('[月払] knock knock AI Enterpriseプラン 1100クレジット')) {
    ProductMaster__c newProduct = new ProductMaster__c(
        Name = '[月払] knock knock AI Enterpriseプラン 1100クレジット',
        UnitPrice__c = 159500,
        BillingTiming__c = '毎月',
        ProductType__c = '継続費用',
        MRR_Target__c = true,
        ARR_Target__c = true
    );
    insert newProduct;
    productByName.put(newProduct.Name, newProduct);
}
System.assertEquals(requiredProductNames.size(), productByName.size(),
    '必要な商品マスタを一意に特定できません。');

Mig_FreeeInvoiceWork__c agreWork = workByName.get('MFIW-000280');
List<Contract__c> agreContracts = [
    SELECT Id
    FROM Contract__c
    WHERE Name = 'CN-00000120'
    LIMIT 2
];
List<ContractPeriod__c> agrePeriods = [
    SELECT Id
    FROM ContractPeriod__c
    WHERE Name = 'CP-00000119'
    LIMIT 2
];
System.assertEquals(1, agreContracts.size(), 'Agreの契約管理を一意に特定できません。');
System.assertEquals(1, agrePeriods.size(), 'Agreの契約期間を一意に特定できません。');
agreWork.ResolvedContract__c = agreContracts[0].Id;
agreWork.ResolvedContractPeriod__c = agrePeriods[0].Id;

Map<Id, String> workNameById = new Map<Id, String>();
for (Mig_FreeeInvoiceWork__c workRecord : workByName.values()) {
    workNameById.put(workRecord.Id, workRecord.Name);
}

List<Mig_FreeeInvoiceLineWork__c> lineUpdates = new List<Mig_FreeeInvoiceLineWork__c>();
Map<String, Integer> activeLineCountByWork = new Map<String, Integer>();
Map<String, Decimal> totalByWork = new Map<String, Decimal>();
for (Mig_FreeeInvoiceLineWork__c lineRecord : [
    SELECT Id, Name, InvoiceWork__c, Description__c, Quantity__c, UnitPrice__c,
           LineAmount__c, TaxAmount__c, ConfirmedProductMaster__c,
           ImportStatus__c, ResolveMessage__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c IN :workNameById.keySet()
    FOR UPDATE
]) {
    String workName = workNameById.get(lineRecord.InvoiceWork__c);

    if (workName == 'MFIW-000154') {
        lineRecord.ImportStatus__c = '対象外';
        lineRecord.ResolveMessage__c = 'Google Sheets備考確認済み: 交通費明細のため移行対象外';
        lineUpdates.add(lineRecord);
        continue;
    }

    if (new Set<String>{'MFIW-000275', 'MFIW-000280'}.contains(workName)) {
        lineRecord.ConfirmedProductMaster__c =
            productByName.get('knock knock AI Basicプラン(50クレジット)').Id;
    } else if (new Set<String>{
        'MFIW-000174', 'MFIW-000230', 'MFIW-000277',
        'MFIW-000296', 'MFIW-000422'
    }.contains(workName)) {
        lineRecord.ConfirmedProductMaster__c =
            productByName.get('[月払] knock knock AI Enterpriseプラン 1100クレジット').Id;
    } else if (new Set<String>{
        'MFIW-000259', 'MFIW-000260', 'MFIW-000329',
        'MFIW-000330', 'MFIW-000410'
    }.contains(workName)) {
        lineRecord.ConfirmedProductMaster__c =
            productByName.get('[代理販売20%] Rendery Proプラン').Id;
    } else if (workName == 'MFIW-000414') {
        lineRecord.ConfirmedProductMaster__c =
            productByName.get('[代理販売20%] Rendery Enterpriseプラン').Id;
    } else if (new Set<String>{'MFIW-000268', 'MFIW-000327', 'MFIW-000388'}.contains(workName)) {
        lineRecord.ConfirmedProductMaster__c = productByName.get('Rendery Proプラン').Id;
    } else if (workName == 'MFIW-000359') {
        lineRecord.ConfirmedProductMaster__c =
            productByName.get('[OLD] Rendery Enterpriseプラン(2025年9月まで)').Id;
    }

    if (new Set<String>{'MFIW-000206', 'MFIW-000211', 'MFIW-000264'}.contains(workName)) {
        if (lineRecord.Description__c != null && lineRecord.Description__c.contains('割引')) {
            lineRecord.ImportStatus__c = '対象外';
            lineRecord.ResolveMessage__c = 'Google Sheets備考確認済み: 年払い割引を主明細へ統合';
            lineUpdates.add(lineRecord);
            continue;
        }
        Decimal quantity = lineRecord.Quantity__c == null ? 1 : lineRecord.Quantity__c;
        lineRecord.ConfirmedProductMaster__c =
            productByName.get('[年払] Rendery Enterpriseプラン').Id;
        lineRecord.UnitPrice__c = 168000;
        lineRecord.LineAmount__c = quantity * 168000;
        lineRecord.TaxAmount__c = lineRecord.LineAmount__c * 0.10;
    }

    if (workName == 'MFIW-000268') {
        lineRecord.Quantity__c = 12;
        lineRecord.UnitPrice__c = 8000;
        lineRecord.LineAmount__c = 96000;
        lineRecord.TaxAmount__c = 9600;
    }
    if (workName == 'MFIW-000292') {
        lineRecord.UnitPrice__c = 8000;
    }

    lineRecord.ResolveMessage__c = 'Google Sheets備考確認済み: 経理担当者が商品・金額を確認';
    lineUpdates.add(lineRecord);
    activeLineCountByWork.put(workName,
        (activeLineCountByWork.containsKey(workName) ? activeLineCountByWork.get(workName) : 0) + 1);
    Decimal lineTotal = (lineRecord.LineAmount__c == null ? 0 : lineRecord.LineAmount__c)
        + (lineRecord.TaxAmount__c == null ? 0 : lineRecord.TaxAmount__c);
    totalByWork.put(workName,
        (totalByWork.containsKey(workName) ? totalByWork.get(workName) : 0) + lineTotal);
}
System.assertEquals(36, lineUpdates.size(), '対象明細Workが36件揃っていません。');
update lineUpdates;

List<Id> readyWorkIds = new List<Id>();
for (Mig_FreeeInvoiceWork__c workRecord : workByName.values()) {
    if (workRecord.Name == 'MFIW-000154') {
        workRecord.ImportStatus__c = '対象外';
        workRecord.ValidationMessage__c =
            'Google Sheets備考確認済み: 交通費のみの請求のため移行対象外としました。';
        continue;
    }
    System.assert(workRecord.ResolvedAccount__c != null,
        workRecord.Name + ': 取引先が未確定です。');
    System.assert(workRecord.ResolvedContract__c != null,
        workRecord.Name + ': 契約管理が未確定です。');
    System.assert(workRecord.ResolvedContractPeriod__c != null,
        workRecord.Name + ': 契約期間が未確定です。');
    System.assert(activeLineCountByWork.get(workRecord.Name) > 0,
        workRecord.Name + ': 有効な請求明細がありません。');
    System.assertEquals(workRecord.InvoiceAmount__c, totalByWork.get(workRecord.Name),
        workRecord.Name + ': 請求金額と明細合計が一致しません。');
    workRecord.ImportStatus__c = '反映可能';
    workRecord.ValidationMessage__c = null;
    readyWorkIds.add(workRecord.Id);
}
update workByName.values();

System.debug(LoggingLevel.ERROR,
    'GOOGLE_SHEET_NOTES_APPLIED target=' + workByName.size()
    + ' ready=' + readyWorkIds.size()
    + ' excluded=1'
    + ' newProduct=' + productByName.get('[月払] knock knock AI Enterpriseプラン 1100クレジット').Id);
