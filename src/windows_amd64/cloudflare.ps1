# Cloudflare API Credentials
$authEmail = ""
$authMethod = ""  # Set to "global" for Global API Key or "token" for Scoped API Token
$authKey = ""
$zoneId = ""

# 文件路径
$filePath = "C:\software\IP\CFIP\result_hosts.txt"

# 读取文件内容
$fileContent = Get-Content -Path $filePath

# 定义正则表达式匹配 IPv4 地址的模式
$ipv4Pattern = '\b(?:\d{1,3}\.){3}\d{1,3}\b'

# 从文件内容中提取 IP 地址
$ipAddresses = $fileContent | ForEach-Object { [regex]::Matches($_, $ipv4Pattern) } | ForEach-Object { $_.Value }

# Check and set the proper auth header
if ($authMethod -eq "global") {
    $authHeader = "X-Auth-Key"
} else {
    $authHeader = "Authorization"
}

# Loop through each extracted IP address and update Cloudflare A record
foreach ($ipAddress in $ipAddresses) {
    $recordName = "ccad.deardg.com"  # 替换为你的域名
    $ttl = "300"
    $proxy = $false

    # Seek for the A record
    $apiEndpoint = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?type=A&name=$recordName"
    $record = Invoke-RestMethod -Uri $apiEndpoint -Method Get -Headers @{
        "X-Auth-Email" = $authEmail
        "X-Auth-Key" = $authKey
        "Content-Type" = "application/json"
    }

    # Check if the domain has an A record
    if ($record.result.count -eq 0) {
        Write-Host "DDNS Updater: Record does not exist, perhaps create one first? ($ipAddress for $recordName)"
        exit 1
    }

    # Get existing IP
    $oldIp = $record.result[0].content

    # Compare if they're the same
    if ($ipAddress -eq $oldIp) {
        Write-Host "DDNS Updater: IP ($ipAddress) for $recordName has not changed."
        continue
    }

    # Set the record identifier from result
    $recordIdentifier = $record.result[0].id

    # Change the IP@Cloudflare using the API
    $updateData = @{
        type = "A"
        name = $recordName
        content = $ipAddress
        ttl = $ttl
        proxied = $proxy
    }

    $updateEndpoint = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordIdentifier"
    $updateRecord = Invoke-RestMethod -Uri $updateEndpoint -Method Patch -Headers @{
        "X-Auth-Email" = $authEmail
        "X-Auth-Key" = $authKey
        "Content-Type" = "application/json"
    } -Body ($updateData | ConvertTo-Json)

    # Report the status
    if ($updateRecord.success -eq $false) {
        Write-Host "DDNS Updater: $ipAddress $recordName DDNS failed for $recordIdentifier ($ipAddress). DUMPING RESULTS:`n$updateRecord"
        exit 1
    } else {
        Write-Host "DDNS Updater: $ipAddress $recordName DDNS updated."
    }
}
