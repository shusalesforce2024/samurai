param(
    [string]$InputDirectory = "docs/SamuraiData/audit/20260723_mig_work_needs_review",
    [string]$OutputCsv = "docs/freee/freee請求移行Work_要確認対応一覧_20260723.csv",
    [string]$OutputMarkdown = "docs/freee/freee請求移行Work_要確認対応一覧_20260723.md"
)

$ErrorActionPreference = "Stop"

function TextOrBlank($value) {
    if ($null -eq $value) {
        return ""
    }
    return [string]$value
}

function FormatNumber($value) {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        return "-"
    }
    return ([decimal]$value).ToString("#,##0.##")
}

function EscapeMarkdown($value) {
    return (TextOrBlank $value).Replace("|", "\|").Replace("`r", " ").Replace("`n", "<br>")
}

$workPath = Join-Path $InputDirectory "prod_needs_review_work_enriched.json"
$linePath = Join-Path $InputDirectory "prod_needs_review_lines_enriched.json"
$worksRaw = Get-Content -LiteralPath $workPath -Raw | ConvertFrom-Json
$linesRaw = Get-Content -LiteralPath $linePath -Raw | ConvertFrom-Json
$works = if ($worksRaw -is [System.Array]) { $worksRaw } else { @($worksRaw) }
$lines = if ($linesRaw -is [System.Array]) { $linesRaw } else { @($linesRaw) }

$linesByWork = @{}
foreach ($line in $lines) {
    if (-not $linesByWork.ContainsKey($line.InvoiceWork__c)) {
        $linesByWork[$line.InvoiceWork__c] = @()
    }
    $linesByWork[$line.InvoiceWork__c] += $line
}

$rows = @()
$sequence = 0
foreach ($work in $works) {
    $sequence++
    $workLines = if ($linesByWork.ContainsKey($work.Id)) { @($linesByWork[$work.Id]) } else { @() }
    $missingContract = [string]::IsNullOrWhiteSpace((TextOrBlank $work.ResolvedContract__c))
    $missingPeriod = [string]::IsNullOrWhiteSpace((TextOrBlank $work.ResolvedContractPeriod__c))
    $missingProductLines = @($workLines | Where-Object {
        [string]::IsNullOrWhiteSpace((TextOrBlank $_.ConfirmedProductMaster__c))
    })
    $hasProductIssue = $missingProductLines.Count -gt 0
    $message = TextOrBlank $work.ValidationMessage__c
    $hasAmountMismatch = $message.Contains("請求金額と明細合計が一致していません")
    $hasSimilarityIssue = $message.Contains("商品マスタ名が類似していない")
    $hasExistingLineMismatch = $message.Contains("すべての請求明細を照合できませんでした")

    if ($hasExistingLineMismatch) {
        $category = "既存請求明細との照合不一致"
        $priority = "高"
    } elseif ($hasSimilarityIssue) {
        $category = "商品名の類似性不足"
        $priority = "高"
    } elseif ($missingContract -and $hasProductIssue -and $hasAmountMismatch) {
        $category = "契約・商品・金額不一致"
        $priority = "高"
    } elseif ($hasProductIssue -and $hasAmountMismatch) {
        $category = "商品・金額不一致"
        $priority = "高"
    } elseif ($missingContract -and $hasProductIssue) {
        $category = "契約・商品未確定"
        $priority = "中"
    } elseif ($hasAmountMismatch) {
        $category = "金額不一致"
        $priority = "高"
    } elseif ($missingContract -or $missingPeriod) {
        $category = "契約・契約期間未確定"
        $priority = "中"
    } elseif ($hasProductIssue) {
        $category = "商品未確定"
        $priority = "中"
    } else {
        $category = "その他"
        $priority = "中"
    }

    $lineDisplay = @()
    $productQuestions = @()
    $allMissingLinesHaveNamePriceCandidate = $missingProductLines.Count -gt 0
    foreach ($line in $workLines) {
        $suggestedName = if ($null -ne $line.SuggestedProductMaster__r) {
            TextOrBlank $line.SuggestedProductMaster__r.Name
        } else {
            ""
        }
        $confirmedName = if ($null -ne $line.ConfirmedProductMaster__r) {
            TextOrBlank $line.ConfirmedProductMaster__r.Name
        } else {
            ""
        }
        $productName = if (-not [string]::IsNullOrWhiteSpace($confirmedName)) {
            "確定:$confirmedName"
        } elseif (-not [string]::IsNullOrWhiteSpace($suggestedName)) {
            "候補:$suggestedName"
        } else {
            "商品未候補"
        }
        $lineDisplay += "{0} / 数量:{1} / 単価:{2} / 金額:{3} / {4}" -f `
            (TextOrBlank $line.Description__c),
            (FormatNumber $line.Quantity__c),
            (FormatNumber $line.UnitPrice__c),
            (FormatNumber $line.LineAmount__c),
            $productName

        if ([string]::IsNullOrWhiteSpace((TextOrBlank $line.ConfirmedProductMaster__c))) {
            $candidateNotFound = (TextOrBlank $line.ResolveMessage__c) -eq "No ProductMaster candidate found."
            if (-not $candidateNotFound -and -not [string]::IsNullOrWhiteSpace($suggestedName)) {
                $productQuestions += "明細「$($line.Description__c)」（数量 $(FormatNumber $line.Quantity__c)、単価 $(FormatNumber $line.UnitPrice__c) 円）を商品「$suggestedName」としてよいか確認する。"
            } else {
                $allMissingLinesHaveNamePriceCandidate = $false
                $productQuestions += "明細「$($line.Description__c)」（数量 $(FormatNumber $line.Quantity__c)、単価 $(FormatNumber $line.UnitPrice__c) 円）に対応する商品マスタを選ぶ。該当商品がなければ、汎用商品への集約か商品マスタ追加かを判断する。"
            }
            if ((TextOrBlank $line.ResolveMessage__c) -ne "Matched by unit price and product name.") {
                $allMissingLinesHaveNamePriceCandidate = $false
            }
        }
    }

    $questions = @()
    $actions = @()
    $questionCodes = @()
    $individualTargets = @()
    if ($missingContract -or $missingPeriod) {
        $questionCodes += "C01"
        $individualTargets += "請求区分と契約先: $($work.PartnerName__c) / 請求日: $($work.BillingDate__c)"
        $questions += "取引先「$($work.PartnerName__c)」の請求が、月契約・年契約・単発請求のどれに該当するか確認する。"
        $questions += "既存の有効契約へ紐づけるか、新しいFreee管理契約を作成するか確認する。"
        $questions += "請求日 $($work.BillingDate__c) を含む契約期間を作成または選択してよいか確認する。"
        $actions += "確認した商品と請求区分を基に、取引先・商品・件名キーワード・請求区分が一意になるFreee請求契約ルールを登録して有効化する。"
    }
    if ($hasProductIssue) {
        foreach ($line in $missingProductLines) {
            $suggestedName = if ($null -ne $line.SuggestedProductMaster__r) {
                TextOrBlank $line.SuggestedProductMaster__r.Name
            } else {
                ""
            }
            $candidateNotFound = (TextOrBlank $line.ResolveMessage__c) -eq "No ProductMaster candidate found."
            if (-not $candidateNotFound -and -not [string]::IsNullOrWhiteSpace($suggestedName)) {
                $questionCodes += "P01"
                $individualTargets += "商品候補確認: 「$($line.Description__c)」 -> 「$suggestedName」"
            } else {
                $questionCodes += "P02"
                $individualTargets += "商品選択: 「$($line.Description__c)」"
            }
        }
        $questions += $productQuestions
        $actions += "確定商品マスタを設定する。今後も同じ明細名が発生する場合は、Freee請求明細商品マッピングも登録する。"
    }
    if ($hasSimilarityIssue) {
        $questionCodes += "P03"
        foreach ($line in $workLines) {
            $confirmedName = if ($null -ne $line.ConfirmedProductMaster__r) {
                TextOrBlank $line.ConfirmedProductMaster__r.Name
            } else {
                ""
            }
            if (-not [string]::IsNullOrWhiteSpace($confirmedName)) {
                $individualTargets += "商品誤紐づけ確認: 「$($line.Description__c)」 -> 「$confirmedName」"
                $questions += "Freee明細「$($line.Description__c)」を商品「$confirmedName」としてよいか、名称だけでなく単価・数量・契約内容も確認する。"
            }
        }
        $actions += "商品対応が正しければ商品マッピングへ正式な別名として登録する。誤りなら確定商品を解除して正しい商品を選択する。"
    }
    if ($hasAmountMismatch) {
        [decimal]$lineSum = 0
        foreach ($amountLine in $workLines) {
            if ($null -ne $amountLine.LineAmount__c) {
                $lineSum += [decimal]$amountLine.LineAmount__c
            }
        }
        [decimal]$invoiceAmountValue = [Convert]::ToDecimal($work.InvoiceAmount__c)
        [decimal]$difference = $lineSum - $invoiceAmountValue
        if ($difference -eq 0) {
            $questionCodes += "A01"
            $individualTargets += "再検証対象: 請求金額 $(FormatNumber $work.InvoiceAmount__c) 円 = 現在の明細合計 $(FormatNumber $lineSum) 円"
            $questions += "現在のWorkでは請求金額 $(FormatNumber $work.InvoiceAmount__c) 円と明細合計 $(FormatNumber $lineSum) 円が一致している。過去の検証メッセージが残っているため、まず再検証して金額エラーが消えるか確認する。"
            $actions += "データ補正は行わず再検証する。再検証後も金額エラーが残る場合だけ、Raw JSONの税込・税抜金額と税額を調査する。"
        } else {
            $questionCodes += "A02"
            $individualTargets += "金額差異: 請求金額 $(FormatNumber $work.InvoiceAmount__c) 円 / 明細合計 $(FormatNumber $lineSum) 円 / 差額 $(FormatNumber $difference) 円"
            $questions += "Freee原本で、請求金額 $(FormatNumber $work.InvoiceAmount__c) 円が税抜・税込のどちらか、税額と明細合計 $(FormatNumber $lineSum) 円を確認する。現在の差額は $(FormatNumber $difference) 円。"
            if ($invoiceAmountValue -ne 0 -and $lineSum -eq ($invoiceAmountValue * 2)) {
                $questions += "明細合計が請求金額の2倍のため、同じ明細が重複取得されていないか確認する。"
            } else {
                $questions += "差額が消費税、値引き、源泉税、調整額、または明細重複のどれに該当するか確認する。"
            }
            $actions += "Freee原本を正としてWorkの税額・請求金額・明細を補正し、合計一致後に再検証する。"
        }
    }
    if ($hasExistingLineMismatch) {
        $questionCodes += "I01"
        $individualTargets += "明細照合: Salesforce請求「$($work.CreatedInvoice__r.Name)」 / Freee請求書ID $($work.FreeeInvoiceId__c)"
        $questions += "作成済みSalesforce請求「$($work.CreatedInvoice__r.Name)」とFreee請求書ID $($work.FreeeInvoiceId__c) の明細を、Freee明細ID・件名・数量・単価・金額単位で比較する。"
        $questions += "Salesforce側の明細を残す・修正する・不足分を追加するのどれが正しいか確認する。"
        $actions += "既存請求明細を直接削除せず、Freee原本との差分を確定してから不足明細の追加または誤明細の訂正を行う。"
    }
    if ($questions.Count -eq 0) {
        $questionCodes += "O01"
        $individualTargets += "検証メッセージを確認"
        $questions += "検証メッセージとFreee原本を比較し、停止理由が解消しているか確認する。"
    }
    $questionCodes = @($questionCodes | Select-Object -Unique)
    $individualTargets = @($individualTargets | Select-Object -Unique)
    $actions += "修正後にWorkを再検証し、ステータスが「反映可能」になったことを確認して本反映する。"

    if ($hasExistingLineMismatch -or $hasAmountMismatch -or $hasSimilarityIssue) {
        $automation = "不可（個別確認が必要）"
    } elseif ($hasProductIssue -and $allMissingLinesHaveNamePriceCandidate -and -not $missingContract -and -not $missingPeriod) {
        $automation = "条件付き可（候補商品が一意であることを確認）"
    } elseif ($missingContract -or $missingPeriod) {
        $automation = "契約ルール登録後に可"
    } elseif ($hasProductIssue) {
        $automation = "商品確定後に可"
    } else {
        $automation = "再検証後に可"
    }

    $accountName = if ($null -ne $work.ResolvedAccount__r) { TextOrBlank $work.ResolvedAccount__r.Name } else { "" }
    $contractName = if ($null -ne $work.ResolvedContract__r) { TextOrBlank $work.ResolvedContract__r.Name } else { "" }
    $periodName = if ($null -ne $work.ResolvedContractPeriod__r) { TextOrBlank $work.ResolvedContractPeriod__r.Name } else { "" }
    $invoiceName = if ($null -ne $work.CreatedInvoice__r) { TextOrBlank $work.CreatedInvoice__r.Name } else { "" }
    $workUrl = "https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/$($work.Id)/view"

    $rows += [pscustomobject]@{
        No = $sequence
        優先度 = $priority
        主原因 = $category
        Work名 = $work.Name
        SalesforceURL = $workUrl
        Freee請求書ID = $work.FreeeInvoiceId__c
        Freee請求書番号 = $work.FreeeInvoiceNumber__c
        取引先 = $work.PartnerName__c
        解決済み取引先 = $accountName
        請求日 = $work.BillingDate__c
        請求金額 = $work.InvoiceAmount__c
        契約管理 = $contractName
        契約期間 = $periodName
        作成済み請求 = $invoiceName
        請求明細 = ($lineDisplay -join " || ")
        確認コード = ($questionCodes -join ",")
        個別確認対象 = ($individualTargets -join " || ")
        具体的な確認事項 = ($questions -join " ")
        確認後の対応 = ($actions -join " ")
        自動反映可否 = $automation
        担当 = "経理（内容判断）／システム管理者（マスタ・ルール設定）"
        現在の検証メッセージ = $message.Replace("`r", " ").Replace("`n", " / ")
    }
}

$outputCsvDirectory = Split-Path -Parent $OutputCsv
$outputMarkdownDirectory = Split-Path -Parent $OutputMarkdown
New-Item -ItemType Directory -Path $outputCsvDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $outputMarkdownDirectory -Force | Out-Null
$rows | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding utf8

$categorySummary = $rows | Group-Object 主原因 | Sort-Object Count -Descending
$markdown = New-Object System.Collections.Generic.List[string]
$markdown.Add("# Freee請求移行Work 要確認対応一覧")
$markdown.Add("")
$markdown.Add("- 作成日: $((Get-Date).ToString('yyyy-MM-dd'))")
$markdown.Add("- 対象環境: prod")
$markdown.Add("- 対象件数: $($rows.Count)件")
$markdown.Add("- 用途: 経理担当者が各Workの確認内容と対応方法を判断するためのチェックリスト")
$markdown.Add("")
$markdown.Add("## 原因別件数")
$markdown.Add("")
$markdown.Add("| 主原因 | 件数 |")
$markdown.Add("|---|---:|")
foreach ($group in $categorySummary) {
    $markdown.Add("| $(EscapeMarkdown $group.Name) | $($group.Count) |")
}
$markdown.Add("")
$markdown.Add("## 対応順序")
$markdown.Add("")
$markdown.Add("1. 優先度「高」の金額不一致、既存請求明細不一致、商品名類似性不足を確認する。")
$markdown.Add("2. 商品未確定レコードの商品を確定し、再利用できる名称は商品マッピングへ登録する。")
$markdown.Add("3. 契約未確定レコードの請求区分を確認し、Freee請求契約ルールを登録する。")
$markdown.Add("4. Workを再検証し、「反映可能」になったレコードだけ本反映する。")
$markdown.Add("")
$markdown.Add("## 共通確認事項")
$markdown.Add("")
$markdown.Add("同じ内容をレコードごとに繰り返さず、以下の確認コードでまとめています。各レコード固有の確認対象は次の一覧を参照してください。")
$markdown.Add("")
$markdown.Add("| コード | 対象件数 | 共通して確認すること | 確認後の対応 |")
$markdown.Add("|---|---:|---|---|")
$questionDefinitions = @(
    [pscustomobject]@{ Code = "C01"; Question = "請求が月契約・年契約・単発請求のどれか、既存契約へ紐づけるか新規契約を作るか、請求日を含む契約期間を作成してよいか確認する。"; Action = "取引先・商品・件名キーワード・請求区分が一意になるFreee請求契約ルールを登録し、有効化する。" },
    [pscustomobject]@{ Code = "P01"; Question = "Freee明細名・単価・数量と候補商品が一致し、その商品として確定してよいか確認する。"; Action = "候補商品を確定商品に設定し、継続利用する名称は商品マッピングへ登録する。" },
    [pscustomobject]@{ Code = "P02"; Question = "商品候補がない明細について、既存商品、汎用商品、商品マスタ追加のどれで管理するか確認する。"; Action = "商品マスタを選択または追加し、確定商品と商品マッピングを設定する。" },
    [pscustomobject]@{ Code = "P03"; Question = "Freee明細名と確定商品名が類似していないため、単価・数量・契約内容を含めて誤紐づけでないか確認する。"; Action = "正しければ正式な別名として商品マッピングへ登録し、誤りなら正しい商品へ変更する。" },
    [pscustomobject]@{ Code = "A01"; Question = "現在の請求金額と明細合計は一致しているため、古い金額エラーが再検証で消えるか確認する。"; Action = "データを変更せず再検証する。残る場合だけRaw JSONの税込・税抜金額と税額を調査する。" },
    [pscustomobject]@{ Code = "A02"; Question = "現在も請求金額と明細合計が異なるため、税、値引き、源泉税、調整額、明細重複のどれが原因かFreee原本で確認する。"; Action = "Freee原本を正としてWorkの税額・請求金額・明細を補正する。" },
    [pscustomobject]@{ Code = "I01"; Question = "作成済みSalesforce請求とFreee請求の明細を、Freee明細ID・件名・数量・単価・金額単位で比較する。"; Action = "既存明細を直接削除せず、差分確定後に不足明細の追加または誤明細の訂正を行う。" },
    [pscustomobject]@{ Code = "O01"; Question = "検証メッセージとFreee原本を比較し、停止理由が解消しているか確認する。"; Action = "必要な補正後に再検証する。" }
)
foreach ($definition in $questionDefinitions) {
    $targetCount = @($rows | Where-Object { @($_.確認コード -split ",") -contains $definition.Code }).Count
    if ($targetCount -gt 0) {
        $markdown.Add("| $($definition.Code) | $targetCount | $(EscapeMarkdown $definition.Question) | $(EscapeMarkdown $definition.Action) |")
    }
}
$markdown.Add("")
$markdown.Add("## レコード別確認事項")
$markdown.Add("")
$markdown.Add("| No | 優先度 | 主原因 | Work | 取引先 | 請求日 | 金額 | 確認コード | このレコード固有の確認対象 |")
$markdown.Add("|---:|---|---|---|---|---|---:|---|---|")
foreach ($row in $rows) {
    $workLink = "[$(EscapeMarkdown $row.Work名)]($($row.SalesforceURL))"
    $markdown.Add("| $($row.No) | $(EscapeMarkdown $row.優先度) | $(EscapeMarkdown $row.主原因) | $workLink | $(EscapeMarkdown $row.取引先) | $(EscapeMarkdown $row.請求日) | $(FormatNumber $row.請求金額) | $(EscapeMarkdown $row.確認コード) | $(EscapeMarkdown $row.個別確認対象) |")
}

$markdown | Set-Content -LiteralPath $OutputMarkdown -Encoding utf8
Write-Output "rows=$($rows.Count) csv=$OutputCsv markdown=$OutputMarkdown"
