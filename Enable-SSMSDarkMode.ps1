#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

$DarkThemeGuid = "1ded0138-47ce-435e-84ef-9ec1f439b749"
$DarkThemeEntry = '[$RootKey$\Themes\{' + $DarkThemeGuid + '}]'
$DisabledDarkThemeEntry = '//' + $DarkThemeEntry

function Get-SsmsExeFromCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return $null
    }

    $Candidate = $Candidate.Trim().Trim('"')
    $Candidate = $Candidate -replace ',\d+$', ''

    if (-not (Test-Path -LiteralPath $Candidate)) {
        return $null
    }

    $item = Get-Item -LiteralPath $Candidate -ErrorAction SilentlyContinue

    if ($item -and -not $item.PSIsContainer -and $item.Name -ieq "Ssms.exe") {
        return $item.FullName
    }

    if ($item -and $item.PSIsContainer) {
        $directCandidates = @(
            (Join-Path $item.FullName "Ssms.exe"),
            (Join-Path $item.FullName "Common7\IDE\Ssms.exe")
        )

        foreach ($directCandidate in $directCandidates) {
            if (Test-Path -LiteralPath $directCandidate) {
                return (Get-Item -LiteralPath $directCandidate).FullName
            }
        }

        $found = Get-ChildItem `
            -LiteralPath $item.FullName `
            -Filter "Ssms.exe" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Find-SsmsFromRegistry {
    $results = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $appPathKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ssms.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\Ssms.exe",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ssms.exe"
    )

    foreach ($key in $appPathKeys) {
        if (-not (Test-Path $key)) {
            continue
        }

        try {
            $keyItem = Get-Item -Path $key -ErrorAction Stop
            $defaultValue = $keyItem.GetValue("")

            if ($defaultValue) {
                $exe = Get-SsmsExeFromCandidate -Candidate $defaultValue

                if ($exe) {
                    [void]$results.Add($exe)
                }
            }
        }
        catch {
        }
    }

    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($registryPath in $uninstallPaths) {
        $entries = Get-ItemProperty $registryPath -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -match "SQL Server Management Studio"
            }

        foreach ($entry in $entries) {
            $candidates = @(
                $entry.InstallLocation,
                $entry.DisplayIcon
            )

            foreach ($candidate in $candidates) {
                if ([string]::IsNullOrWhiteSpace($candidate)) {
                    continue
                }

                $exe = Get-SsmsExeFromCandidate -Candidate $candidate

                if ($exe) {
                    [void]$results.Add($exe)
                }
            }
        }
    }

    return @($results)
}

function Find-SsmsFromPath {
    $results = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $commands = Get-Command "Ssms.exe" -All -ErrorAction SilentlyContinue

    foreach ($command in $commands) {
        if ($command.Source -and (Test-Path -LiteralPath $command.Source)) {
            [void]$results.Add((Get-Item -LiteralPath $command.Source).FullName)
        }
    }

    return @($results)
}

function Find-SsmsFromFileSystem {
    $results = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $fixedDrives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3" -ErrorAction SilentlyContinue

    foreach ($drive in $fixedDrives) {
        $driveRoot = "$($drive.DeviceID)\"

        $programRoots = @(
            (Join-Path $driveRoot "Program Files"),
            (Join-Path $driveRoot "Program Files (x86)")
        )

        foreach ($programRoot in $programRoots) {
            if (-not (Test-Path -LiteralPath $programRoot)) {
                continue
            }

            $ssmsDirectories = Get-ChildItem `
                -LiteralPath $programRoot `
                -Directory `
                -Filter "Microsoft SQL Server Management Studio*" `
                -ErrorAction SilentlyContinue

            foreach ($directory in $ssmsDirectories) {
                $exe = Get-SsmsExeFromCandidate -Candidate $directory.FullName

                if ($exe) {
                    [void]$results.Add($exe)
                }
            }
        }
    }

    return @($results)
}

function Find-SsmsInstallations {
    $results = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    Write-Host "Checking registry for SSMS..." -ForegroundColor DarkGray

    foreach ($exe in @(Find-SsmsFromRegistry)) {
        [void]$results.Add($exe)
    }

    Write-Host "Checking PATH for SSMS..." -ForegroundColor DarkGray

    foreach ($exe in @(Find-SsmsFromPath)) {
        [void]$results.Add($exe)
    }

    if ($results.Count -eq 0) {
        Write-Host "Registry and PATH discovery did not locate SSMS." -ForegroundColor Yellow
        Write-Host "Searching Program Files directories on fixed drives..." -ForegroundColor DarkGray

        foreach ($exe in @(Find-SsmsFromFileSystem)) {
            [void]$results.Add($exe)
        }
    }

    return @($results | Sort-Object)
}

function Find-SsmsPkgUndef {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SsmsExe
    )

    $ideDirectory = Split-Path -Parent $SsmsExe
    $directPath = Join-Path $ideDirectory "ssms.pkgundef"

    if (Test-Path -LiteralPath $directPath) {
        return (Get-Item -LiteralPath $directPath).FullName
    }

    $searchRoots = @(
        $ideDirectory,
        (Split-Path -Parent $ideDirectory)
    ) | Select-Object -Unique

    foreach ($searchRoot in $searchRoots) {
        if (-not $searchRoot -or -not (Test-Path -LiteralPath $searchRoot)) {
            continue
        }

        $found = Get-ChildItem `
            -LiteralPath $searchRoot `
            -Filter "ssms.pkgundef" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Enable-SsmsDarkTheme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SsmsExe
    )

    Write-Host ""
    Write-Host "SSMS installation found" -ForegroundColor Cyan
    Write-Host "  Executable: $SsmsExe"

    try {
        $versionInfo = (Get-Item -LiteralPath $SsmsExe).VersionInfo
        $productVersion = $versionInfo.ProductVersion

        if ($productVersion) {
            Write-Host "  Version:    $productVersion"
        }
    }
    catch {
        Write-Host "  Version:    Unable to determine" -ForegroundColor Yellow
    }

    $pkgUndef = Find-SsmsPkgUndef -SsmsExe $SsmsExe

    if (-not $pkgUndef) {
        Write-Host "  ssms.pkgundef was not found." -ForegroundColor Yellow
        Write-Host "  This SSMS installation may provide dark mode without the pkgundef workaround."
        return
    }

    Write-Host "  Config:     $pkgUndef"

    try {
        $lines = [System.IO.File]::ReadAllLines($pkgUndef)
    }
    catch {
        Write-Host "  Unable to read ssms.pkgundef: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $activeIndexes = [System.Collections.Generic.List[int]]::new()
    $disabledIndexes = [System.Collections.Generic.List[int]]::new()

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $trimmed = $lines[$i].Trim()

        if ($trimmed -eq $DarkThemeEntry) {
            $activeIndexes.Add($i)
        }
        elseif ($trimmed -eq $DisabledDarkThemeEntry -or $trimmed -eq ("// " + $DarkThemeEntry)) {
            $disabledIndexes.Add($i)
        }
    }

    if ($disabledIndexes.Count -gt 0 -and $activeIndexes.Count -eq 0) {
        Write-Host "  Dark theme entry is already enabled." -ForegroundColor Green
        return
    }

    if ($activeIndexes.Count -eq 0) {
        Write-Host "  The dark-theme suppression entry was not found." -ForegroundColor Yellow

        $guidMatches = @()

        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i] -like "*$DarkThemeGuid*") {
                $guidMatches += [PSCustomObject]@{
                    LineNumber = $i + 1
                    Text       = $lines[$i].Trim()
                }
            }
        }

        if ($guidMatches.Count -gt 0) {
            Write-Host "  The theme GUID exists in the file:" -ForegroundColor Yellow

            foreach ($match in $guidMatches) {
                Write-Host "    Line $($match.LineNumber): $($match.Text)"
            }
        }
        else {
            Write-Host "  The dark-theme GUID is not present in this file."
        }

        return
    }

    $backupPath = "$pkgUndef.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    try {
        Copy-Item `
            -LiteralPath $pkgUndef `
            -Destination $backupPath `
            -Force
    }
    catch {
        Write-Host "  Unable to create backup: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    foreach ($index in $activeIndexes) {
        $originalLine = $lines[$index]
        $leadingWhitespace = $originalLine.Substring(0, $originalLine.Length - $originalLine.TrimStart().Length)
        $lines[$index] = $leadingWhitespace + "//" + $originalLine.TrimStart()
    }

    try {
        [System.IO.File]::WriteAllLines(
            $pkgUndef,
            $lines,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    catch {
        Write-Host "  Unable to write ssms.pkgundef: $($_.Exception.Message)" -ForegroundColor Red

        try {
            Copy-Item `
                -LiteralPath $backupPath `
                -Destination $pkgUndef `
                -Force

            Write-Host "  Original file restored from backup." -ForegroundColor Yellow
        }
        catch {
            Write-Host "  Automatic restore failed. Backup is located at:" -ForegroundColor Red
            Write-Host "    $backupPath"
        }

        return
    }

    $verificationLines = [System.IO.File]::ReadAllLines($pkgUndef)
    $verified = $false

    foreach ($line in $verificationLines) {
        $trimmed = $line.Trim()

        if ($trimmed -eq $DisabledDarkThemeEntry -or $trimmed -eq ("// " + $DarkThemeEntry)) {
            $verified = $true
            break
        }
    }

    if ($verified) {
        Write-Host "  Dark theme support enabled successfully." -ForegroundColor Green
        Write-Host "  Backup:     $backupPath"
    }
    else {
        Write-Host "  Verification failed. Restoring the original file." -ForegroundColor Red

        Copy-Item `
            -LiteralPath $backupPath `
            -Destination $pkgUndef `
            -Force
    }
}

Write-Host ""
Write-Host "SSMS Dark Theme Enabler" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host ""

$ssmsProcesses = Get-Process "Ssms" -ErrorAction SilentlyContinue

if ($ssmsProcesses) {
    Write-Host "SSMS is currently running." -ForegroundColor Red
    Write-Host "Close all SSMS windows and run this script again."
    exit 1
}

$installations = @(Find-SsmsInstallations)

if ($installations.Count -eq 0) {
    Write-Host ""
    Write-Host "SQL Server Management Studio could not be located." -ForegroundColor Red
    Write-Host ""
    Write-Host "The script checked:"
    Write-Host "  - Windows App Paths registry entries"
    Write-Host "  - Installed-program registry entries"
    Write-Host "  - The current PATH"
    Write-Host "  - Program Files directories on fixed drives"
    exit 1
}

foreach ($ssmsExe in $installations) {
    Enable-SsmsDarkTheme -SsmsExe $ssmsExe
}

Write-Host ""
Write-Host "Finished." -ForegroundColor Cyan
Write-Host ""
Write-Host "Open SSMS and go to:"
Write-Host "  Tools -> Options -> Environment -> General -> Color theme"
Write-Host ""
Write-Host "Select Dark."
