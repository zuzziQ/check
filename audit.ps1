# =========================================
# WINDOWS / OFFICE ACTIVATION AUDIT
# =========================================

Clear-Host

$Risk = 0
$Findings = @()

function Info($msg) {
    Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

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
Write-Host "===== ACTIVATION AUDIT =====" -ForegroundColor White
Write-Host ""

# =========================================
# LICENSE CHECK
# =========================================

Info "Checking installed licenses..."

$items = Get-CimInstance SoftwareLicensingProduct |
Where-Object {
    $_.PartialProductKey
}

$LicenseResults = @()

foreach ($i in $items) {

    Write-Host ""
    Write-Host "----------------------------------" -ForegroundColor DarkGray

    $status = switch ($i.LicenseStatus) {
        0 { "Unlicensed" }
        1 { "Licensed" }
        2 { "OOB Grace" }
        3 { "OOT Grace" }
        4 { "Non-Genuine Grace" }
        5 { "Notification" }
        6 { "Extended Grace" }
        default { "Unknown" }
    }

    Write-Host "Name        : $($i.Name)"
    Write-Host "Description : $($i.Description)"
    Write-Host "Status      : $status"
    Write-Host "Partial Key : $($i.PartialProductKey)"

    $Channel = "Unknown"

    if ($i.Description -match "RETAIL") {
        $Channel = "Retail"
        Good "Retail license"
    }

    elseif ($i.Description -match "OEM_DM|OEM") {
        $Channel = "OEM"
        Good "OEM factory license"
    }

    elseif ($i.Description -match "VOLUME_MAK") {
        $Channel = "MAK"
        Warn "MAK volume license"
        $Risk += 1
        $Findings += "MAK license detected"
    }

    elseif ($i.Description -match "VOLUME_KMSCLIENT") {
        $Channel = "KMS"
        Bad "KMS client activation detected"
        $Risk += 3
        $Findings += "KMS activation detected"
    }

    $LicenseResults += [PSCustomObject]@{
        Name = $i.Name
        Channel = $Channel
        Status = $status
        PartialKey = $i.PartialProductKey
    }
}

# =========================================
# SLMGR CHECK
# =========================================

Write-Host ""
Info "Running slmgr /xpr..."

$xpr = cscript.exe //Nologo C:\Windows\System32\slmgr.vbs /xpr

if ($xpr -match "permanently activated") {
    Good "Windows permanently activated"
}
else {
    Warn "Windows may not be permanently activated"
    $Risk += 1
    $Findings += "Non-permanent activation"
}

# =========================================
# REGISTRY KMS CHECK
# =========================================

Write-Host ""
Info "Checking KMS registry..."

$kmsReg = reg query `
"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" `
/v KeyManagementServiceName 2>$null

if ($kmsReg) {
    Bad "KMS server registry found"
    Write-Host $kmsReg

    $Risk += 3
    $Findings += "KMS registry detected"
}
else {
    Good "No KMS registry"
}

# =========================================
# SCHEDULED TASKS
# =========================================

Write-Host ""
Info "Checking scheduled tasks..."

$tasks = Get-ScheduledTask | Where-Object {
    $_.TaskName -match "KMS|MAS|AutoPico|Activator"
}

if ($tasks) {

    foreach ($t in $tasks) {
        Bad "Suspicious task: $($t.TaskName)"
        $Risk += 2
        $Findings += "Suspicious task: $($t.TaskName)"
    }
}
else {
    Good "No suspicious scheduled tasks"
}

# =========================================
# SERVICES
# =========================================

Write-Host ""
Info "Checking suspicious services..."

$services = Get-Service | Where-Object {
    $_.Name -match "KMS|Pico|Activator"
}

if ($services) {

    foreach ($s in $services) {
        Bad "Suspicious service: $($s.Name)"
        $Risk += 2
        $Findings += "Suspicious service: $($s.Name)"
    }
}
else {
    Good "No suspicious services"
}

# =========================================
# FINAL RESULT
# =========================================

Write-Host ""
Write-Host "===== FINAL RESULT =====" -ForegroundColor White
Write-Host ""

Write-Host "Risk Score: $Risk"

if ($Risk -eq 0) {
    Good "System appears legitimate"
}
elseif ($Risk -le 3) {
    Warn "Possibly legitimate but check manually"
}
else {
    Bad "High probability of KMS/crack activation"
}

# =========================================
# JSON OUTPUT
# =========================================

$Output = [PSCustomObject]@{
    Computer = $env:COMPUTERNAME
    User = $env:USERNAME
    Time = Get-Date
    RiskScore = $Risk
    Findings = $Findings
    Licenses = $LicenseResults
}

Write-Host ""
Write-Host "===== JSON OUTPUT =====" -ForegroundColor White
Write-Host ""

$Output | ConvertTo-Json -Depth 5