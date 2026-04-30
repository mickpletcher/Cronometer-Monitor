Describe 'ConvertFrom-NutritionResponse output shaping' {
    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $repoRoot -ChildPath 'Invoke-CronometerMonitor.ps1')
        $logPath = Join-Path -Path $TestDrive -ChildPath 'CronometerMonitor.test.log'
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
}
