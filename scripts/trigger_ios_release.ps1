<#
.SYNOPSIS
    Eduly iOS TestFlight derlemesini Codemagic uzerinde eduly-testflight dali veya opsiyonel Git tag (v*) ile tetikler.
.DESCRIPTION
    Windows PowerShell 5.1 uyumludur. main dalinda temiz calisma agacini kontrol eder,
    testleri calistirir, varsayilan olarak origin/main ve origin+fork eduly-testflight dallarini senkronize eder.
    Opsiyonel -Tag parametresi verilirse belirtilen v* etiketini olusturup gonderir.
#>
[CmdletBinding()]
param(
    [string]$Tag,
    [switch]$SkipTests,
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$CodemagicUrl = 'https://codemagic.io/builds?app_id=6b01c00f6d74f7039d18461a'

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

    $remotes = @(& git remote)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] Git uzak depolari okunamadi." -ForegroundColor Red
        exit 1
    }
    $hasFork = ($remotes -contains 'fork')

    Write-Section '2. Surum ve Tetikleme Modu Kontrolu'
    $pubspecPath = Join-Path $RepoRoot 'pubspec.yaml'
    $versionLine = Get-Content -LiteralPath $pubspecPath -Encoding UTF8 | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
    if (-not $versionLine) {
        Write-Host "[HATA] pubspec.yaml icinde version satiri bulunamadi." -ForegroundColor Red
        exit 1
    }

    $rawVersion = ($versionLine -replace '^version:\s*', '').Trim()
    $semVer = ($rawVersion -split '\+')[0].Trim()
    $useTagMode = -not [string]::IsNullOrWhiteSpace($Tag)

    Write-Host "Pubspec surumu : $rawVersion"
    Write-Host "Fork deposu    : $(if ($hasFork) { 'var (fork/eduly-testflight senkronize edilecek)' } else { 'yok (yalnizca origin)' })"

    if ($useTagMode) {
        $Tag = $Tag.Trim()
        if ($Tag -notmatch '^v') {
            Write-Host "[HATA] Etiket 'v' ile baslamalidir (ornek: v$semVer-tf2). Verilen: '$Tag'" -ForegroundColor Red
            exit 1
        }
        Write-Host "Tetikleme modu : Git Tag ($Tag)"

        $localTagMatch = & git tag --list $Tag
        if ($localTagMatch) {
            Write-Host "[HATA] '$Tag' etiketi yerelde zaten mevcut. Ornek yeni etiket: -Tag v${semVer}-tf2" -ForegroundColor Red
            exit 1
        }

        $originTagMatch = & git ls-remote --tags origin "refs/tags/$Tag"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[HATA] origin uzak deposundaki etiketler sorgulanamadi." -ForegroundColor Red
            exit $LASTEXITCODE
        }
        if ($originTagMatch) {
            Write-Host "[HATA] '$Tag' etiketi origin uzerinde zaten mevcut. Ornek yeni etiket: -Tag v${semVer}-tf2" -ForegroundColor Red
            exit 1
        }

        if ($hasFork) {
            $forkTagMatch = & git ls-remote --tags fork "refs/tags/$Tag"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[HATA] fork uzak deposundaki etiketler sorgulanamadi." -ForegroundColor Red
                exit $LASTEXITCODE
            }
            if ($forkTagMatch) {
                Write-Host "[HATA] '$Tag' etiketi fork uzerinde zaten mevcut. Ornek yeni etiket: -Tag v${semVer}-tf2" -ForegroundColor Red
                exit 1
            }
        }
    } else {
        Write-Host "Tetikleme modu : Dal Push (origin/eduly-testflight$(if ($hasFork) { ' + fork/eduly-testflight' }))"
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
        if ($useTagMode) {
            Write-Host "  2. git tag -a $Tag -m `"Eduly $Tag TestFlight release`""
            Write-Host "  3. git push origin $Tag"
            if ($hasFork) {
                Write-Host "  4. git push fork $Tag"
            }
        } else {
            Write-Host "  2. git push origin main:eduly-testflight"
            if ($hasFork) {
                Write-Host "  3. git push fork main:eduly-testflight"
            }
        }
        Write-Host "  Codemagic: $CodemagicUrl"
        exit 0
    }

    Write-Section '4. Uzak Depo Gonderimi'
    & git push origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] git push origin main basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }

    if ($useTagMode) {
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

        if ($hasFork) {
            & git push fork $Tag
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[HATA] git push fork $Tag basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
                exit $LASTEXITCODE
            }
        }
    } else {
        & git push origin main:eduly-testflight
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[HATA] git push origin main:eduly-testflight basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
            exit $LASTEXITCODE
        }

        if ($hasFork) {
            & git push fork main:eduly-testflight
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[HATA] git push fork main:eduly-testflight basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
                exit $LASTEXITCODE
            }
        }
    }

    Write-Section 'Codemagic Tetiklendi'
    if ($useTagMode) {
        Write-Host "[OK] '$Tag' etiketi gonderildi." -ForegroundColor Green
    } else {
        Write-Host "[OK] eduly-testflight dali guncellendi." -ForegroundColor Green
    }
    Write-Host "Codemagic iOS -> TestFlight derlemesini buradan izleyebilirsiniz:" -ForegroundColor Cyan
    Write-Host $CodemagicUrl -ForegroundColor Cyan
    exit 0
} finally {
    Pop-Location
}
