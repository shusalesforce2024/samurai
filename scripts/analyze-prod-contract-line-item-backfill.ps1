param(
    [string]$AnalysisDir = "docs/SamuraiData/load/prod/analysis"
)

$ErrorActionPreference = "Stop"

function Get-CsvRows($path) {
    if (-not (Test-Path $path)) {
        throw "Missing file: $path"
    }
    return @(Import-Csv -Path $path | Where-Object { $_.Id -and $_.Id -notmatch '^(Querying|Warning|$)' })
}

function Add-ToMapList($map, [string]$key, $value) {
    if (-not $map.ContainsKey($key)) {
        $map[$key] = New-Object System.Collections.ArrayList
    }
    [void]$map[$key].Add($value)
}

function Get-UniqueNonBlank($values) {
    return @($values | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique)
}

$contractLines = Get-CsvRows (Join-Path $AnalysisDir "prod_contract_line_items_current.csv")
$invoices = Get-CsvRows (Join-Path $AnalysisDir "prod_invoices_freee_current.csv")
$invoiceLines = Get-CsvRows (Join-Path $AnalysisDir "prod_invoice_lines_current.csv")
$products = Get-CsvRows (Join-Path $AnalysisDir "prod_product_master_current.csv")

$productById = @{}
foreach ($p in $products) {
    $productById[$p.Id] = $p
}

$firstOnlyValue = -join ([char]0x521D, [char]0x56DE, [char]0x306E, [char]0x307F)
$initialFeeValue = -join ([char]0x521D, [char]0x671F, [char]0x8CBB, [char]0x7528)
$discountWord = -join ([char]0x5272, [char]0x5F15)
$spotPaymentWord = -join ([char]0x90FD, [char]0x5EA6, [char]0x6255, [char]0x3044)
$cancelledValue = -join ([char]0x53D6, [char]0x6D88, [char]0x6E08)
$billedValue = -join ([char]0x8ACB, [char]0x6C42, [char]0x6E08)

$invoiceById = @{}
$invoicesByPeriodMonth = @{}
$invoicesByContract = @{}
foreach ($invoice in $invoices) {
    $invoiceById[$invoice.Id] = $invoice
    if ($invoice.ContractPeriod__c -and $invoice.Billing_Date__c) {
        $month = ([datetime]$invoice.Billing_Date__c).ToString("yyyy/MM")
        Add-ToMapList $invoicesByPeriodMonth "$($invoice.ContractPeriod__c)|$month" $invoice
    }
    if ($invoice.ParentContract__c) {
        Add-ToMapList $invoicesByContract $invoice.ParentContract__c $invoice
    }
}

$linesByInvoice = @{}
foreach ($line in $invoiceLines) {
    Add-ToMapList $linesByInvoice $line.Invoice__c $line
}

function Is-EligibleProduct([string]$productId) {
    if (-not $productId -or -not $productById.ContainsKey($productId)) {
        return $false
    }
    $p = $productById[$productId]
    if ($p.BillingTiming__c -eq $firstOnlyValue) {
        return $false
    }
    if ($p.ProductType__c -eq $initialFeeValue) {
        return $false
    }
    if ($p.Name -match $discountWord -or $p.Name -match $initialFeeValue -or $p.Name -match $spotPaymentWord) {
        return $false
    }
    return ($p.MRR_Target__c -eq "true" -or $p.ARR_Target__c -eq "true")
}

function Get-EligibleProductsFromInvoices($invoiceList) {
    $ids = New-Object System.Collections.ArrayList
    foreach ($invoice in @($invoiceList)) {
        foreach ($line in @($linesByInvoice[$invoice.Id])) {
            if (Is-EligibleProduct $line.ProductMaster__c) {
                [void]$ids.Add($line.ProductMaster__c)
            }
        }
    }
    return Get-UniqueNonBlank $ids
}

$expectedRelatedInvoiceUpdates = New-Object System.Collections.ArrayList
$expectedProductUpdates = New-Object System.Collections.ArrayList
$reviewRows = New-Object System.Collections.ArrayList

$stats = [ordered]@{
    TotalContractLineItems = $contractLines.Count
    RelatedInvoiceAlreadySet = 0
    RelatedInvoiceBlank = 0
    RelatedInvoiceUpdateExpected = 0
    RelatedInvoiceAmbiguous = 0
    RelatedInvoiceNoCandidate = 0
    ProductMasterBlank = 0
    ProductUpdateByRelatedInvoiceExpected = 0
    ProductUpdateByPeriodMonthInvoiceExpected = 0
    ProductUpdateByContractExpected = 0
    ProductAmbiguous = 0
    ProductNoCandidate = 0
}

foreach ($cli in $contractLines) {
    if ($cli.RelatedInvoice__c) {
        $stats.RelatedInvoiceAlreadySet++
    } else {
        $stats.RelatedInvoiceBlank++
    }
    if (-not $cli.ProductMaster__c) {
        $stats.ProductMasterBlank++
    }

    $periodMonthKey = "$($cli.ContractPeriod__c)|$($cli.ContractYearMonth__c)"
    $periodMonthInvoices = @($invoicesByPeriodMonth[$periodMonthKey])
    $uniquePeriodInvoices = @($periodMonthInvoices | Where-Object { $_.Id } | Sort-Object Id -Unique)

    $invoiceForProduct = $null
    $relatedInvoiceReason = ""
    if ($cli.RelatedInvoice__c -and $invoiceById.ContainsKey($cli.RelatedInvoice__c)) {
        $invoiceForProduct = $invoiceById[$cli.RelatedInvoice__c]
        $relatedInvoiceReason = "existing_related_invoice"
    } elseif (-not $cli.RelatedInvoice__c -and $uniquePeriodInvoices.Count -eq 1) {
        $invoiceForProduct = $uniquePeriodInvoices[0]
        $relatedInvoiceReason = "period_month_unique_invoice"
        [void]$expectedRelatedInvoiceUpdates.Add([pscustomobject]@{
            Id = $cli.Id
            RelatedInvoice__c = $invoiceForProduct.Id
            InvoiceStatus__c = if ($invoiceForProduct.CancelStatus__c -eq $cancelledValue) { $cancelledValue } else { $billedValue }
            MatchRule = $relatedInvoiceReason
            ContractLineItemName = $cli.Name
            ContractYearMonth__c = $cli.ContractYearMonth__c
            InvoiceName = $invoiceForProduct.Name
            Billing_Date__c = $invoiceForProduct.Billing_Date__c
            Freee_Invoice_Status__c = $invoiceForProduct.Freee_Invoice_Status__c
            PaymentStatus__c = $invoiceForProduct.PaymentStatus__c
        })
    } elseif (-not $cli.RelatedInvoice__c -and $uniquePeriodInvoices.Count -gt 1) {
        $stats.RelatedInvoiceAmbiguous++
    } elseif (-not $cli.RelatedInvoice__c) {
        $stats.RelatedInvoiceNoCandidate++
    }

    if (-not $cli.ProductMaster__c) {
        $productCandidates = @()
        $productRule = ""

        if ($invoiceForProduct) {
            $productCandidates = @(Get-EligibleProductsFromInvoices @($invoiceForProduct))
            $productRule = "$relatedInvoiceReason invoice_lines"
        }

        if ($productCandidates.Count -eq 0 -and $uniquePeriodInvoices.Count -eq 1) {
            $productCandidates = @(Get-EligibleProductsFromInvoices @($uniquePeriodInvoices[0]))
            $productRule = "period_month_unique_invoice invoice_lines"
        }

        if ($productCandidates.Count -eq 0 -and $cli.MasterContract__c -and $invoicesByContract.ContainsKey($cli.MasterContract__c)) {
            $contractInvoices = @($invoicesByContract[$cli.MasterContract__c])
            $productCandidates = @(Get-EligibleProductsFromInvoices $contractInvoices)
            $productRule = "contract_invoices invoice_lines"
        }

        if ($productCandidates.Count -eq 1) {
            [void]$expectedProductUpdates.Add([pscustomobject]@{
                Id = $cli.Id
                ProductMaster__c = $productCandidates[0]
                ProductName = $productById[$productCandidates[0]].Name
                MatchRule = $productRule
                ContractLineItemName = $cli.Name
                ContractYearMonth__c = $cli.ContractYearMonth__c
                RelatedInvoice__c = if ($invoiceForProduct) { $invoiceForProduct.Id } else { $cli.RelatedInvoice__c }
            })
            if ($productRule -match "existing_related_invoice") {
                $stats.ProductUpdateByRelatedInvoiceExpected++
            } elseif ($productRule -match "period_month_unique_invoice") {
                $stats.ProductUpdateByPeriodMonthInvoiceExpected++
            } else {
                $stats.ProductUpdateByContractExpected++
            }
        } elseif ($productCandidates.Count -gt 1) {
            $stats.ProductAmbiguous++
            [void]$reviewRows.Add([pscustomobject]@{
                Id = $cli.Id
                Name = $cli.Name
                Reason = "multiple_product_candidates"
                ContractYearMonth__c = $cli.ContractYearMonth__c
                CandidateProductIds = ($productCandidates -join ";")
            })
        } else {
            $stats.ProductNoCandidate++
            [void]$reviewRows.Add([pscustomobject]@{
                Id = $cli.Id
                Name = $cli.Name
                Reason = "no_product_candidate"
                ContractYearMonth__c = $cli.ContractYearMonth__c
                CandidateProductIds = ""
            })
        }
    }
}

$stats.RelatedInvoiceUpdateExpected = $expectedRelatedInvoiceUpdates.Count

$expectedRelatedInvoiceUpdates |
    Export-Csv -Path (Join-Path $AnalysisDir "expected_contract_line_item_related_invoice_updates.csv") -NoTypeInformation -Encoding UTF8

$expectedProductUpdates |
    Export-Csv -Path (Join-Path $AnalysisDir "expected_contract_line_item_product_updates.csv") -NoTypeInformation -Encoding UTF8

$reviewRows |
    Export-Csv -Path (Join-Path $AnalysisDir "contract_line_item_product_review_required.csv") -NoTypeInformation -Encoding UTF8

$summaryPath = Join-Path $AnalysisDir "contract_line_item_backfill_expected_summary.md"
$summary = @(
    "# ContractLineItem Backfill Expected Summary",
    "",
    "## Input counts",
    "",
    "| Type | Count |",
    "|---|---:|",
    "| ContractLineItem total | $($stats.TotalContractLineItems) |",
    "| RelatedInvoice already set | $($stats.RelatedInvoiceAlreadySet) |",
    "| RelatedInvoice blank | $($stats.RelatedInvoiceBlank) |",
    "| ProductMaster blank | $($stats.ProductMasterBlank) |",
    "",
    "## Expected updates",
    "",
    "| Update | Expected count |",
    "|---|---:|",
    "| RelatedInvoice deterministic updates | $($stats.RelatedInvoiceUpdateExpected) |",
    "| ProductMaster deterministic updates | $($expectedProductUpdates.Count) |",
    "| ProductMaster via existing RelatedInvoice | $($stats.ProductUpdateByRelatedInvoiceExpected) |",
    "| ProductMaster via period-month invoice | $($stats.ProductUpdateByPeriodMonthInvoiceExpected) |",
    "| ProductMaster via parent contract invoices | $($stats.ProductUpdateByContractExpected) |",
    "",
    "## Excluded from automatic update",
    "",
    "| Reason | Count |",
    "|---|---:|",
    "| RelatedInvoice no candidate | $($stats.RelatedInvoiceNoCandidate) |",
    "| RelatedInvoice multiple candidates | $($stats.RelatedInvoiceAmbiguous) |",
    "| Product no candidate | $($stats.ProductNoCandidate) |",
    "| Product multiple candidates | $($stats.ProductAmbiguous) |",
    "",
    "## Output files",
    "",
    "- expected_contract_line_item_related_invoice_updates.csv",
    "- expected_contract_line_item_product_updates.csv",
    "- contract_line_item_product_review_required.csv"
)

Set-Content -Path $summaryPath -Value $summary -Encoding UTF8

[pscustomobject]$stats | Format-List
