<#
.SYNOPSIS
    Eduly Android Release (AAB / APK) yerel derleme ve on kontrol araci.
.DESCRIPTION
    Windows PowerShell 5.1 uyumludur. Android Studio JBR'yi otomatik secer,
    google-services.json ve release imza dosyalarini dogrular, istege bagli
    upload keystore olusturur ve release .aab (ve -Apk ile .apk) uretir.
#>
[CmdletBinding()]
param(
    [switch]$InitKeystore,
    [switch]$Apk,
    [switch]$SkipTests,
    [switch]$PreflightOnly
)

$ErrorActionPreference = 'Continue'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Convert-SecureStringToPlainText {
    param([System.Security.SecureString]$SecureValue)
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

Push-Location $RepoRoot
try {
    Write-Section '1. Java / JBR Ortami'
    $jbrPath = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path $jbrPath) {
        $env:JAVA_HOME = $jbrPath
        $jbrBin = Join-Path $jbrPath 'bin'
        if ($env:PATH -notlike "$jbrBin*") {
            $env:PATH = "$jbrBin;$env:PATH"
        }
        Write-Host "[OK] JAVA_HOME Android Studio JBR olarak ayarlandi: $env:JAVA_HOME" -ForegroundColor Green
    } else {
        Write-Host "[UYARI] Android Studio JBR bulunamadi ($jbrPath). Sistem JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Yellow
    }

    $preflightOk = $true

    Write-Section '2. Firebase google-services.json Kontrolu'
    $googleServicesPath = Join-Path $RepoRoot 'android\app\google-services.json'
    if (-not (Test-Path $googleServicesPath)) {
        Write-Host "[HATA] android/app/google-services.json dosyasi bulunamadi." -ForegroundColor Red
        $preflightOk = $false
    } else {
        try {
            $gsJson = Get-Content -LiteralPath $googleServicesPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $projectId = ''
            if ($null -ne $gsJson.project_info -and $null -ne $gsJson.project_info.project_id) {
                $projectId = [string]$gsJson.project_info.project_id
            }

            $packageNames = @()
            if ($null -ne $gsJson.client) {
                foreach ($client in $gsJson.client) {
                    if ($null -ne $client.client_info -and
                        $null -ne $client.client_info.android_client_info -and
                        $null -ne $client.client_info.android_client_info.package_name) {
                        $packageNames += [string]$client.client_info.android_client_info.package_name
                    }
                }
            }

            $hasEdulyProject = ($projectId -eq 'eduly-server')
            $hasEdulyPackage = ($packageNames -contains 'com.eduly.app')

            if ($hasEdulyProject -and $hasEdulyPackage) {
                Write-Host "[OK] google-services.json gecerli (project_id: $projectId, package: com.eduly.app)." -ForegroundColor Green
            } else {
                $pkgSummary = if ($packageNames.Count -gt 0) { $packageNames -join ', ' } else { 'yok' }
                Write-Host "[HATA] google-services.json guncel Eduly projesiyle eslesmiyor!" -ForegroundColor Red
                Write-Host "       Bulunan project_id : $projectId (beklenen: eduly-server)" -ForegroundColor Red
                Write-Host "       Bulunan paket(ler) : $pkgSummary (beklenen: com.eduly.app)" -ForegroundColor Red
                Write-Host "       Cozum: Firebase Console -> eduly-server -> Project Settings -> Add Android app (com.eduly.app)" -ForegroundColor Yellow
                Write-Host "              Indirilen google-services.json dosyasini android/app/google-services.json uzerine kaydedin." -ForegroundColor Yellow
                $preflightOk = $false
            }
        } catch {
            Write-Host "[HATA] google-services.json okunamadi: $($_.Exception.Message)" -ForegroundColor Red
            $preflightOk = $false
        }
    }

    Write-Section '3. Android Release Keystore Kontrolu'
    $keyPropsPath = Join-Path $RepoRoot 'android\key.properties'
    $keystorePath = Join-Path $RepoRoot 'android\upload-keystore.jks'
    $hasKeyProps = Test-Path $keyPropsPath
    $hasKeystore = Test-Path $keystorePath

    if ($InitKeystore -and (-not $PreflightOnly) -and ((-not $hasKeyProps) -or (-not $hasKeystore))) {
        if (-not $hasKeystore) {
            $keytoolCmd = Get-Command 'keytool' -ErrorAction SilentlyContinue
            if ($null -eq $keytoolCmd) {
                Write-Host "[HATA] keytool komutu bulunamadi. JDK/JBR kurulumunu kontrol edin." -ForegroundColor Red
                exit 1
            }

            Write-Host "Upload keystore olusturuluyor: $keystorePath" -ForegroundColor Cyan
            Write-Host "Not: keytool sizden keystore sifresi, isim/kurum bilgileri ve key sifresi isteyecektir." -ForegroundColor Yellow
            & $keytoolCmd.Source -genkey -v -keystore $keystorePath -keyalg RSA -keysize 2048 -validity 10000 -alias upload
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[HATA] keytool keystore olusturulamadi (exit $LASTEXITCODE)." -ForegroundColor Red
                exit $LASTEXITCODE
            }
            $hasKeystore = Test-Path $keystorePath
        } else {
            Write-Host "[BILGI] Mevcut upload-keystore.jks bulundu; yeniden olusturulmadi." -ForegroundColor Yellow
        }

        if ($hasKeystore -and (-not $hasKeyProps)) {
            Write-Host ""
            Write-Host "android/key.properties olusturmak icin belirlediginiz sifreleri girin:" -ForegroundColor Cyan
            $storeSec = Read-Host -Prompt 'Keystore sifresi (storePassword)' -AsSecureString
            $storePassPlain = Convert-SecureStringToPlainText -SecureValue $storeSec
            $keySec = Read-Host -Prompt 'Key sifresi (keyPassword - ayniysa bos birakip Enter)' -AsSecureString
            $keyPassPlain = Convert-SecureStringToPlainText -SecureValue $keySec
            if ([string]::IsNullOrEmpty($keyPassPlain)) {
                $keyPassPlain = $storePassPlain
            }

            $propsLines = @(
                "storePassword=$storePassPlain",
                "keyPassword=$keyPassPlain",
                "keyAlias=upload",
                "storeFile=../upload-keystore.jks"
            )
            $propsContent = ($propsLines -join "`n") + "`n"
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($keyPropsPath, $propsContent, $utf8NoBom)

            $storePassPlain = $null
            $keyPassPlain = $null
            $hasKeyProps = Test-Path $keyPropsPath
            Write-Host "[OK] android/key.properties olusturuldu (.gitignore korumasinda)." -ForegroundColor Green
        }
    }

    if ($hasKeyProps -and $hasKeystore) {
        Write-Host "[OK] android/key.properties ve android/upload-keystore.jks mevcut." -ForegroundColor Green
    } else {
        if (-not $hasKeyProps) {
            Write-Host "[HATA] android/key.properties eksik." -ForegroundColor Red
        }
        if (-not $hasKeystore) {
            Write-Host "[HATA] android/upload-keystore.jks eksik." -ForegroundColor Red
        }
        Write-Host "       Cozum: Ilk kez keystore ve key.properties uretmek icin su komutu calistirin:" -ForegroundColor Yellow
        Write-Host "       powershell -ExecutionPolicy Bypass -File scripts/build_android_release.ps1 -InitKeystore" -ForegroundColor Yellow
        $preflightOk = $false
    }

    if ($PreflightOnly) {
        Write-Section 'On Kontrol Ozeti (-PreflightOnly)'
        if ($preflightOk) {
            Write-Host "[BASARILI] Tum Android release on kosullari hazir. Derleme icin -PreflightOnly olmadan calistirabilirsiniz." -ForegroundColor Green
            exit 0
        } else {
            Write-Host "[EKSIK VAR] Yukaridaki maddeleri tamamladiktan sonra tekrar deneyin." -ForegroundColor Red
            exit 1
        }
    }

    if (-not $preflightOk) {
        Write-Host ""
        Write-Host "[DURDURULDU] On kontrol basarisiz. Eksikleri tamamlamadan release derlemesi baslatilmadi." -ForegroundColor Red
        exit 1
    }

    Write-Section '4. Flutter Bagimliliklari ve Dogrulama'
    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] flutter pub get basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }

    if (-not $SkipTests) {
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

    Write-Section '5. Android Release Ciktisi (AAB)'
    & flutter build appbundle --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[HATA] flutter build appbundle --release basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }

    $outputs = @()
    $aabPath = Join-Path $RepoRoot 'build\app\outputs\bundle\release\app-release.aab'
    if (Test-Path $aabPath) {
        $outputs += $aabPath
    }

    if ($Apk) {
        Write-Section '6. Android Release APK (-Apk)'
        & flutter build apk --release
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[HATA] flutter build apk --release basarisiz (exit $LASTEXITCODE)." -ForegroundColor Red
            exit $LASTEXITCODE
        }
        $apkPath = Join-Path $RepoRoot 'build\app\outputs\flutter-apk\app-release.apk'
        if (Test-Path $apkPath) {
            $outputs += $apkPath
        }
    }

    Write-Section 'Derleme Tamamlandi'
    foreach ($outFile in $outputs) {
        $fileInfo = Get-Item -LiteralPath $outFile
        $sizeMb = [math]::Round(($fileInfo.Length / 1MB), 2)
        $sha256 = (Get-FileHash -LiteralPath $outFile -Algorithm SHA256).Hash
        Write-Host "Dosya  : $($fileInfo.FullName)" -ForegroundColor Green
        Write-Host "Boyut  : $sizeMb MB"
        Write-Host "SHA256 : $sha256"
        Write-Host ""
    }
    exit 0
} finally {
    Pop-Location
}
