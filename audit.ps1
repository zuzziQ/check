# =========================================
# ENTERPRISE DEVICE + LICENSE AUDIT
# Hardware + Microsoft 365 Recommendation
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
Write-Host "===== ENTERPRISE DEVICE AUDIT =====" -ForegroundColor Cyan
Write-Host ""

# =========================================
# OS
# =========================================

$OS = Get-CimInstance Win32_OperatingSystem

# =========================================
# CPU
# =========================================

$CPU = Get-CimInstance Win32_Processor

$CPUName = $CPU.Name.Trim()
$Cores = $CPU.NumberOfCores
$Threads = $CPU.NumberOfLogicalProcessors
$Clock = $CPU.MaxClockSpeed

# =========================================
# RAM
# =========================================

$RAM = Get-CimInstance Win32_ComputerSystem
$RAMGB = [math]::Round($RAM.TotalPhysicalMemory / 1GB)

# =========================================
# RAM TYPE
# =========================================

$RamModules = Get-CimInstance Win32_PhysicalMemory

$RamTypes = @()

foreach ($r in $RamModules) {

    $Type = switch ($r.SMBIOSMemoryType) {

        20 { "DDR" }
        21 { "DDR2" }
        24 { "DDR3" }
        26 { "DDR4" }
        34 { "DDR5" }

        default { "Unknown" }
    }

    $RamTypes += $Type
}

$RamGeneration = ($RamTypes | Select-Object -Unique) -join ", "

# =========================================
# STORAGE
# Detect Windows Drive Only
# =========================================

$DiskType = "Unknown"
$DiskName = "Unknown"

try {

    $SystemPartition = Get-Partition -DriveLetter C
    $SystemDisk = Get-Disk -Number $SystemPartition.DiskNumber

    $DiskName = $SystemDisk.FriendlyName

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

    # fallback
    if ($DiskType -eq "Unknown") {

        if (
            $DiskName -match
            "SSD|NVMe|KINGSTON|SAMSUNG|WD_BLACK|SN[0-9]|970|980|990|SU800"
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
# LICENSE
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
# DISPLAY
# =========================================

Write-Host "Computer     : $env:COMPUTERNAME"
Write-Host "OS           : $($OS.Caption)"
Write-Host "CPU          : $CPUName"
Write-Host "Cores        : $Cores"
Write-Host "Threads      : $Threads"
Write-Host "Clock MHz    : $Clock"
Write-Host "RAM          : $RAMGB GB"
Write-Host "RAM Type     : $RamGeneration"
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

# RAM TYPE
if ($RamGeneration -match "DDR5") {
    $Score += 3
}
elseif ($RamGeneration -match "DDR4") {
    $Score += 2
}
elseif ($RamGeneration -match "DDR3") {
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

$Tier = ""
$WindowsPlan = ""
$M365Plan = ""
$Notes = ""

# LOW
if ($Score -le 6) {

    $Tier = "LOW-END"

    $WindowsPlan = "Windows 10 Pro"
    $M365Plan = "Office Web / Office LTSC"

    $Notes = @"
- Suitable for:
  Telesale
  Reception
  Basic Office

- Avoid:
  Windows 11
  Heavy Defender stack
  Intune full compliance

- Strongly recommend SSD upgrade
"@

    Warn "Low-end machine detected"
}

# MID
elseif ($Score -le 10) {

    $Tier = "MID-RANGE"

    $WindowsPlan = "Windows 10/11 Pro"
    $M365Plan = "Microsoft 365 Business Standard"

    $Notes = @"
- Suitable for:
  Marketing
  Content
  CSKH
  Office Staff

- Teams Desktop acceptable
- Optional Intune
"@

    Good "Mid-range machine detected"
}

# HIGH
else {

    $Tier = "HIGH-END"

    $WindowsPlan = "Windows 11 Pro / Enterprise"
    $M365Plan = "Microsoft 365 Business Premium"

    $Notes = @"
- Suitable for:
  IT
  Manager
  Accounting
  Sensitive data users

- Recommended:
  Intune
  BitLocker
  Defender for Business
  MFA
  Compliance Policy
"@

    Good "High-end machine detected"
}

# =========================================
# OUTPUT
# =========================================

Write-Host ""
Write-Host "Performance Score : $Score"
Write-Host "Machine Tier      : $Tier"

Write-Host ""
Write-Host "Windows Plan      : $WindowsPlan"
Write-Host "M365 Plan         : $M365Plan"

Write-Host ""
Write-Host $Notes -ForegroundColor White

# =========================================
# JSON EXPORT
# =========================================

$Output = [PSCustomObject]@{

    Computer = $env:COMPUTERNAME

    OS = $OS.Caption

    CPU = $CPUName
    Cores = $Cores
    Threads = $Threads
    ClockMHz = $Clock

    RAMGB = $RAMGB
    RAMType = $RamGeneration

    DiskType = $DiskType
    DiskModel = $DiskName

    TPM = $TPMEnabled

    License = $LicenseChannel

    Score = $Score
    Tier = $Tier

    WindowsPlan = $WindowsPlan
    M365Plan = $M365Plan

    Notes = $Notes
}

Write-Host ""
Write-Host "===== JSON =====" -ForegroundColor Cyan
Write-Host ""

$Output | ConvertTo-Json -Depth 5
