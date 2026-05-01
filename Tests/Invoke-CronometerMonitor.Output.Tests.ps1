Describe 'ConvertFrom-NutritionResponse output shaping' {
    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $repoRoot -ChildPath 'Invoke-CronometerMonitor.ps1')
        $script:logPath = Join-Path -Path $TestDrive -ChildPath 'CronometerMonitor.test.log'
    }

    It 'renders empty missing signals as None and preserves selector fields' {
        $rawJson = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'fixtures\dom-response-valid-empty-signals.json') -Raw -Encoding UTF8
        $validation = Test-NutritionExtractionPayload -RawJson $rawJson -LogPath $logPath

        $result = ConvertFrom-NutritionResponse `
            -RawJson $rawJson `
            -CalorieGoal 2200 `
            -ProteinGoalGrams 150 `
            -CarbohydrateGoalGrams 200 `
            -FatGoalGrams 70 `
            -ValidationResult $validation `
            -AttemptsUsed 1 `
            -LogPath $logPath

        $result.QueryStatus | Should -Be 'Parsed'
        $result.ValidationStatus | Should -Be 'Passed'
        $result.MissingRequiredSummary | Should -Be 'None'
        $result.MissingSignalsSummary | Should -Be 'None'
        $result.DateSelectorUsed | Should -Be '.diary-date-btn'
        $result.TablesSelectorUsed | Should -Be 'table.targets-table'
        $result.OutputMetadata.SelectorMatchesSummary | Should -Match 'Date=.diary-date-btn'
        $result.OutputMetadata.MissingSignalsSummary | Should -Be 'None'
    }

    It 'handles a single missing signal entry without scalar Count failures' {
        $rawJson = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'fixtures\dom-response-valid-single-signal.json') -Raw -Encoding UTF8
        $validation = Test-NutritionExtractionPayload -RawJson $rawJson -LogPath $logPath

        $result = ConvertFrom-NutritionResponse `
            -RawJson $rawJson `
            -CalorieGoal 2200 `
            -ProteinGoalGrams 150 `
            -CarbohydrateGoalGrams 200 `
            -FatGoalGrams 70 `
            -ValidationResult $validation `
            -AttemptsUsed 1 `
            -LogPath $logPath

        $result.QueryStatus | Should -Be 'Parsed'
        $result.MissingSignalsSummary | Should -Be 'NutrientUnitSelector'
        $result.OutputMetadata.MissingSignals | Should -HaveCount 1
        $result.OutputMetadata.MissingSignals[0] | Should -Be 'NutrientUnitSelector'
        $result.OutputMetadata.MissingSignalsSummary | Should -Be 'NutrientUnitSelector'
    }

    It 'surfaces biometrics and grouped diary entries in the shaped output' {
        $rawJson = Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'fixtures\dom-response-valid-with-diary-and-biometrics.json') -Raw -Encoding UTF8
        $validation = Test-NutritionExtractionPayload -RawJson $rawJson -LogPath $logPath

        $result = ConvertFrom-NutritionResponse `
            -RawJson $rawJson `
            -CalorieGoal 2200 `
            -ProteinGoalGrams 150 `
            -CarbohydrateGoalGrams 200 `
            -FatGoalGrams 70 `
            -ValidationResult $validation `
            -AttemptsUsed 1 `
            -LogPath $logPath

        $result.SchemaVersion | Should -Be '2.1'
        $result.Biometrics | Should -HaveCount 2
        $result.Biometrics[1].Name | Should -Be 'Blood Pressure'
        $result.Biometrics[1].Systolic | Should -Be 136
        $result.Biometrics[1].Diastolic | Should -Be 87
        $result.DiaryGroups | Should -HaveCount 2
        $result.DiaryGroups[0].GroupName | Should -Be 'Breakfast'
        $result.DiaryGroups[0].Summary.Calories | Should -Be 160
        $result.DiaryEntries | Should -HaveCount 2
        $result.DiaryEntries[1].EntryType | Should -Be 'Supplement'
        $result.OutputMetadata.BiometricCount | Should -Be 2
        $result.OutputMetadata.DiaryGroupCount | Should -Be 2
        $result.OutputMetadata.DiaryEntryCount | Should -Be 2
    }
}
