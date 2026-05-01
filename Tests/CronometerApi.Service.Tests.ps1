Describe 'Cronometer API service helpers' {
    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $repoRoot -ChildPath 'CronometerApi.Service.ps1')
    }

    It 'requires an API key when binding beyond localhost' {
        $requiresKey = Test-CronometerApiKeyRequirement -BindAddress '*' -RequireApiKey $false -ResolvedApiKey $null
        $requiresKey | Should -BeTrue
    }

    It 'returns cache entries while they are fresh' {
        $state = New-CronometerApiState -CacheTtlSeconds 60 -ResultJsonPath (Join-Path -Path $TestDrive -ChildPath 'result.json')
        $now = [datetime]'2026-04-30T18:00:00Z'
        [void](Set-CronometerApiCacheEntry -State $state -Data ([pscustomobject]@{ DiaryDate = 'Today' }) -Source 'FreshExtraction' -NowUtc $now)

        $cacheEntry = Get-CronometerApiCacheEntry -State $state -NowUtc $now.AddSeconds(10)

        $cacheEntry | Should -Not -BeNullOrEmpty
        $cacheEntry.CacheHit | Should -BeTrue
        $cacheEntry.Data.DiaryDate | Should -Be 'Today'
    }

    It 'expires cache entries after the TTL' {
        $state = New-CronometerApiState -CacheTtlSeconds 10 -ResultJsonPath (Join-Path -Path $TestDrive -ChildPath 'result.json')
        $now = [datetime]'2026-04-30T18:00:00Z'
        [void](Set-CronometerApiCacheEntry -State $state -Data ([pscustomobject]@{ DiaryDate = 'Today' }) -Source 'FreshExtraction' -NowUtc $now)

        $cacheEntry = Get-CronometerApiCacheEntry -State $state -NowUtc $now.AddSeconds(11)

        $cacheEntry | Should -BeNullOrEmpty
    }

    It 'loads a fresh result file into cache' {
        $resultPath = Join-Path -Path $TestDrive -ChildPath 'result.json'
        '{"DiaryDate":"Today","SchemaVersion":"2.0"}' | Set-Content -LiteralPath $resultPath -Encoding UTF8
        $state = New-CronometerApiState -CacheTtlSeconds 60 -ResultJsonPath $resultPath

        $entry = Read-CronometerApiResultFile -State $state -NowUtc ([datetime]::UtcNow)

        $entry | Should -Not -BeNullOrEmpty
        $entry.Source | Should -Be 'ResultFile'
        $state.CachedResult.DiaryDate | Should -Be 'Today'
    }
}
