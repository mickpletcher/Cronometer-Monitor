Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-CronometerNutritionTargetSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    if (-not (Test-Path -LiteralPath $SchemaPath)) {
        throw "Nutrition target schema not found at '$SchemaPath'."
    }

    return (Get-Content -LiteralPath $SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20)
}

function Get-CronometerAnalysisFieldMap {
    [CmdletBinding()]
    param()

    return @{
        calories = [pscustomobject]@{ Property = 'CaloriesConsumed'; SourceUnit = 'kcal'; TargetUnit = 'kcal'; Conversion = 'None'; DisplayName = 'Calories' }
        protein = [pscustomobject]@{ Property = 'ProteinGrams'; SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'Protein' }
        carbohydrates = [pscustomobject]@{ Property = 'CarbsGrams'; SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'Carbohydrates' }
        fiber = [pscustomobject]@{ Property = 'FiberGrams'; SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'Fiber' }
        fat = [pscustomobject]@{ Property = 'FatGrams'; SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'Fat' }
        omega3 = [pscustomobject]@{ NutrientNames = @('Omega-3'); SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'Omega-3' }
        ala = [pscustomobject]@{ NutrientNames = @('ALA'); SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'ALA' }
        dha = [pscustomobject]@{ NutrientNames = @('DHA'); SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'DHA' }
        epa = [pscustomobject]@{ NutrientNames = @('EPA'); SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'EPA' }
        omega6 = [pscustomobject]@{ NutrientNames = @('Omega-6'); SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'Omega-6' }
        la = [pscustomobject]@{ NutrientNames = @('LA'); SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'LA' }
        saturatedFat = [pscustomobject]@{ Property = 'SaturatedFatGrams'; SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'Saturated Fat' }
        transFat = [pscustomobject]@{ Property = 'TransFatGrams'; SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'Trans Fat' }
        cholesterol = [pscustomobject]@{ Property = 'CholesterolMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Cholesterol' }
        sodium = [pscustomobject]@{ Property = 'SodiumMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Sodium' }
        potassium = [pscustomobject]@{ Property = 'PotassiumMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Potassium' }
        magnesium = [pscustomobject]@{ Property = 'MagnesiumMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Magnesium' }
        phosphorus = [pscustomobject]@{ Property = 'PhosphorusMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Phosphorus' }
        manganese = [pscustomobject]@{ Property = 'ManganeseMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Manganese' }
        selenium = [pscustomobject]@{ Property = 'SeleniumUg'; SourceUnit = 'ug'; TargetUnit = 'mcg'; Conversion = 'None'; DisplayName = 'Selenium' }
        addedSugars = [pscustomobject]@{ Property = 'AddedSugarsGrams'; SourceUnit = 'g'; TargetUnit = 'g'; Conversion = 'None'; DisplayName = 'Added Sugars' }
        vitaminA = [pscustomobject]@{ Property = 'VitaminA_ug'; SourceUnit = 'ug'; TargetUnit = 'mcg'; Conversion = 'None'; DisplayName = 'Vitamin A' }
        vitaminC = [pscustomobject]@{ Property = 'VitaminC_mg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Vitamin C' }
        vitaminD = [pscustomobject]@{ Property = 'VitaminD_IU'; SourceUnit = 'IU'; TargetUnit = 'mcg'; Conversion = 'VitaminD_IU_To_Mcg'; DisplayName = 'Vitamin D' }
        vitaminE = [pscustomobject]@{ Property = 'VitaminE_mg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Vitamin E' }
        vitaminK = [pscustomobject]@{ Property = 'VitaminK_ug'; SourceUnit = 'ug'; TargetUnit = 'mcg'; Conversion = 'None'; DisplayName = 'Vitamin K' }
        vitaminB12 = [pscustomobject]@{ Property = 'B12_Cobalamin_ug'; SourceUnit = 'ug'; TargetUnit = 'mcg'; Conversion = 'None'; DisplayName = 'Vitamin B12' }
        iron = [pscustomobject]@{ Property = 'IronMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Iron' }
        calcium = [pscustomobject]@{ Property = 'CalciumMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Calcium' }
        thiaminB1 = [pscustomobject]@{ Property = 'B1_Thiamine_mg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Thiamin B1' }
        riboflavinB2 = [pscustomobject]@{ Property = 'B2_Riboflavin_mg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Riboflavin B2' }
        niacinB3 = [pscustomobject]@{ Property = 'B3_Niacin_mg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Niacin B3' }
        pantothenicAcidB5 = [pscustomobject]@{ Property = 'B5_PantothenicAcid_mg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Pantothenic Acid B5' }
        pyridoxineB6 = [pscustomobject]@{ Property = 'B6_Pyridoxine_mg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Pyridoxine B6' }
        folate = [pscustomobject]@{ Property = 'Folate_ug'; SourceUnit = 'ug'; TargetUnit = 'mcg'; Conversion = 'None'; DisplayName = 'Folate' }
        zinc = [pscustomobject]@{ Property = 'ZincMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Zinc' }
        copper = [pscustomobject]@{ Property = 'CopperMg'; SourceUnit = 'mg'; TargetUnit = 'mg'; Conversion = 'None'; DisplayName = 'Copper' }
    }
}

function Get-CronometerAnalysisRawValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result,

        [Parameter(Mandatory)]
        [object]$Mapping
    )

    if ($Mapping.PSObject.Properties['Property']) {
        $propertyName = [string]$Mapping.Property
        if (-not [string]::IsNullOrWhiteSpace($propertyName) -and $Result.PSObject.Properties[$propertyName]) {
            return [pscustomobject]@{
                SourceProperty = $propertyName
                RawValue       = $Result.$propertyName
            }
        }
    }

    if ($Mapping.PSObject.Properties['NutrientNames'] -and $Result.PSObject.Properties['Nutrients']) {
        $entries = @($Result.Nutrients)
        foreach ($candidateName in @($Mapping.NutrientNames)) {
            $match = $entries | Where-Object { [string]$_.Name -eq [string]$candidateName } | Select-Object -First 1
            if ($match) {
                return [pscustomobject]@{
                    SourceProperty = ("Nutrients[{0}]" -f [string]$candidateName)
                    RawValue       = $match.Value
                }
            }
        }
    }

    return [pscustomobject]@{
        SourceProperty = ''
        RawValue       = $null
    }
}

function Convert-CronometerAnalysisValue {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value,

        [Parameter()]
        [string]$Conversion = 'None'
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    $numericValue = 0.0
    if (-not [double]::TryParse([string]$Value, [ref]$numericValue)) {
        return $null
    }

    switch ($Conversion) {
        'VitaminD_IU_To_Mcg' {
            return [math]::Round(($numericValue / 40.0), 3)
        }
        default {
            return $numericValue
        }
    }
}

function Get-CronometerAnalysisTargetProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Definition
    )

    $minimumTarget = $null
    $optimalTarget = $null
    $maximumTarget = $null
    $referenceTarget = $null
    $comparisonMode = 'None'
    $targetSource = 'None'
    $notes = [System.Collections.Generic.List[string]]::new()

    if ($Definition.PSObject.Properties['rules'] -and $Definition.rules.PSObject.Properties['limit'] -and [bool]$Definition.rules.limit) {
        if ($Definition.PSObject.Properties['fda'] -and $Definition.fda.PSObject.Properties['max']) {
            $maximumTarget = [double]$Definition.fda.max
            $comparisonMode = 'Maximum'
            $targetSource = 'FDA'
        }
    }

    if ($comparisonMode -eq 'None' -and $Definition.PSObject.Properties['bariatric']) {
        $bariatric = $Definition.bariatric
        if ($bariatric.PSObject.Properties['range']) {
            $minimumTarget = [double]$bariatric.range[0]
            $optimalTarget = [double]$bariatric.range[0]
            $maximumTarget = [double]$bariatric.range[1]
            $comparisonMode = 'Range'
            $targetSource = 'Bariatric'
        }
        elseif ($bariatric.PSObject.Properties['min'] -and $bariatric.PSObject.Properties['optimal']) {
            $minimumTarget = [double]$bariatric.min
            $optimalTarget = [double]$bariatric.optimal
            $comparisonMode = 'MinimumOptimal'
            $targetSource = 'Bariatric'
        }
        elseif ($bariatric.PSObject.Properties['optimal']) {
            $minimumTarget = [double]$bariatric.optimal
            $optimalTarget = [double]$bariatric.optimal
            $comparisonMode = 'Minimum'
            $targetSource = 'Bariatric'
        }
        elseif ($bariatric.PSObject.Properties['min']) {
            $minimumTarget = [double]$bariatric.min
            $optimalTarget = [double]$bariatric.min
            $comparisonMode = 'Minimum'
            $targetSource = 'Bariatric'
        }
        elseif ($bariatric.PSObject.Properties['target']) {
            $minimumTarget = [double]$bariatric.target
            $optimalTarget = [double]$bariatric.target
            $comparisonMode = 'Minimum'
            $targetSource = 'Bariatric'
        }

        if ($bariatric.PSObject.Properties['note']) {
            $notes.Add([string]$bariatric.note)
        }
        if ($bariatric.PSObject.Properties['type']) {
            $notes.Add([string]$bariatric.type)
        }
    }

    if ($comparisonMode -eq 'None' -and $Definition.PSObject.Properties['fda']) {
        $fda = $Definition.fda
        if ($fda.PSObject.Properties['dailyValue']) {
            $minimumTarget = [double]$fda.dailyValue
            $optimalTarget = [double]$fda.dailyValue
            $referenceTarget = [double]$fda.dailyValue
            $comparisonMode = 'Minimum'
            $targetSource = 'FDA'
        }
        elseif ($fda.PSObject.Properties['reference']) {
            $minimumTarget = [double]$fda.reference
            $optimalTarget = [double]$fda.reference
            $referenceTarget = [double]$fda.reference
            $comparisonMode = 'Minimum'
            $targetSource = 'FDA'
        }
        elseif ($fda.PSObject.Properties['max']) {
            $maximumTarget = [double]$fda.max
            $comparisonMode = 'Maximum'
            $targetSource = 'FDA'
        }

        if ($fda.PSObject.Properties['note']) {
            $notes.Add([string]$fda.note)
        }
    }

    return [pscustomobject]@{
        ComparisonMode = $comparisonMode
        TargetSource   = $targetSource
        MinimumTarget  = $minimumTarget
        OptimalTarget  = $optimalTarget
        MaximumTarget  = $maximumTarget
        ReferenceTarget = $referenceTarget
        Notes          = @($notes)
    }
}

function Get-CronometerNutrientAnalysisItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NutrientKey,

        [Parameter(Mandatory)]
        [object]$Definition,

        [Parameter(Mandatory)]
        [object]$Result,

        [Parameter(Mandatory)]
        [hashtable]$FieldMap
    )

    $mapping = if ($FieldMap.ContainsKey($NutrientKey)) { $FieldMap[$NutrientKey] } else { $null }
    $rawValue = $null
    $value = $null
    $status = 'Unmapped'
    $percentOfTarget = $null
    $deficit = $null
    $excess = $null
    $priority = 'None'
    $sourceProperty = ''
    $notes = [System.Collections.Generic.List[string]]::new()

    if ($mapping) {
        $resolvedValue = Get-CronometerAnalysisRawValue -Result $Result -Mapping $mapping
        $sourceProperty = [string]$resolvedValue.SourceProperty
        $rawValue = $resolvedValue.RawValue
        $value = Convert-CronometerAnalysisValue -Value $rawValue -Conversion ([string]$mapping.Conversion)
    }

    $targetProfile = Get-CronometerAnalysisTargetProfile -Definition $Definition

    if ($targetProfile.Notes) {
        foreach ($note in @($targetProfile.Notes)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$note)) {
                $notes.Add([string]$note)
            }
        }
    }

    if ($null -eq $mapping) {
        $notes.Add('No extractor field mapping defined.')
    }
    elseif ($null -eq $value) {
        $status = 'Missing'
        $notes.Add('Extractor value was missing or could not be parsed.')
    }
    else {
        switch ($targetProfile.ComparisonMode) {
            'Maximum' {
                if ($null -ne $targetProfile.MaximumTarget -and $targetProfile.MaximumTarget -gt 0) {
                    $percentOfTarget = [math]::Round(($value / $targetProfile.MaximumTarget) * 100, 1)
                    if ($value -gt $targetProfile.MaximumTarget) {
                        $status = 'Excess'
                        $excess = [math]::Round(($value - $targetProfile.MaximumTarget), 3)
                        $priority = 'High'
                    }
                    else {
                        $status = 'WithinLimit'
                        $priority = 'None'
                    }
                }
            }
            'Range' {
                if ($null -ne $targetProfile.MinimumTarget -and $targetProfile.MinimumTarget -gt 0) {
                    $percentOfTarget = [math]::Round(($value / $targetProfile.MinimumTarget) * 100, 1)
                }

                if ($value -lt $targetProfile.MinimumTarget) {
                    $status = 'Deficient'
                    $deficit = [math]::Round(($targetProfile.MinimumTarget - $value), 3)
                    $priority = 'High'
                }
                elseif ($null -ne $targetProfile.MaximumTarget -and $value -gt $targetProfile.MaximumTarget) {
                    $status = 'High'
                    $excess = [math]::Round(($value - $targetProfile.MaximumTarget), 3)
                    $priority = 'Medium'
                }
                else {
                    $status = 'Optimal'
                    $priority = 'None'
                }
            }
            'MinimumOptimal' {
                if ($null -ne $targetProfile.MinimumTarget -and $targetProfile.MinimumTarget -gt 0) {
                    $percentOfTarget = [math]::Round(($value / $targetProfile.OptimalTarget) * 100, 1)
                }

                if ($value -lt $targetProfile.MinimumTarget) {
                    $status = 'Deficient'
                    $deficit = [math]::Round(($targetProfile.MinimumTarget - $value), 3)
                    $priority = 'High'
                }
                elseif ($null -ne $targetProfile.OptimalTarget -and $value -lt $targetProfile.OptimalTarget) {
                    $status = 'BelowOptimal'
                    $deficit = [math]::Round(($targetProfile.OptimalTarget - $value), 3)
                    $priority = 'Medium'
                }
                else {
                    $status = 'Optimal'
                    $priority = 'None'
                }
            }
            'Minimum' {
                if ($null -ne $targetProfile.MinimumTarget -and $targetProfile.MinimumTarget -gt 0) {
                    $percentOfTarget = [math]::Round(($value / $targetProfile.MinimumTarget) * 100, 1)
                    if ($value -lt $targetProfile.MinimumTarget) {
                        $status = 'Deficient'
                        $deficit = [math]::Round(($targetProfile.MinimumTarget - $value), 3)
                        $priority = 'High'
                    }
                    else {
                        $status = 'Optimal'
                        $priority = 'None'
                    }
                }
            }
            default {
                $status = 'Informational'
                $notes.Add('No numeric target defined in the schema.')
            }
        }
    }

    if ($Definition.PSObject.Properties['rules'] -and $Definition.rules.PSObject.Properties['priority']) {
        if ($status -eq 'Deficient') {
            $priority = 'High'
        }
        $notes.Add(("Priority source: {0}" -f [string]$Definition.rules.priority))
    }

    return [pscustomobject]@{
        NutrientKey      = $NutrientKey
        DisplayName      = if ($mapping) { [string]$mapping.DisplayName } else { $NutrientKey }
        SourceProperty   = $sourceProperty
        SourceUnit       = if ($mapping) { [string]$mapping.SourceUnit } else { '' }
        TargetUnit       = if ($mapping) { [string]$mapping.TargetUnit } else { [string]$Definition.unit }
        Value            = $value
        RawValue         = $rawValue
        Status           = $status
        ComparisonMode   = $targetProfile.ComparisonMode
        TargetSource     = $targetProfile.TargetSource
        MinimumTarget    = $targetProfile.MinimumTarget
        OptimalTarget    = $targetProfile.OptimalTarget
        MaximumTarget    = $targetProfile.MaximumTarget
        ReferenceTarget  = $targetProfile.ReferenceTarget
        PercentOfTarget  = $percentOfTarget
        Deficit          = $deficit
        Excess           = $excess
        Priority         = $priority
        Notes            = @($notes)
    }
}

function Get-CronometerDerivedAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Result,

        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    $schema = Resolve-CronometerNutritionTargetSchema -SchemaPath $SchemaPath
    $fieldMap = Get-CronometerAnalysisFieldMap
    $items = @()

    foreach ($property in $schema.nutritionSchema.nutrients.PSObject.Properties) {
        $items += Get-CronometerNutrientAnalysisItem -NutrientKey $property.Name -Definition $property.Value -Result $Result -FieldMap $fieldMap
    }

    $deficient = @($items | Where-Object { $_.Status -eq 'Deficient' } | Sort-Object @{ Expression = { if ($_.PercentOfTarget -is [double] -or $_.PercentOfTarget -is [int]) { $_.PercentOfTarget } else { 9999 } } }, NutrientKey)
    $belowOptimal = @($items | Where-Object { $_.Status -eq 'BelowOptimal' } | Sort-Object @{ Expression = { if ($_.PercentOfTarget -is [double] -or $_.PercentOfTarget -is [int]) { $_.PercentOfTarget } else { 9999 } } }, NutrientKey)
    $excess = @($items | Where-Object { $_.Status -in @('Excess', 'High') } | Sort-Object Priority, NutrientKey)
    $optimal = @($items | Where-Object { $_.Status -in @('Optimal', 'WithinLimit') })
    $missing = @($items | Where-Object { $_.Status -in @('Missing', 'Unmapped', 'Informational') })

    return [pscustomobject]@{
        AnalysisVersion = '1.0'
        SchemaVersion   = [string]$schema.nutritionSchema.version
        SchemaDescription = [string]$schema.nutritionSchema.description
        DiaryDate       = if ($Result.PSObject.Properties['DiaryDate']) { [string]$Result.DiaryDate } else { '' }
        QueryStatus     = if ($Result.PSObject.Properties['QueryStatus']) { [string]$Result.QueryStatus } else { '' }
        EvaluatedAtUtc  = [datetime]::UtcNow
        RecommendationEngine = $schema.nutritionSchema.recommendationEngine
        Summary         = [pscustomobject]@{
            NutrientCount   = @($items).Count
            DeficientCount  = @($deficient).Count
            BelowOptimalCount = @($belowOptimal).Count
            ExcessCount     = @($excess).Count
            OptimalCount    = @($optimal).Count
            MissingCount    = @($missing).Count
        }
        PriorityDeficiencies = @($deficient | Select-Object -First 5)
        SecondaryDeficiencies = @($belowOptimal | Select-Object -First 5)
        LimitAlerts     = @($excess | Where-Object { $_.Status -eq 'Excess' } | Select-Object -First 5)
        Nutrients       = $items
    }
}
