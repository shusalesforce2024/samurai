param(
    [string]$DataDir = 'docs\SamuraiData',
    [string]$OutputDir = 'docs\SamuraiData\output',
    [string]$OnlyObject = ''
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ColIndex([string]$cellRef) {
    $letters = ([regex]::Match($cellRef, '^[A-Z]+')).Value
    $n = 0
    foreach ($ch in $letters.ToCharArray()) {
        $n = $n * 26 + ([int][char]$ch - [int][char]'A' + 1)
    }
    return $n
}

function Get-ZipText($zip, [string]$path) {
    $entry = $zip.GetEntry($path)
    if (-not $entry) { return $null }
    $reader = New-Object System.IO.StreamReader($entry.Open(), [Text.Encoding]::UTF8)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Get-SharedStrings($zip) {
    $entry = $zip.GetEntry('xl/sharedStrings.xml')
    if (-not $entry) { return @() }
    $values = New-Object 'System.Collections.Generic.List[string]'
    $reader = [System.Xml.XmlReader]::Create($entry.Open())
    try {
        $current = $null
        while ($reader.Read()) {
            if ($reader.NodeType -eq [System.Xml.XmlNodeType]::Element -and $reader.LocalName -eq 'si') {
                $current = New-Object System.Text.StringBuilder
            } elseif ($reader.NodeType -eq [System.Xml.XmlNodeType]::Text -and ($null -ne $current)) {
                [void]$current.Append($reader.Value)
            } elseif ($reader.NodeType -eq [System.Xml.XmlNodeType]::EndElement -and $reader.LocalName -eq 'si' -and ($null -ne $current)) {
                $values.Add($current.ToString())
                $current = $null
            }
        }
    } finally {
        $reader.Close()
    }
    return $values
}

function Get-DateStyleIndexes($zip) {
    $xmlText = Get-ZipText $zip 'xl/styles.xml'
    if (-not $xmlText) { return @{} }
    [xml]$xml = $xmlText
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace('x', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')
    $customDateIds = @{}
    foreach ($fmt in $xml.SelectNodes('//x:numFmts/x:numFmt', $ns)) {
        $id = [int]$fmt.numFmtId
        $code = [string]$fmt.formatCode
        if ($code -match '(?i)(yy|mm|dd|h:|ss)') { $customDateIds[$id] = $true }
    }
    $builtInDateIds = @(14,15,16,17,18,19,20,21,22,45,46,47)
    $styleIsDate = @{}
    $i = 0
    foreach ($xf in $xml.SelectNodes('//x:cellXfs/x:xf', $ns)) {
        $numFmtId = [int]$xf.numFmtId
        if ($builtInDateIds -contains $numFmtId -or $customDateIds.ContainsKey($numFmtId)) {
            $styleIsDate[$i] = $true
        }
        $i++
    }
    return $styleIsDate
}

function Convert-CellValue($cell, $sharedStrings, $dateStyles) {
    $type = [string]$cell.t
    $style = if ($cell.s -ne $null -and "$($cell.s)" -ne '') { [int]$cell.s } else { -1 }
    $vNode = $cell.SelectSingleNode('./*[local-name()="v"]')
    $isNode = $cell.SelectSingleNode('./*[local-name()="is"]')
    if ($type -eq 'inlineStr' -and $isNode) {
        return (($isNode.SelectNodes('.//*[local-name()="t"]') | ForEach-Object { $_.InnerText }) -join '')
    }
    if (-not $vNode) { return '' }
    $raw = [string]$vNode.InnerText
    if ($type -eq 's') {
        $idx = [int]$raw
        if ($idx -ge 0 -and $idx -lt $sharedStrings.Count) { return [string]$sharedStrings[$idx] }
        return ''
    }
    if ($type -eq 'b') {
        if ($raw -eq '1') { return 'true' } else { return 'false' }
    }
    if ($style -ge 0 -and $dateStyles.ContainsKey($style) -and $raw -match '^-?\d+(\.\d+)?$') {
        try { return ([DateTime]::FromOADate([double]$raw)).ToString('yyyy-MM-dd') } catch { return $raw }
    }
    return $raw
}

function Read-XlsxFirstSheet([string]$path) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
    try {
        $shared = Get-SharedStrings $zip
        $dateStyles = Get-DateStyleIndexes $zip
        $sheetPath = 'xl/worksheets/sheet1.xml'
        $entry = $zip.GetEntry($sheetPath)
        if (-not $entry) { return [pscustomobject]@{ Headers=@(); Records=@(); SheetRows=0; SheetCols=0 } }
        $rows = New-Object 'System.Collections.Generic.List[object]'
        $reader = [System.Xml.XmlReader]::Create($entry.Open())
        try {
            while ($reader.Read()) {
                if ($reader.NodeType -ne [System.Xml.XmlNodeType]::Element -or $reader.LocalName -ne 'row') { continue }
                $rowNumber = [int]$reader.GetAttribute('r')
                $rowMap = @{}
                $maxCol = 0
                $sub = $reader.ReadSubtree()
                try {
                    while ($sub.Read()) {
                        if ($sub.NodeType -ne [System.Xml.XmlNodeType]::Element -or $sub.LocalName -ne 'c') { continue }
                        $ref = [string]$sub.GetAttribute('r')
                        $type = [string]$sub.GetAttribute('t')
                        $styleAttr = [string]$sub.GetAttribute('s')
                        $style = if ($styleAttr) { [int]$styleAttr } else { -1 }
                        $raw = ''
                        $inline = New-Object System.Text.StringBuilder
                        if (-not $sub.IsEmptyElement) {
                            $cellSub = $sub.ReadSubtree()
                            try {
                                while ($cellSub.Read()) {
                                    if ($cellSub.NodeType -eq [System.Xml.XmlNodeType]::Element -and $cellSub.LocalName -eq 'v') {
                                        $raw = $cellSub.ReadElementContentAsString()
                                    } elseif ($cellSub.NodeType -eq [System.Xml.XmlNodeType]::Element -and $cellSub.LocalName -eq 't') {
                                        [void]$inline.Append($cellSub.ReadElementContentAsString())
                                    }
                                }
                            } finally {
                                $cellSub.Close()
                            }
                        }
                        $val = ''
                        if ($type -eq 'inlineStr') {
                            $val = $inline.ToString()
                        } elseif ($type -eq 's') {
                            if ($raw -ne '') {
                                $idx = [int]$raw
                                if ($idx -ge 0 -and $idx -lt $shared.Count) { $val = [string]$shared[$idx] }
                            }
                        } elseif ($type -eq 'b') {
                            if ($raw -eq '1') { $val = 'true' } else { $val = 'false' }
                        } elseif ($style -ge 0 -and $dateStyles.ContainsKey($style) -and $raw -match '^-?\d+(\.\d+)?$') {
                            try { $val = ([DateTime]::FromOADate([double]$raw)).ToString('yyyy-MM-dd') } catch { $val = $raw }
                        } else {
                            $val = $raw
                        }
                        $col = Get-ColIndex $ref
                        $rowMap[$col] = $val
                        if ($col -gt $maxCol) { $maxCol = $col }
                    }
                } finally {
                    $sub.Close()
                }
                $rows.Add([pscustomobject]@{ RowNumber = $rowNumber; Cells = $rowMap; MaxCol = $maxCol })
            }
        } finally {
            $reader.Close()
        }
        if ($rows.Count -eq 0) { return [pscustomobject]@{ Headers=@(); Records=@(); SheetRows=0; SheetCols=0; RawRows=@() } }
        $max = ($rows | Measure-Object -Property MaxCol -Maximum).Maximum
        return [pscustomobject]@{ Headers=@(); Records=@(); SheetRows=$rows.Count; SheetCols=$max; RawRows=$rows.ToArray() }
    } finally {
        $zip.Dispose()
    }
}

function Get-FieldMetadata([string]$objectApi) {
    $fieldDir = Join-Path 'force-app/main/default/objects' (Join-Path $objectApi 'fields')
    $fields = @()
    if (Test-Path $fieldDir) {
        Get-ChildItem -LiteralPath $fieldDir -Filter '*.field-meta.xml' | ForEach-Object {
            [xml]$x = Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName
            $full = [string]$x.CustomField.fullName
            $label = [string]$x.CustomField.label
            $type = [string]$x.CustomField.type
            $required = [string]$x.CustomField.required
            $refTo = @()
            foreach ($r in $x.CustomField.referenceTo) { if ([string]$r) { $refTo += [string]$r } }
            $values = @()
            foreach ($v in $x.SelectNodes('//*[local-name()="value"]')) {
                $fn = $v.SelectSingleNode('./*[local-name()="fullName"]')
                if ($fn) { $values += [string]$fn.InnerText }
            }
            $fields += [pscustomobject]@{
                Api = $full; Label = $label; Type = $type; Required = ($required -eq 'true');
                ReferenceTo = ($refTo -join ';'); PicklistValues = ($values -join ';')
            }
        }
    }
    return $fields
}

function Infer-Type($values) {
    $vals = @($values | Where-Object { $_ -ne $null -and "$_".Trim() -ne '' })
    if ($vals.Count -eq 0) { return '空/不明' }
    $sample = @($vals | Select-Object -First 200)
    $dateCount = @($sample | Where-Object { "$_" -match '^\d{4}-\d{2}-\d{2}$' }).Count
    $boolCount = @($sample | Where-Object { "$_".ToLower() -in @('true','false','1','0','yes','no') }).Count
    $numCount = @($sample | Where-Object { "$_" -match '^-?\d+(\.\d+)?$' }).Count
    if ($dateCount -eq $sample.Count) { return '日付' }
    if ($boolCount -eq $sample.Count) { return '真偽値' }
    if ($numCount -eq $sample.Count) { return '数値' }
    if (@($sample | Where-Object { "$_" -match '^[a-zA-Z0-9]{15,18}$' }).Count -eq $sample.Count) { return '参照ID候補' }
    return 'テキスト'
}

function Normalize-Header([string]$s) {
    if (-not $s) { return '' }
    return ($s -replace '\s','').Trim().ToLowerInvariant()
}

function Find-Field($header, $fields) {
    $h = Normalize-Header $header
    $exactApi = @($fields | Where-Object { (Normalize-Header $_.Api) -eq $h }) | Select-Object -First 1
    if ($exactApi) { return $exactApi }
    $exactLabel = @($fields | Where-Object { (Normalize-Header $_.Label) -eq $h }) | Select-Object -First 1
    if ($exactLabel) { return $exactLabel }
    return $null
}

function Get-Cell($row, [int]$col) {
    if (-not $row) { return '' }
    $v = [string]$row.Cells[$col]
    if ($v -eq $null) { return '' }
    return $v.Trim()
}

function Is-ReadonlyColumn([string]$api, [string]$typeText) {
    $readonlyApis = @(
        'Id','IsDeleted','MasterRecordId','CreatedDate','CreatedById','LastModifiedDate','LastModifiedById',
        'SystemModstamp','LastActivityDate','LastViewedDate','LastReferencedDate','PhotoUrl',
        'BillingAddress','ShippingAddress','MailingAddress','OtherAddress'
    )
    if ($readonlyApis -contains $api) { return $true }
    if ($typeText -match '^数式') { return $true }
    return $false
}

function Is-SalesforceId([string]$value) {
    if (-not $value) { return $true }
    return ($value -match '^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$')
}

function Normalize-Phone([string]$value) {
    if (-not $value) { return '' }
    $v = (($value -split '[,\|]')[0]).Trim()
    $digits = ($v -replace '[^\d]', '')
    if (-not $digits) { return $v }
    if ($digits.Length -eq 11 -and $digits -match '^(050|070|080|090)') {
        return "{0}-{1}-{2}" -f $digits.Substring(0,3), $digits.Substring(3,4), $digits.Substring(7,4)
    }
    if ($digits.Length -eq 10 -and $digits -match '^(03|06)') {
        return "{0}-{1}-{2}" -f $digits.Substring(0,2), $digits.Substring(2,4), $digits.Substring(6,4)
    }
    if ($digits.Length -eq 10) {
        return "{0}-{1}-{2}" -f $digits.Substring(0,3), $digits.Substring(3,3), $digits.Substring(6,4)
    }
    if ($digits.Length -eq 11) {
        return "{0}-{1}-{2}" -f $digits.Substring(0,3), $digits.Substring(3,4), $digits.Substring(7,4)
    }
    return $v
}

function Normalize-Email([string]$value) {
    if (-not $value) { return '' }
    $fullwidthAt = [string][char]0xFF20
    $v = $value.Trim() -replace [regex]::Escape($fullwidthAt), '@'
    return (($v -split '[,\|]')[0]).Trim()
}

function Normalize-DateValue([string]$value, [bool]$asDateTime) {
    if (-not $value) { return '' }
    $v = $value.Trim()
    if ($v -eq '2027-4-31') { $v = '2027-4-30' }
    if ($v -eq '2027-2-31') { $v = '2027-2-28' }
    $formats = @(
        'yyyy-MM-dd HH:mm:ss','yyyy-MM-dd H:mm:ss','yyyy-MM-dd',
        'yyyy/M/d H:mm:ss','yyyy/M/d','yyyy-M-d H:mm:ss','yyyy-M-d'
    )
    $dt = [DateTime]::MinValue
    foreach ($fmt in $formats) {
        if ([DateTime]::TryParseExact($v, $fmt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$dt)) {
            if ($asDateTime) { return $dt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z') }
            return $dt.ToString('yyyy-MM-dd')
        }
    }
    if ([DateTime]::TryParse($v, [ref]$dt)) {
        if ($asDateTime) { return $dt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z') }
        return $dt.ToString('yyyy-MM-dd')
    }
    return $v
}

function Normalize-Boolean([string]$value) {
    if (-not $value) { return '' }
    $v = $value.Trim()
    switch ($v.ToLowerInvariant()) {
        'true' { return 'true' }
        'false' { return 'false' }
        '1' { return 'true' }
        '0' { return 'false' }
        'yes' { return 'true' }
        'no' { return 'false' }
        '希望する' { return 'true' }
        '希望しない' { return 'false' }
        '○' { return 'true' }
        '〇' { return 'true' }
        '×' { return 'false' }
        'x' { return 'false' }
        default { return $v }
    }
}

function Normalize-Number([string]$value) {
    if (-not $value) { return '' }
    $v = $value.Trim()
    $v = $v -replace ',', ''
    $v = $v -replace '[￥¥円%]', ''
    return $v.Trim()
}

function Normalize-ForSalesforce($col, [string]$value) {
    if ($null -eq $value) { return '' }
    $v = $value.Trim()
    if ($v -eq '') { return '' }
    $type = [string]$col.TypeText
    $api = [string]$col.Api
    if ($type -match '電話' -or $api -match '(Phone|Fax)$') { return Normalize-Phone $v }
    if ($api -match 'Email') { return Normalize-Email $v }
    if ($type -match '日付/時間') { return Normalize-DateValue $v $true }
    if ($type -match '^日付$') { return Normalize-DateValue $v $false }
    if ($api -in @('DMFaxConsent__c','TelemarketingTarget__c')) { return $v }
    if ($type -match 'チェックボックス') { return Normalize-Boolean $v }
    if ($type -match '^(数値|通貨|パーセント)') { return Normalize-Number $v }
    return $v
}

function Is-Valid-ForType($col, [string]$value) {
    if (-not $value) { return $true }
    $type = [string]$col.TypeText
    if ($type -match '日付/時間') { return ($value -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.000Z$') }
    if ($type -match '^日付$') { return ($value -match '^\d{4}-\d{2}-\d{2}$') }
    if ($type -match 'チェックボックス') { return ($value -in @('true','false')) }
    if ($type -match '^(数値|通貨|パーセント)') { return ($value -match '^-?\d+(\.\d+)?$') }
    return $true
}

$objectMap = [ordered]@{
    '取引先' = 'Account'
    '取引先責任者' = 'Contact'
    '商品マスタ' = 'ProductMaster__c'
    '契約管理' = 'Contract__c'
    '契約期間' = 'ContractPeriod__c'
    '契約月次明細' = 'ContractLineItem__c'
    '取引' = 'Opportunity__c'
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$summary = @()
$mappings = @()
$issues = @()
$csvPlan = @()

foreach ($name in $objectMap.Keys) {
    if ($OnlyObject -and $objectMap[$name] -ne $OnlyObject -and $name -ne $OnlyObject) { continue }
    Write-Output "PROCESSING $name / $($objectMap[$name])"
    $file = Join-Path $DataDir "$name.xlsx"
    if (-not (Test-Path $file)) {
        $issues += [pscustomobject]@{ Object=$objectMap[$name]; File="$name.xlsx"; Row=''; Column=''; Issue='対象Excelファイルが見つかりません'; Before=''; After=''; Action='要確認' }
        continue
    }
    $objectApi = $objectMap[$name]
    $book = Read-XlsxFirstSheet $file
    $fields = @(Get-FieldMetadata $objectApi)
    $rawRows = @($book.RawRows)
    $labelRow = $rawRows | Where-Object { $_.RowNumber -eq 2 } | Select-Object -First 1
    $apiRow = $rawRows | Where-Object { $_.RowNumber -eq 3 } | Select-Object -First 1
    $typeRow = $rawRows | Where-Object { $_.RowNumber -eq 4 } | Select-Object -First 1
    $lengthRow = $rawRows | Where-Object { $_.RowNumber -eq 5 } | Select-Object -First 1
    $requiredRow = $rawRows | Where-Object { $_.RowNumber -eq 7 } | Select-Object -First 1
    $picklistRow = $rawRows | Where-Object { $_.RowNumber -eq 8 } | Select-Object -First 1
    $externalIdRow = $rawRows | Where-Object { $_.RowNumber -eq 10 } | Select-Object -First 1
    $dataRows = @($rawRows | Where-Object { $_.RowNumber -ge 14 })
    $maxCol = ($rawRows | Measure-Object -Property MaxCol -Maximum).Maximum

    $columns = @()
    for ($c=2; $c -le $maxCol; $c++) {
        $api = Get-Cell $apiRow $c
        if (-not $api) { continue }
        $label = Get-Cell $labelRow $c
        $typeText = Get-Cell $typeRow $c
        $lenText = Get-Cell $lengthRow $c
        $required = ((Get-Cell $requiredRow $c) -match '必須')
        $picklist = Get-Cell $picklistRow $c
        $external = Get-Cell $externalIdRow $c
        $readonly = Is-ReadonlyColumn $api $typeText
        $columns += [pscustomobject]@{
            Col=$c; Api=$api; Label=$label; TypeText=$typeText; Length=$lenText; Required=$required;
            Picklist=$picklist; ExternalId=$external; Readonly=$readonly
        }
    }

    $summary += [pscustomobject]@{ ObjectLabel=$name; ObjectApi=$objectApi; File="$name.xlsx"; Rows=$dataRows.Count; Columns=$columns.Count; Headers=(($columns | ForEach-Object { $_.Api }) -join ' | ') }

    $csvColumns = @($columns | Where-Object { -not $_.Readonly })
    $unmapped = @()
    foreach ($col in $columns) {
        $field = Find-Field $col.Api $fields
        $values = @($dataRows | ForEach-Object { Get-Cell $_ $col.Col })
        $blankCount = @($values | Where-Object { $_ -eq $null -or "$_".Trim() -eq '' }).Count
        if ($field) {
            $mappings += [pscustomobject]@{
                Object=$objectApi; ExcelColumn=$col.Label; SalesforceApi=$col.Api; SalesforceLabel=$field.Label;
                DataType=$col.TypeText; Required=$col.Required; BlankCount=$blankCount; ReferenceTo=$field.ReferenceTo; PicklistValues=$col.Picklist; Readonly=$col.Readonly
            }
            if ($col.Required -and $blankCount -gt 0 -and -not $col.Readonly) {
                $issues += [pscustomobject]@{ Object=$objectApi; File="$name.xlsx"; Row='複数'; Column=$col.Api; Issue="Required field has blanks ($blankCount rows)"; Before=''; After=''; Action='Fix before load' }
            }
            if ($col.Picklist) {
                $allowed = @($col.Picklist -split ';' | Where-Object { $_ })
                $bad = @($values | Where-Object { $_ -and ($allowed -notcontains "$_") } | Select-Object -Unique)
                foreach ($b in $bad) {
                    $issues += [pscustomobject]@{ Object=$objectApi; File="$name.xlsx"; Row='複数'; Column=$col.Api; Issue='Picklist value is not defined'; Before=$b; After=''; Action='Confirm or transform' }
                }
            }
            if ($col.TypeText -match '^参照関係' -and -not $col.Readonly) {
                $badLookup = @($values | Where-Object { $_ -and -not (Is-SalesforceId "$_") } | Select-Object -Unique)
                foreach ($b in $badLookup | Select-Object -First 20) {
                    $issues += [pscustomobject]@{ Object=$objectApi; File="$name.xlsx"; Row='複数'; Column=$col.Api; Issue='Lookup value is not Salesforce ID'; Before=$b; After=''; Action='Replace with Id or External ID reference' }
                }
            }
            if ($col.Length -match '^\d+$') {
                $limit = [int]$col.Length
                $tooLong = @($dataRows | Where-Object { (Get-Cell $_ $col.Col).Length -gt $limit } | Select-Object -First 10)
                foreach ($r in $tooLong) {
                    $v = Get-Cell $r $col.Col
                    $issues += [pscustomobject]@{ Object=$objectApi; File="$name.xlsx"; Row=$r.RowNumber; Column=$col.Api; Issue="Text length exceeds $limit"; Before=$v; After=''; Action='Trim or expand field' }
                }
            }
            if ($col.Api -match 'Email') {
                $badEmailRows = @($dataRows | Where-Object { $v=Normalize-ForSalesforce $col (Get-Cell $_ $col.Col); $v -and ($v -notmatch '^[^@\s,]+@[^@\s,]+\.[^@\s,]+$') } | Select-Object -First 20)
                foreach ($r in $badEmailRows) {
                    $issues += [pscustomobject]@{ Object=$objectApi; File="$name.xlsx"; Row=$r.RowNumber; Column=$col.Api; Issue='Email format invalid after first-value extraction'; Before=(Get-Cell $r $col.Col); After=(Normalize-ForSalesforce $col (Get-Cell $r $col.Col)); Action='Fix before load' }
                }
            }
        } else {
            $unmapped += $col.Api
            $mappings += [pscustomobject]@{
                Object=$objectApi; ExcelColumn=$col.Label; SalesforceApi=$col.Api; SalesforceLabel=''; DataType=$col.TypeText;
                Required=$col.Required; BlankCount=$blankCount; ReferenceTo=''; PicklistValues=$col.Picklist; Readonly=$col.Readonly
            }
        }
    }
    foreach ($u in $unmapped) {
        $issues += [pscustomobject]@{ Object=$objectApi; File="$name.xlsx"; Row=''; Column=$u; Issue='Field metadata not found locally'; Before=''; After=''; Action='Confirm API name or retrieve metadata' }
    }

    $dupCandidates = @('Id','Name','Email','Freee_Partner_Id__c')
    foreach ($key in $dupCandidates) {
        $keyCol = $columns | Where-Object { $_.Api -eq $key } | Select-Object -First 1
        if ($keyCol) {
            $groups = $dataRows | Group-Object -Property { Get-Cell $_ $keyCol.Col } | Where-Object { $_.Name -and $_.Count -gt 1 }
            foreach ($g in $groups | Select-Object -First 20) {
                $issues += [pscustomobject]@{ Object=$objectApi; File="$name.xlsx"; Row='複数'; Column=$key; Issue="Duplicate candidate ($($g.Count) rows)"; Before=$g.Name; After=''; Action='Confirm before Insert' }
            }
        }
    }

    $csvPath = Join-Path $OutputDir "$objectApi.insert.csv"
    $outRecords = @()
    foreach ($row in $dataRows) {
        $obj = [ordered]@{}
        foreach ($col in $csvColumns) {
            $original = Get-Cell $row $col.Col
            $val = Normalize-ForSalesforce $col $original
            if ($original -ne $val) {
                $issues += [pscustomobject]@{ Object=$objectApi; File="$name.xlsx"; Row=$row.RowNumber; Column=$col.Api; Issue='Auto-normalized for Salesforce format'; Before=$original; After=$val; Action='Applied to CSV' }
            }
            if (-not (Is-Valid-ForType $col $val)) {
                $issues += [pscustomobject]@{ Object=$objectApi; File="$name.xlsx"; Row=$row.RowNumber; Column=$col.Api; Issue='Value is still not valid for Salesforce type'; Before=$original; After=$val; Action='Manual fix required' }
            }
            $obj[$col.Api] = $val
        }
        $outRecords += [pscustomobject]$obj
    }
    if ($outRecords.Count -gt 0) {
        $csvText = @($outRecords | ConvertTo-Csv -NoTypeInformation)
    } else {
        $csvText = @(($csvColumns | ForEach-Object { '"' + ($_.Api -replace '"','""') + '"' }) -join ',')
    }
    [System.IO.File]::WriteAllLines((Resolve-Path -LiteralPath $OutputDir).Path + "\$objectApi.insert.csv", $csvText, [System.Text.UTF8Encoding]::new($false))
    $csvPlan += [pscustomobject]@{ Object=$objectApi; Operation='Insert'; Csv="$objectApi.insert.csv"; Rows=$dataRows.Count; CsvColumns=$csvColumns.Count; UnmappedColumns=($unmapped -join ';') }
}

$summary | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDir 'summary.json')
$mappings | ConvertTo-Csv -NoTypeInformation | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDir 'mapping_report.csv')
$issues | ConvertTo-Csv -NoTypeInformation | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDir 'data_quality_issues.csv')
$csvPlan | ConvertTo-Csv -NoTypeInformation | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutputDir 'csv_plan.csv')

Write-Output "SUMMARY"
$summary | Format-Table -AutoSize
Write-Output "CSV_PLAN"
$csvPlan | Format-Table -AutoSize
Write-Output "ISSUE_COUNT=$($issues.Count)"
$issues | Select-Object -First 30 | Format-Table -AutoSize
