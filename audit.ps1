# =========================================
# WINDOWS HARDWARE RECOMMENDATION AUDIT
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
# CPU
# =========================================

$CPU = Get-CimInstance Win32_Processor

$CPUName = $CPU.Name.Trim()
$Cores = $CPU.NumberOfCores
$Threads = $CPU.NumberOfLogicalProcessors

# =========================================
# RAM
# =========================================

$RAM = Get-CimInstance Win32_ComputerSystem
$RAMGB = [math]::Round($RAM.TotalPhysicalMemory / 1GB)

# =========================================
# SYSTEM DRIVE DETECTION
# ONLY CHECK WINDOWS DRIVE
# =========================================

$DiskType = "Unknown"

try {

    $SystemPartition = Get-Partition -DriveLetter C
    $SystemDisk = Get-Disk -Number $SystemPartition.DiskNumber

    $DiskName = $SystemDisk.FriendlyName

    if ($DiskName -match "SSD|NVMe") {
        $DiskType = "SSD"
    }
    else {
        $DiskType = "HDD"
    }
}
catch {

    $DiskType = "Unknown"
}

# =========================================
# TPM
# =========================================

$TPMEnabled = $false

try {

    $TPM = Get-Tpm

    if ($TPM.TpmPresent) {
        $TPMEnabled = $true
    }
}
catch {
    $TPMEnabled = $false
}

# =========================================
# WINDOWS VERSION
# =========================================

$OS = Get-CimInstance Win32_OperatingSystem

# =========================================
# DISPLAY INFO
# =========================================

Write-Host "Computer : $env:COMPUTERNAME"
Write-Host "OS       : $($OS.Caption)"
Write-Host "CPU      : $CPUName"
Write-Host "Cores    : $Cores"
Write-Host "Threads  : $Threads"
Write-Host "RAM      : $RAMGB GB"
Write-Host "Storage  : $DiskType"
Write-Host "TPM      : $TPMEnabled"

# =========================================
# CLASSIFICATION
# =========================================

Write-Host ""
Write-Host "===== RECOMMENDATION =====" -ForegroundColor Cyan
Write-Host ""

$Recommendation = ""
$Level = ""

# =========================================
# LOW-END
# =========================================

if (
    $RAMGB -le 4 -or
    $DiskType -eq "HDD"
) {

    $Level = "LOW"

    $Recommendation = @"
Recommended:
- Windows 10 Pro
- Office Web Apps
- Office LTSC light usage
- Avoid Windows 11
- Avoid heavy security stack
- SSD upgrade strongly recommended
"@

    Warn "Low-end machine detected"
}

# =========================================
# MID-RANGE
# =========================================

elseif (
    $RAMGB -ge 8 -and
    $DiskType -eq "SSD"
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

# =========================================
# HIGH-END
# =========================================

if (
    $RAMGB -ge 16 -and
    $DiskType -eq "SSD" -and
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
# SHOW RESULT
# =========================================

Write-Host ""
Write-Host $Recommendation -ForegroundColor White

# =========================================
# JSON OUTPUT
# =========================================

$Output = [PSCustomObject]@{
    Computer = $env:COMPUTERNAME
    OS = $OS.Caption
    CPU = $CPUName
    Cores = $Cores
    Threads = $Threads
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
