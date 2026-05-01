Describe 'Cronometer history service helpers' {
    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $repoRoot -ChildPath 'CronometerHistory.Service.ps1')
    }

    It 'creates the SQLite store file on initialization' {
        $databasePath = Join-Path -Path $TestDrive -ChildPath 'CronometerHistory.init.sqlite'

        $result = Initialize-CronometerHistoryStore -DatabasePath $databasePath

        $result.Initialized | Should -BeTrue
        (Test-Path -LiteralPath $databasePath) | Should -BeTrue
    }

    It 'saves successful parsed results as daily snapshots' {
        $databasePath = Join-Path -Path $TestDrive -ChildPath 'CronometerHistory.save.sqlite'
        $result = [pscustomobject]@{
            SchemaVersion         = '2.1'
            DiaryDate             = 'Apr 30'
            QueryStatus           = 'Parsed'
            RequiredFieldsPresent = $true
            CaloriesConsumed      = 1800
            ProteinGrams          = 160
            CarbsGrams            = 140
            FatGrams              = 60
            Alerts                = @()
        }

        $saved = Save-CronometerHistorySnapshot -DatabasePath $databasePath -Result $result
        $rows = Get-CronometerHistory -DatabasePath $databasePath -Limit 10

        $saved.Saved | Should -BeTrue
        $rows | Should -HaveCount 1
        $rows[0].SnapshotDateText | Should -Be 'Apr 30'
        $rows[0].CaloriesConsumed | Should -Be 1800
    }

    It 'skips unsuccessful results' {
        $databasePath = Join-Path -Path $TestDrive -ChildPath 'CronometerHistory.skip.sqlite'
        $result = [pscustomobject]@{
            DiaryDate             = 'Apr 30'
            QueryStatus           = 'ValidationFailed'
            RequiredFieldsPresent = $false
        }

        $saved = Save-CronometerHistorySnapshot -DatabasePath $databasePath -Result $result
        $rows = Get-CronometerHistory -DatabasePath $databasePath -Limit 10

        $saved.Saved | Should -BeFalse
        $saved.Reason | Should -Be 'ResultNotEligible'
        @($rows).Count | Should -Be 0
    }

    It 'exports history rows as CSV' {
        $databasePath = Join-Path -Path $TestDrive -ChildPath 'CronometerHistory.export.sqlite'
        $result = [pscustomobject]@{
            SchemaVersion         = '2.1'
            DiaryDate             = 'Apr 29'
            QueryStatus           = 'Parsed'
            RequiredFieldsPresent = $true
            CaloriesConsumed      = 1700
            ProteinGrams          = 150
            CarbsGrams            = 130
            FatGrams              = 55
        }

        [void](Save-CronometerHistorySnapshot -DatabasePath $databasePath -Result $result)
        $exportPath = Join-Path -Path $TestDrive -ChildPath 'history.csv'

        $export = Export-CronometerHistory -DatabasePath $databasePath -OutputPath $exportPath -Format Csv

        $export.Format | Should -Be 'Csv'
        $export.RowCount | Should -Be 1
        (Test-Path -LiteralPath $exportPath) | Should -BeTrue
    }
}
