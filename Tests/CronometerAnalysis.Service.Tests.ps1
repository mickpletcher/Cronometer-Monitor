Describe 'Cronometer analysis service helpers' {
    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $repoRoot -ChildPath 'CronometerAnalysis.Service.ps1')
        $script:schemaPath = Join-Path -Path $repoRoot -ChildPath 'nutrition-targets.schema.json'
    }

    It 'loads the nutrition target schema' {
        $schema = Resolve-CronometerNutritionTargets -SchemaPath $schemaPath

        $schema.nutritionSchema.version | Should -Be '1.0'
        $schema.nutritionSchema.nutrients.protein.bariatric.min | Should -Be 60
        $schema.nutritionSchema.nutrients.vitaminC.fda.dailyValue | Should -Be 90
        $schema.nutritionSchema.nutrients.riboflavinB2.fda.dailyValue | Should -Be 1.3
        $schema.nutritionSchema.nutrients.phosphorus.fda.dailyValue | Should -Be 1250
        $schema.nutritionSchema.nutrients.selenium.fda.dailyValue | Should -Be 55
    }

    It 'converts vitamin D from IU to mcg during analysis' {
        $result = [pscustomobject]@{
            DiaryDate             = 'Apr 30'
            QueryStatus           = 'Parsed'
            RequiredFieldsPresent = $true
            CaloriesConsumed      = 1900
            ProteinGrams          = 70
            CarbsGrams            = 150
            FiberGrams            = 30
            FatGrams              = 60
            SaturatedFatGrams     = 10
            TransFatGrams         = 0
            CholesterolMg         = 200
            SodiumMg              = 2000
            AddedSugarsGrams      = 20
            VitaminA_ug           = 1600
            VitaminD_IU           = 4000
            B12_Cobalamin_ug      = 500
            IronMg                = 50
            CalciumMg             = 1300
            B1_Thiamine_mg        = 15
            Folate_ug             = 500
            ZincMg                = 12
            CopperMg              = 1.2
        }

        $analysis = Get-CronometerDerivedAnalysis -Result $result -SchemaPath $schemaPath
        $vitaminD = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'vitaminD' } | Select-Object -First 1

        $vitaminD.Value | Should -Be 100
        $vitaminD.TargetUnit | Should -Be 'mcg'
        $vitaminD.Status | Should -Be 'Optimal'
    }

    It 'tracks bariatric minimum and optimal protein as separate bands' {
        $result = [pscustomobject]@{
            DiaryDate             = 'Apr 30'
            QueryStatus           = 'Parsed'
            RequiredFieldsPresent = $true
            CaloriesConsumed      = 1900
            ProteinGrams          = 70
            CarbsGrams            = 150
            FiberGrams            = 30
            FatGrams              = 60
            SaturatedFatGrams     = 10
            TransFatGrams         = 0
            CholesterolMg         = 200
            SodiumMg              = 2000
            AddedSugarsGrams      = 20
            VitaminA_ug           = 1600
            VitaminD_IU           = 4000
            B12_Cobalamin_ug      = 500
            IronMg                = 50
            CalciumMg             = 1300
            B1_Thiamine_mg        = 15
            Folate_ug             = 500
            ZincMg                = 12
            CopperMg              = 1.2
        }

        $analysis = Get-CronometerDerivedAnalysis -Result $result -SchemaPath $schemaPath
        $protein = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'protein' } | Select-Object -First 1

        $protein.MinimumTarget | Should -Be 60
        $protein.OptimalTarget | Should -Be 90
        $protein.Status | Should -Be 'BelowOptimal'
        $analysis.Summary.BelowOptimalCount | Should -BeGreaterThan 0
    }

    It 'marks bariatric minimum and limit nutrients correctly' {
        $result = [pscustomobject]@{
            DiaryDate             = 'Apr 30'
            QueryStatus           = 'Parsed'
            RequiredFieldsPresent = $true
            CaloriesConsumed      = 1600
            ProteinGrams          = 50
            CarbsGrams            = 100
            FiberGrams            = 15
            FatGrams              = 40
            SaturatedFatGrams     = 25
            TransFatGrams         = 1
            CholesterolMg         = 320
            SodiumMg              = 2600
            AddedSugarsGrams      = 55
            VitaminA_ug           = 800
            VitaminD_IU           = 400
            B12_Cobalamin_ug      = 150
            IronMg                = 20
            CalciumMg             = 900
            B1_Thiamine_mg        = 5
            Folate_ug             = 200
            ZincMg                = 5
            CopperMg              = 0.5
        }

        $analysis = Get-CronometerDerivedAnalysis -Result $result -SchemaPath $schemaPath
        $protein = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'protein' } | Select-Object -First 1
        $sodium = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'sodium' } | Select-Object -First 1

        $protein.Status | Should -Be 'Deficient'
        $protein.MinimumTarget | Should -Be 60
        $protein.OptimalTarget | Should -Be 90
        $sodium.Status | Should -Be 'Excess'
        $analysis.Summary.DeficientCount | Should -BeGreaterThan 0
        $analysis.Summary.ExcessCount | Should -BeGreaterThan 0
        $analysis.PriorityDeficiencies[0].Priority | Should -Be 'High'
    }

    It 'maps omega values from the flat Nutrients list and scores ALA and LA' {
        $result = [pscustomobject]@{
            DiaryDate             = 'Apr 30'
            QueryStatus           = 'Parsed'
            RequiredFieldsPresent = $true
            Nutrients             = @(
                [pscustomobject]@{ Name = 'Omega-3'; Value = '1.0'; Unit = 'g' }
                [pscustomobject]@{ Name = 'ALA'; Value = '0.8'; Unit = 'g' }
                [pscustomobject]@{ Name = 'DHA'; Value = '0.1'; Unit = 'g' }
                [pscustomobject]@{ Name = 'EPA'; Value = '0.2'; Unit = 'g' }
                [pscustomobject]@{ Name = 'Omega-6'; Value = '0.4'; Unit = 'g' }
                [pscustomobject]@{ Name = 'LA'; Value = '0.4'; Unit = 'g' }
            )
        }

        $analysis = Get-CronometerDerivedAnalysis -Result $result -SchemaPath $schemaPath
        $ala = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'ala' } | Select-Object -First 1
        $la = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'la' } | Select-Object -First 1
        $dha = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'dha' } | Select-Object -First 1
        $omega3 = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'omega3' } | Select-Object -First 1

        $ala.SourceProperty | Should -Be 'Nutrients[ALA]'
        $ala.Value | Should -Be 0.8
        $ala.MinimumTarget | Should -Be 1.6
        $ala.Status | Should -Be 'Deficient'
        $la.SourceProperty | Should -Be 'Nutrients[LA]'
        $la.MinimumTarget | Should -Be 17
        $la.Status | Should -Be 'Deficient'
        $dha.Status | Should -Be 'Informational'
        $omega3.Status | Should -Be 'Informational'
    }

    It 'maps additional vitamin and B complex fields from top level extractor values' {
        $result = [pscustomobject]@{
            DiaryDate             = 'Apr 30'
            QueryStatus           = 'Parsed'
            RequiredFieldsPresent = $true
            VitaminC_mg           = 331
            VitaminE_mg           = 11.3
            VitaminK_ug           = 90
            B2_Riboflavin_mg      = 0.9
            B3_Niacin_mg          = 12
            B5_PantothenicAcid_mg = 3.9
            B6_Pyridoxine_mg      = 11.2
        }

        $analysis = Get-CronometerDerivedAnalysis -Result $result -SchemaPath $schemaPath
        $vitaminC = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'vitaminC' } | Select-Object -First 1
        $riboflavin = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'riboflavinB2' } | Select-Object -First 1
        $niacin = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'niacinB3' } | Select-Object -First 1

        $vitaminC.Value | Should -Be 331
        $vitaminC.MinimumTarget | Should -Be 90
        $vitaminC.Status | Should -Be 'Optimal'
        $riboflavin.Value | Should -Be 0.9
        $riboflavin.MinimumTarget | Should -Be 1.3
        $riboflavin.Status | Should -Be 'Deficient'
        $niacin.Value | Should -Be 12
        $niacin.MinimumTarget | Should -Be 16
        $niacin.Status | Should -Be 'Deficient'
    }

    It 'maps phosphorus manganese and selenium from top level extractor values' {
        $result = [pscustomobject]@{
            DiaryDate             = 'Apr 30'
            QueryStatus           = 'Parsed'
            RequiredFieldsPresent = $true
            PhosphorusMg          = 1802.5
            ManganeseMg           = 1.8
            SeleniumUg            = 41.8
        }

        $analysis = Get-CronometerDerivedAnalysis -Result $result -SchemaPath $schemaPath
        $phosphorus = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'phosphorus' } | Select-Object -First 1
        $manganese = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'manganese' } | Select-Object -First 1
        $selenium = $analysis.Nutrients | Where-Object { $_.NutrientKey -eq 'selenium' } | Select-Object -First 1

        $phosphorus.Value | Should -Be 1802.5
        $phosphorus.MinimumTarget | Should -Be 1250
        $phosphorus.Status | Should -Be 'Optimal'
        $manganese.Value | Should -Be 1.8
        $manganese.MinimumTarget | Should -Be 2.3
        $manganese.Status | Should -Be 'Deficient'
        $selenium.Value | Should -Be 41.8
        $selenium.MinimumTarget | Should -Be 55
        $selenium.Status | Should -Be 'Deficient'
    }
}
