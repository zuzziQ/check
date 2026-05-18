# =========================================
# ENTERPRISE HARDWARE AUDIT
# Windows + Microsoft 365 Recommendation
# =========================================

Clear-Host

# =========================================
# FUNCTIONS
# =========================================

function Good($msg) {
    Write-Host "[ OK ] $msg" -ForegroundColor Green
}

function Warn($msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
}

function Bad($msg) {
    Write-Host "[BAD ] $msg" -ForegroundColor Red
}

function Info($msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "===== ENTERPRISE HARDWARE AUDIT =====" -ForegroundColor Cyan
Write-Host ""

# =========================================
# OS INFO
# =========================================

$OS = Get-CimInstance Win32_OperatingSystem

# =========================================
# CPU INFO
# =========================================

$CPU = Get-CimInstance Win32_Processor

$CPUName = $CPU.Name.Trim()
$Cores = $CPU.NumberOfCores
$Threads = $CPU.NumberOfLogicalProcessors
$CPUSpeed = $CPU.MaxClockSpeed

# =========================================
# RAM INFO
# =========================================

$RAM = Get-CimInstance Win32_ComputerSystem
$RAMGB = [math]::Round($RAM.TotalPhysicalMemory / 1GB)

# =========================================
# STORAGE DETECTION
# Detect Windows Drive Only
# =========================================

$DiskType = "Unknown"
$DiskName = "Unknown"

try {

    $SystemPartition = Get-Partition -DriveLetter C
    $SystemDisk = Get-Disk -Number $SystemPartition.DiskNumber

    $DiskName = $SystemDisk.FriendlyName

    # Try enterprise method first
    $PhysicalDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue

    if ($PhysicalDisks) {

        foreach ($pd in $PhysicalDisks) {

            if (
                $pd.FriendlyName -eq $DiskName -or
                $pd.DeviceId -eq $SystemDisk.Number
            ) {

                if ($pd.MediaType -eq "SSD") {
                    $DiskType = "SSD"
                }

                elseif ($pd.MediaType -eq "HDD") {
                    $DiskType = "HDD"
                }
            }
        }
    }

    # Fallback Detection
    if ($DiskType -eq "Unknown") {

        if (
            $DiskName -match
            "SSD|NVMe|KINGSTON|SAMSUNG|WD_BLACK|SN[0-9]|MZVL|PM9A|970|980|990"
        ) {

            $DiskType = "SSD"
        }
        else {

            $DiskType = "HDD"
        }
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
# WINDOWS LICENSE
# =========================================

$License = Get-CimInstance SoftwareLicensingProduct |
Where-Object {
    $_.PartialProductKey -and
    $_.Name -match "Windows"
} |
Select-Object -First 1

$LicenseChannel = "Unknown"

if ($License.Description -match "RETAIL") {
    $LicenseChannel = "Retail"
}

elseif ($License.Description -match "OEM") {
    $LicenseChannel = "OEM"
}

elseif ($License.Description -match "KMS") {
    $LicenseChannel = "KMS"
}

elseif ($License.Description -match "MAK") {
    $LicenseChannel = "MAK"
}

# =========================================
# DISPLAY INFO
# =========================================

Write-Host "Computer     : $env:COMPUTERNAME"
Write-Host "OS           : $($OS.Caption)"
Write-Host "CPU          : $CPUName"
Write-Host "Cores        : $Cores"
Write-Host "Threads      : $Threads"
Write-Host "RAM          : $RAMGB GB"
Write-Host "Disk         : $DiskType"
Write-Host "Disk Model   : $DiskName"
Write-Host "TPM          : $TPMEnabled"
Write-Host "License      : $LicenseChannel"

# =========================================
# SCORING
# =========================================

$Score = 0

# RAM
if ($RAMGB -ge 16) {
    $Score += 3
}
elseif ($RAMGB -ge 8) {
    $Score += 2
}
else {
    $Score += 1
}

# STORAGE
if ($DiskType -eq "SSD") {
    $Score += 3
}
else {
    $Score += 1
}

# CPU
if ($Threads -ge 12) {
    $Score += 3
}
elseif ($Threads -ge 8) {
    $Score += 2
}
else {
    $Score += 1
}

# TPM
if ($TPMEnabled) {
    $Score += 2
}

# =========================================
# CLASSIFICATION
# =========================================

Write-Host ""
Write-Host "===== RECOMMENDATION =====" -ForegroundColor Cyan
Write-Host ""

$Level = ""
$Recommendation = ""

# -----------------------------------------
# LOW-END
# -----------------------------------------

if ($Score -le 5) {

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

# -----------------------------------------
# MID-RANGE
# -----------------------------------------

elseif ($Score -le 8) {

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
# HIGH-END
# -----------------------------------------

else {

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
Write-Host "Performance Score : $Score / 11"
Write-Host "Machine Tier      : $Level"

Write-Host ""
Write-Host $Recommendation -ForegroundColor White

# =========================================
# JSON EXPORT
# =========================================

$Output = [PSCustomObject]@{

    Computer = $env:COMPUTERNAME
    OS = $OS.Caption

    CPU = $CPUName
    Cores = $Cores
    Threads = $Threads
    ClockMHz = $CPUSpeed

    RAMGB = $RAMGB

    DiskType = $DiskType
    DiskModel = $DiskName

    TPM = $TPMEnabled

    License = $LicenseChannel

    Score = $Score
    Tier = $Level

    Recommendation = $Recommendation
}

Write-Host ""
Write-Host "===== JSON =====" -ForegroundColor Cyan
Write-Host ""

$Output | ConvertTo-Json -Depth 4
