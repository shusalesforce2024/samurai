$ErrorActionPreference = 'Stop'

function New-Directory($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Escape-Xml($Value) {
    if ($null -eq $Value) { return '' }
    return [System.Security.SecurityElement]::Escape([string]$Value)
}

function Write-TextFile($Path, $Content) {
    $parent = Split-Path -Parent $Path
    New-Directory $parent
    $Content | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Picklist-Xml($Values) {
    $lines = @(
        '    <valueSet>',
        '        <restricted>true</restricted>',
        '        <valueSetDefinition>',
        '            <sorted>false</sorted>'
    )

    foreach ($value in $Values) {
        $fullName = if ($value -is [hashtable]) { $value.fullName } else { $value }
        $label = if ($value -is [hashtable] -and $value.label) { $value.label } else { $fullName }
        $default = if ($value -is [hashtable] -and $value.default) { 'true' } else { 'false' }
        $lines += '            <value>'
        $lines += "                <fullName>$(Escape-Xml $fullName)</fullName>"
        $lines += "                <default>$default</default>"
        $lines += "                <label>$(Escape-Xml $label)</label>"
        $lines += '            </value>'
    }

    $lines += @(
        '        </valueSetDefinition>',
        '    </valueSet>'
    )
    return $lines
}

function Field-Xml($Field) {
    $lines = @(
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">',
        "    <fullName>$($Field.fullName)</fullName>"
    )

    switch ($Field.type) {
        'AutoNumber' {
            $lines += "    <displayFormat>$($Field.displayFormat)</displayFormat>"
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <startingNumber>$($Field.startingNumber)</startingNumber>"
            $lines += '    <type>AutoNumber</type>'
        }
        'MasterDetail' {
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <referenceTo>$($Field.referenceTo)</referenceTo>"
            $lines += "    <relationshipLabel>$(Escape-Xml $Field.relationshipLabel)</relationshipLabel>"
            $lines += "    <relationshipName>$($Field.relationshipName)</relationshipName>"
            $lines += '    <reparentableMasterDetail>false</reparentableMasterDetail>'
            $lines += '    <trackHistory>false</trackHistory>'
            $lines += '    <type>MasterDetail</type>'
            $lines += '    <writeRequiresMasterRead>false</writeRequiresMasterRead>'
        }
        'Lookup' {
            $deleteConstraint = if ($Field.deleteConstraint) { $Field.deleteConstraint } elseif ($Field.required) { 'Restrict' } else { 'SetNull' }
            $lines += "    <deleteConstraint>$deleteConstraint</deleteConstraint>"
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <referenceTo>$($Field.referenceTo)</referenceTo>"
            $lines += "    <relationshipLabel>$(Escape-Xml $Field.relationshipLabel)</relationshipLabel>"
            $lines += "    <relationshipName>$($Field.relationshipName)</relationshipName>"
            $lines += "    <required>$([string]$Field.required).ToLower()</required>"
            $lines += '    <trackHistory>false</trackHistory>'
            $lines += '    <trackTrending>false</trackTrending>'
            $lines += '    <type>Lookup</type>'
        }
        'Text' {
            $externalId = if ($Field.externalId) { 'true' } else { 'false' }
            $unique = if ($Field.unique) { 'true' } else { 'false' }
            $lines += "    <externalId>$externalId</externalId>"
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <length>$($Field.length)</length>"
            $lines += "    <required>$([string]$Field.required).ToLower()</required>"
            $lines += '    <trackHistory>false</trackHistory>'
            $lines += '    <trackTrending>false</trackTrending>'
            $lines += '    <type>Text</type>'
            $lines += "    <unique>$unique</unique>"
        }
        'LongTextArea' {
            $lines += '    <externalId>false</externalId>'
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <length>$($Field.length)</length>"
            $lines += "    <required>$([string]$Field.required).ToLower()</required>"
            $lines += '    <type>LongTextArea</type>'
            $lines += "    <visibleLines>$($Field.visibleLines)</visibleLines>"
        }
        'Date' {
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <required>$([string]$Field.required).ToLower()</required>"
            $lines += '    <trackHistory>false</trackHistory>'
            $lines += '    <trackTrending>false</trackTrending>'
            $lines += '    <type>Date</type>'
        }
        'DateTime' {
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <required>$([string]$Field.required).ToLower()</required>"
            $lines += '    <trackHistory>false</trackHistory>'
            $lines += '    <trackTrending>false</trackTrending>'
            $lines += '    <type>DateTime</type>'
        }
        'Checkbox' {
            $default = if ($Field.defaultValue) { $Field.defaultValue } else { 'false' }
            $lines += "    <defaultValue>$default</defaultValue>"
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += '    <trackHistory>false</trackHistory>'
            $lines += '    <trackTrending>false</trackTrending>'
            $lines += '    <type>Checkbox</type>'
        }
        'Picklist' {
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <required>$([string]$Field.required).ToLower()</required>"
            $lines += '    <trackHistory>false</trackHistory>'
            $lines += '    <trackTrending>false</trackTrending>'
            $lines += '    <type>Picklist</type>'
            $lines += Picklist-Xml $Field.values
        }
        { $_ -in @('Number', 'Currency') } {
            $externalId = if ($Field.externalId) { 'true' } else { 'false' }
            $unique = if ($Field.unique) { 'true' } else { 'false' }
            $lines += "    <externalId>$externalId</externalId>"
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <precision>$($Field.precision)</precision>"
            $lines += "    <required>$([string]$Field.required).ToLower()</required>"
            $lines += "    <scale>$($Field.scale)</scale>"
            $lines += '    <trackHistory>false</trackHistory>'
            $lines += '    <trackTrending>false</trackTrending>'
            $lines += "    <type>$($Field.type)</type>"
            $lines += "    <unique>$unique</unique>"
        }
        'Url' {
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <required>$([string]$Field.required).ToLower()</required>"
            $lines += '    <trackHistory>false</trackHistory>'
            $lines += '    <trackTrending>false</trackTrending>'
            $lines += '    <type>Url</type>'
        }
        'FormulaCurrency' {
            $lines += "    <formula>$(Escape-Xml $Field.formula)</formula>"
            $lines += '    <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>'
            $lines += "    <label>$(Escape-Xml $Field.label)</label>"
            $lines += "    <precision>$($Field.precision)</precision>"
            $lines += "    <scale>$($Field.scale)</scale>"
            $lines += '    <type>Currency</type>'
        }
        default {
            throw "Unsupported field type: $($Field.type)"
        }
    }

    $lines += '</CustomField>'
    return ($lines -join "`r`n") + "`r`n"
}

function Write-Field($ObjectName, $Field) {
    $path = Join-Path $Root "force-app\main\default\objects\$ObjectName\fields\$($Field.fullName).field-meta.xml"
    Write-TextFile $path (Field-Xml $Field)
}

function Layout-Item($Field, $Behavior = 'Edit') {
@"
            <layoutItems>
                <behavior>$Behavior</behavior>
                <field>$Field</field>
            </layoutItems>
"@
}

function Layout-Section($Label, $Left, $Right, $Style = 'TwoColumnsTopToBottom', [bool]$CustomLabel = $false) {
    $custom = [string]$CustomLabel
    $leftXml = ($Left -join "`r`n")
    $rightXml = ($Right -join "`r`n")
@"
    <layoutSections>
        <customLabel>$($custom.ToLower())</customLabel>
        <detailHeading>false</detailHeading>
        <editHeading>true</editHeading>
        <label>$(Escape-Xml $Label)</label>
        <layoutColumns>
$leftXml
        </layoutColumns>
        <layoutColumns>
$rightXml
        </layoutColumns>
        <style>$Style</style>
    </layoutSections>
"@
}

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')

$quotationObjectDir = Join-Path $Root 'force-app\main\default\objects\Quotation__c'
$quotationLineObjectDir = Join-Path $Root 'force-app\main\default\objects\QuotationLine__c'
New-Directory (Join-Path $quotationObjectDir 'fields')
New-Directory (Join-Path $quotationObjectDir 'listViews')
New-Directory (Join-Path $quotationLineObjectDir 'fields')
New-Directory (Join-Path $quotationLineObjectDir 'listViews')

$quotationObject = @'
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <description>freee quotation header for creating estimates.</description>
    <enableActivities>true</enableActivities>
    <enableFeeds>true</enableFeeds>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <label>Quotation</label>
    <nameField>
        <displayFormat>QT-{000000}</displayFormat>
        <label>Quotation Number</label>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Quotations</pluralLabel>
    <searchLayouts>
        <customTabListAdditionalFields>Account__c</customTabListAdditionalFields>
        <customTabListAdditionalFields>Subject__c</customTabListAdditionalFields>
        <customTabListAdditionalFields>Issue_Date__c</customTabListAdditionalFields>
        <customTabListAdditionalFields>Freee_Sync_Status__c</customTabListAdditionalFields>
        <searchResultsAdditionalFields>Account__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>Subject__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>Issue_Date__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>Freee_Sync_Status__c</searchResultsAdditionalFields>
    </searchLayouts>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>
'@
Write-TextFile (Join-Path $quotationObjectDir 'Quotation__c.object-meta.xml') $quotationObject

$quotationLineObject = @'
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <description>freee quotation line items for creating estimates.</description>
    <enableActivities>false</enableActivities>
    <enableFeeds>false</enableFeeds>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <label>Quotation Line</label>
    <nameField>
        <displayFormat>QTL-{000000}</displayFormat>
        <label>Quotation Line Number</label>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Quotation Lines</pluralLabel>
    <sharingModel>ControlledByParent</sharingModel>
</CustomObject>
'@
Write-TextFile (Join-Path $quotationLineObjectDir 'QuotationLine__c.object-meta.xml') $quotationLineObject

$quotationFields = @(
    @{ fullName='Account__c'; label='Account'; type='Lookup'; referenceTo='Account'; relationshipLabel='Quotations'; relationshipName='Quotations'; required=$true; deleteConstraint='Restrict' },
    @{ fullName='Issue_Date__c'; label='Issue Date'; type='Date'; required=$true },
    @{ fullName='Quotation_Number__c'; label='Quotation Number'; type='Text'; length='255'; required=$true; externalId=$true; unique=$true },
    @{ fullName='Subject__c'; label='Subject'; type='Text'; length='255'; required=$true },
    @{ fullName='Partner_Display_Name__c'; label='Partner Display Name'; type='Text'; length='255'; required=$false },
    @{ fullName='Partner_Title__c'; label='Partner Title'; type='Picklist'; required=$false; values=@('Onchu','Sama') },
    @{ fullName='Quotation_Status__c'; label='Quotation Status'; type='Picklist'; required=$false; values=@('Draft','Sent','Accepted','Rejected') },
    @{ fullName='Expiration_Date__c'; label='Expiration Date'; type='Date'; required=$false },
    @{ fullName='Memo__c'; label='Memo'; type='LongTextArea'; length='32768'; visibleLines='4'; required=$false },
    @{ fullName='Freee_Account_Item_Picklist__c'; label='freee Account Item Key'; type='Picklist'; required=$false; values=@('sales') },
    @{ fullName='Freee_Partner_Id__c'; label='freee Partner ID'; type='Number'; precision='18'; scale='0'; required=$false },
    @{ fullName='Freee_Quotation_Id__c'; label='freee Quotation ID'; type='Number'; precision='18'; scale='0'; required=$false },
    @{ fullName='Freee_Quotation_Number__c'; label='freee Quotation Number'; type='Text'; length='255'; required=$false },
    @{ fullName='Freee_Quotation_URL__c'; label='freee Quotation URL'; type='Url'; required=$false },
    @{ fullName='Freee_Sync_Status__c'; label='freee Sync Status'; type='Picklist'; required=$false; values=@(@{ fullName='Not Sent'; label='Not Sent'; default=$true }, 'Processing', 'Success', 'Failed') },
    @{ fullName='Freee_Sync_Message__c'; label='freee Sync Message'; type='LongTextArea'; length='32768'; visibleLines='4'; required=$false },
    @{ fullName='Freee_Last_Synced_At__c'; label='freee Last Synced At'; type='DateTime'; required=$false },
    @{ fullName='Sent_To_Freee__c'; label='Sent To freee'; type='Checkbox'; defaultValue='false' },
    @{ fullName='Retry_Count__c'; label='Retry Count'; type='Number'; precision='18'; scale='0'; required=$false },
    @{ fullName='Freee_External_Key__c'; label='freee External Key'; type='Text'; length='255'; required=$false; externalId=$true; unique=$false }
)

$quotationLineFields = @(
    @{ fullName='Quotation__c'; label='Quotation'; type='MasterDetail'; referenceTo='Quotation__c'; relationshipLabel='Quotation Lines'; relationshipName='QuotationLines' },
    @{ fullName='Description__c'; label='Description'; type='Text'; length='255'; required=$true },
    @{ fullName='Quantity__c'; label='Quantity'; type='Number'; precision='18'; scale='2'; required=$true },
    @{ fullName='Unit_Price__c'; label='Unit Price'; type='Currency'; precision='18'; scale='0'; required=$true },
    @{ fullName='Tax_Rate__c'; label='Tax Rate'; type='Picklist'; required=$true; values=@('0','8','10') },
    @{ fullName='Reduced_Tax__c'; label='Reduced Tax'; type='Checkbox'; defaultValue='false' },
    @{ fullName='Withholding__c'; label='Withholding'; type='Checkbox'; defaultValue='false' },
    @{ fullName='Freee_Account_Item_Id__c'; label='freee Account Item ID'; type='Text'; length='255'; required=$false },
    @{ fullName='Sort_Order__c'; label='Sort Order'; type='Number'; precision='18'; scale='0'; required=$false },
    @{ fullName='Line_Amount__c'; label='Line Amount'; type='FormulaCurrency'; precision='18'; scale='0'; formula='Quantity__c * Unit_Price__c' }
)

foreach ($field in $quotationFields) {
    Write-Field 'Quotation__c' $field
}
foreach ($field in $quotationLineFields) {
    Write-Field 'QuotationLine__c' $field
}

$quotationListView = @'
<?xml version="1.0" encoding="UTF-8"?>
<ListView xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>All</fullName>
    <columns>NAME</columns>
    <columns>Account__c</columns>
    <columns>Subject__c</columns>
    <columns>Issue_Date__c</columns>
    <columns>Freee_Sync_Status__c</columns>
    <filterScope>Everything</filterScope>
    <label>All</label>
</ListView>
'@
Write-TextFile (Join-Path $quotationObjectDir 'listViews\All.listView-meta.xml') $quotationListView

$quotationLineListView = @'
<?xml version="1.0" encoding="UTF-8"?>
<ListView xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>All</fullName>
    <columns>NAME</columns>
    <columns>Quotation__c</columns>
    <columns>Description__c</columns>
    <columns>Quantity__c</columns>
    <columns>Unit_Price__c</columns>
    <filterScope>Everything</filterScope>
    <label>All</label>
</ListView>
'@
Write-TextFile (Join-Path $quotationLineObjectDir 'listViews\All.listView-meta.xml') $quotationLineListView

$quotationLayout = @(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<Layout xmlns="http://soap.sforce.com/2006/04/metadata">',
    (Layout-Section 'Information' @(
        (Layout-Item 'Name' 'Readonly'),
        (Layout-Item 'Account__c' 'Required'),
        (Layout-Item 'Issue_Date__c' 'Required'),
        (Layout-Item 'Quotation_Number__c' 'Required'),
        (Layout-Item 'Subject__c' 'Required'),
        (Layout-Item 'Quotation_Status__c'),
        (Layout-Item 'Expiration_Date__c'),
        (Layout-Item 'Memo__c')
    ) @(
        (Layout-Item 'OwnerId'),
        (Layout-Item 'Partner_Display_Name__c'),
        (Layout-Item 'Partner_Title__c'),
        (Layout-Item 'Freee_Account_Item_Picklist__c')
    )),
    (Layout-Section 'freee Sync Information' @(
        (Layout-Item 'Freee_Partner_Id__c'),
        (Layout-Item 'Freee_Quotation_Id__c'),
        (Layout-Item 'Freee_Quotation_Number__c'),
        (Layout-Item 'Freee_Quotation_URL__c'),
        (Layout-Item 'Freee_External_Key__c')
    ) @(
        (Layout-Item 'Freee_Sync_Status__c'),
        (Layout-Item 'Freee_Sync_Message__c'),
        (Layout-Item 'Freee_Last_Synced_At__c'),
        (Layout-Item 'Sent_To_Freee__c'),
        (Layout-Item 'Retry_Count__c')
    )),
    (Layout-Section 'System Information' @(
        (Layout-Item 'CreatedById' 'Readonly')
    ) @(
        (Layout-Item 'LastModifiedById' 'Readonly')
    )),
@'
    <layoutSections>
        <customLabel>false</customLabel>
        <detailHeading>false</detailHeading>
        <editHeading>true</editHeading>
        <layoutColumns/>
        <layoutColumns/>
        <layoutColumns/>
        <style>CustomLinks</style>
    </layoutSections>
    <relatedLists>
        <fields>NAME</fields>
        <fields>Description__c</fields>
        <fields>Quantity__c</fields>
        <fields>Unit_Price__c</fields>
        <fields>Tax_Rate__c</fields>
        <relatedList>QuotationLine__c.Quotation__c</relatedList>
    </relatedLists>
    <relatedLists>
        <fields>TASK.SUBJECT</fields>
        <fields>TASK.WHO_NAME</fields>
        <fields>ACTIVITY.TASK</fields>
        <fields>TASK.DUE_DATE</fields>
        <fields>TASK.STATUS</fields>
        <fields>TASK.PRIORITY</fields>
        <fields>CORE.USERS.FULL_NAME</fields>
        <relatedList>RelatedActivityList</relatedList>
    </relatedLists>
    <relatedLists>
        <fields>TASK.SUBJECT</fields>
        <fields>TASK.WHO_NAME</fields>
        <fields>ACTIVITY.TASK</fields>
        <fields>TASK.DUE_DATE</fields>
        <fields>CORE.USERS.FULL_NAME</fields>
        <fields>TASK.LAST_UPDATE</fields>
        <relatedList>RelatedHistoryList</relatedList>
    </relatedLists>
    <showEmailCheckbox>false</showEmailCheckbox>
    <showHighlightsPanel>false</showHighlightsPanel>
    <showInteractionLogPanel>false</showInteractionLogPanel>
    <showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox>
    <showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>
'@
)
Write-TextFile (Join-Path $Root 'force-app\main\default\layouts\Quotation__c-Quotation Layout.layout-meta.xml') ($quotationLayout -join "`r`n")

$quotationLineLayout = @(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<Layout xmlns="http://soap.sforce.com/2006/04/metadata">',
    (Layout-Section 'Information' @(
        (Layout-Item 'Name' 'Readonly'),
        (Layout-Item 'Quotation__c' 'Required'),
        (Layout-Item 'Description__c' 'Required'),
        (Layout-Item 'Quantity__c' 'Required'),
        (Layout-Item 'Unit_Price__c' 'Required')
    ) @(
        (Layout-Item 'Tax_Rate__c' 'Required'),
        (Layout-Item 'Reduced_Tax__c'),
        (Layout-Item 'Withholding__c'),
        (Layout-Item 'Freee_Account_Item_Id__c'),
        (Layout-Item 'Sort_Order__c'),
        (Layout-Item 'Line_Amount__c' 'Readonly')
    )),
    (Layout-Section 'System Information' @(
        (Layout-Item 'CreatedById' 'Readonly')
    ) @(
        (Layout-Item 'LastModifiedById' 'Readonly')
    )),
@'
    <layoutSections>
        <customLabel>false</customLabel>
        <detailHeading>false</detailHeading>
        <editHeading>true</editHeading>
        <layoutColumns/>
        <layoutColumns/>
        <layoutColumns/>
        <style>CustomLinks</style>
    </layoutSections>
    <showEmailCheckbox>false</showEmailCheckbox>
    <showHighlightsPanel>false</showHighlightsPanel>
    <showInteractionLogPanel>false</showInteractionLogPanel>
    <showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox>
    <showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>
'@
)
Write-TextFile (Join-Path $Root 'force-app\main\default\layouts\QuotationLine__c-Quotation Line Layout.layout-meta.xml') ($quotationLineLayout -join "`r`n")
