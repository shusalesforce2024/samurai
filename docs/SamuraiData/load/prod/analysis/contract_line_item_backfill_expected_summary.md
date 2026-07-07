# ContractLineItem Backfill Expected Summary

## Input counts

| Type | Count |
|---|---:|
| ContractLineItem total | 1515 |
| RelatedInvoice already set | 1 |
| RelatedInvoice blank | 1514 |
| ProductMaster blank | 1515 |

## Expected updates

| Update | Expected count |
|---|---:|
| RelatedInvoice deterministic updates | 59 |
| ProductMaster deterministic updates | 232 |
| ProductMaster via existing RelatedInvoice | 1 |
| ProductMaster via period-month invoice | 57 |
| ProductMaster via parent contract invoices | 174 |

## Excluded from automatic update

| Reason | Count |
|---|---:|
| RelatedInvoice no candidate | 1452 |
| RelatedInvoice multiple candidates | 3 |
| Product no candidate | 1267 |
| Product multiple candidates | 16 |

## Output files

- expected_contract_line_item_related_invoice_updates.csv
- expected_contract_line_item_product_updates.csv
- contract_line_item_product_review_required.csv
