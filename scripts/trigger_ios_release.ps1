<#
.SYNOPSIS
    Eduly iOS TestFlight derlemesini Codemagic uzerinde Git tag (v*) ile tetikler.
.DESCRIPTION
    Windows PowerShell 5.1 uyumludur. main dalinda temiz calisma agacini kontrol eder,
    testleri calistirir, origin/main ve v* etiketini push eder.
#>
[CmdletBinding()]
param(
    [string]$Tag,
    [switch]$SkipTests,
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

Push-Location $RepoRoot
try {
    Write-Section '1. Git Dal ve Calisma Agaci Kontrolu'
    $currentBranch = (& git rev-parse --abbrev-ref HEAD).Trim()
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] Git dal bilgisi alinamadi." -ForegroundColor Red
        exit 1
    }
    if ($currentBranch -ne 'main') {
        Write-Host "[HATA] Su anda '$currentBranch' dalindasiniz. TestFlight yayini yalnizca 'main' dalindan yapilmalidir." -ForegroundColor Red
        exit 1
    }

    $dirtyTracked = & git status --untracked-files=no --porcelain
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] Git durum kontrolu basarisiz." -ForegroundColor Red
        exit 1
    }
    if ($dirtyTracked) {
        Write-Host "[HATA] Takip edilen dosyalarda commit edilmemis degisiklikler var:" -ForegroundColor Red
        $dirtyTracked | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
        Write-Host "       Once degisiklikleri commit edin veya temizleyin." -ForegroundColor Yellow
        exit 1
    }

    Write-Section '2. Surum ve Etiket Belirleme'
    $pubspecPath = Join-Path $RepoRoot 'pubspec.yaml'
    $versionLine = Get-Content -LiteralPath $pubspecPath -Encoding UTF8 | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
    if (-not $versionLine) {
        Write-Host "[HATA] pubspec.yaml icinde version satiri bulunamadi." -ForegroundColor Red
        exit 1
    }

    $rawVersion = ($versionLine -replace '^version:\s*', '').Trim()
    $semVer = ($rawVersion -split '\+')[0].Trim()
    if ([string]::IsNullOrWhiteSpace($Tag)) {
        $Tag = "v$semVer"
    }

    if ($Tag -notmatch '^v') {
        Write-Host "[HATA] Etiket 'v' ile baslamalidir (ornek: v$semVer). Verilen: '$Tag'" -ForegroundColor Red
        exit 1
    }

    Write-Host "Pubspec surumu : $rawVersion"
    Write-Host "Hedef etiket   : $Tag"

    $localTagMatch = & git tag --list $Tag
    if ($localTagMatch) {
        Write-Host "[HATA] '$Tag' etiketi yerelde zaten mevcut. Tekrar TestFlight almak icin -Tag ${Tag}-tf2 seklinde deneyin." -ForegroundColor Red
        exit 1
    }

    $remoteTagMatch = & git ls-remote --tags origin "refs/tags/$Tag"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] origin uzak deposundaki etiketler sorgulanamadi." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    if ($remoteTagMatch) {
        Write-Host "[HATA] '$Tag' etiketi origin uzerinde zaten mevcut. Tekrar TestFlight almak icin -Tag ${Tag}-tf2 seklinde deneyin." -ForegroundColor Red
        exit 1
    }

    if (-not $SkipTests) {
        Write-Section '3. Flutter Analyze & Test'
        & flutter analyze
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[HATA] flutter analyze hata verdi (exit $LASTEXITCODE)." -ForegroundColor Red
            exit $LASTEXITCODE
        }

        & flutter test
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[HATA] flutter test basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } else {
        Write-Host "[ATLANDI] -SkipTests sebebiyle flutter analyze ve flutter test atlandi." -ForegroundColor Yellow
    }

    if ($DryRun) {
        Write-Section 'Dry Run Ozeti (-DryRun)'
        Write-Host "[DRY RUN] Asagidaki islemler uygulanacakti (hicbir push/tag yapilmadi):" -ForegroundColor Yellow
        Write-Host "  1. git push origin main"
        Write-Host "  2. git tag -a $Tag -m `"Eduly $Tag TestFlight release`""
        Write-Host "  3. git push origin $Tag"
        Write-Host "  4. Codemagic: https://codemagic.io/app/6b01c00f6d74f7039d18461a"
        exit 0
    }

    Write-Section '4. origin/main ve Tag Push'
    & git push origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] git push origin main basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }

    & git tag -a $Tag -m "Eduly $Tag TestFlight release"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] git tag olusturulamadi (exit $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }

    & git push origin $Tag
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] git push origin $Tag basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Section 'Codemagic Tetiklendi'
    Write-Host "[OK] '$Tag' etiketi gonderildi. Codemagic iOS -> TestFlight derlemesini buradan izleyebilirsiniz:" -ForegroundColor Green
    Write-Host "https://codemagic.io/app/6b01c00f6d74f7039d18461a" -ForegroundColor Cyan
    exit 0
} finally {
    Pop-Location
}
