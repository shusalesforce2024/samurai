# ContractLineItem Backfill Actual Result

| Check | Expected | Actual | Result |
|---|---:|---:|---|
| RelatedInvoice updates | 59 | 59 | OK |
| ProductMaster updates | 232 | 232 | OK |

| Metric | Before | After | Delta |
|---|---:|---:|---:|
| RelatedInvoice set | 1 | 60 | 59 |
| ProductMaster set | 0 | 232 | 232 |
| ProductMaster blank | 1515 | 1283 | -232 |

RelatedInvoice mismatch: 0
ProductMaster mismatch: 0

## Additional consistency fix

| Check | Expected | Actual | Result |
|---|---:|---:|---|
| InvoiceStatus changed to billed for records with RelatedInvoice | 59 | 59 | OK |

## Final verification

| Metric | Count |
|---|---:|
| RelatedInvoice set and InvoiceStatus billed | 60 |
| RelatedInvoice set and freee send/payment status visible | 60 |
| ProductMaster set | 232 |
