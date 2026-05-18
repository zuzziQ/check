# =========================================
# WINDOWS RECOMMENDATION AUDIT
# =========================================

Clear-Host

function Good($msg) {
    Write-Host "[ OK ] $msg" -ForegroundColor Green
}

function Warn($msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Bad($msg) {
    Write-Host "[BAD ] $msg" -ForegroundColor Red
}

Write-Host ""
Write-Host "===== HARDWARE AUDIT =====" -ForegroundColor Cyan
Write-Host ""

# =========================================
# SYSTEM INFO
# =========================================

$CPU = Get-CimInstance Win32_Processor
$RAM = Get-CimInstance Win32_ComputerSystem
$Disk = Get-CimInstance Win32_DiskDrive
$TPM = Get-Tpm -ErrorAction SilentlyContinue

$CPUName = $CPU.Name.Trim()
$Cores = $CPU.NumberOfCores
$Threads = $CPU.NumberOfLogicalProcessors

$RAMGB = [math]::Round($RAM.TotalPhysicalMemory / 1GB)

$DiskType = "Unknown"

foreach ($d in $Disk) {

    if ($d.MediaType -match "SSD") {
        $DiskType = "SSD"
    }

    elseif ($d.Model -match "NVMe") {
        $DiskType = "NVMe"
    }

    elseif ($d.MediaType -match "HDD|Fixed") {
        if ($DiskType -eq "Unknown") {
            $DiskType = "HDD"
        }
    }
}

$TPMEnabled = $false

if ($TPM) {
    $TPMEnabled = $TPM.TpmPresent
}

# =========================================
# DISPLAY INFO
# =========================================

Write-Host "Computer : $env:COMPUTERNAME"
Write-Host "CPU      : $CPUName"
Write-Host "Cores    : $Cores"
Write-Host "Threads  : $Threads"
Write-Host "RAM      : $RAMGB GB"
Write-Host "Storage  : $DiskType"
Write-Host "TPM      : $TPMEnabled"

# =========================================
# WINDOWS RECOMMENDATION
# =========================================

Write-Host ""
Write-Host "===== RECOMMENDATION =====" -ForegroundColor Cyan
Write-Host ""

$Recommendation = ""
$Level = ""

# -----------------------------------------
# VERY OLD PC
# -----------------------------------------

if (
    $RAMGB -le 4 -or
    $DiskType -eq "HDD"
) {

    $Level = "LOW"

    $Recommendation = @"
Recommended:
- Windows 10 Pro
- Office Web
- Office LTSC light usage
- Avoid Windows 11
- Avoid heavy security stack
- Upgrade SSD strongly recommended
"@

    Warn "Low-end machine detected"
}

# -----------------------------------------
# MID RANGE
# -----------------------------------------

elseif (
    $RAMGB -ge 8 -and
    $DiskType -match "SSD|NVMe"
) {

    $Level = "MID"

    $Recommendation = @"
Recommended:
- Windows 10 Pro
- Microsoft 365 Business Standard
- Office Desktop Apps
- Teams acceptable
- Optional Intune
"@

    Good "Mid-range machine detected"
}

# -----------------------------------------
# HIGH END
# -----------------------------------------

if (
    $RAMGB -ge 16 -and
    $DiskType -match "SSD|NVMe" -and
    $TPMEnabled
) {

    $Level = "HIGH"

    $Recommendation = @"
Recommended:
- Windows 11 Pro / Enterprise
- Microsoft 365 Business Premium
- Intune
- Defender for Business
- Full security stack
"@

    Good "High-end machine detected"
}

# =========================================
# OUTPUT
# =========================================

Write-Host ""
Write-Host $Recommendation -ForegroundColor White

# =========================================
# JSON EXPORT
# =========================================

$Output = [PSCustomObject]@{
    Computer = $env:COMPUTERNAME
    CPU = $CPUName
    RAMGB = $RAMGB
    Disk = $DiskType
    TPM = $TPMEnabled
    Level = $Level
    Recommendation = $Recommendation
}

Write-Host ""
Write-Host "===== JSON =====" -ForegroundColor Cyan
Write-Host ""

$Output | ConvertTo-Json -Depth 3
