<#
    .SYNOPSIS
        some comments
#>

Param (
    [string] $packagedownloaduri,
    [string] $vmhostname,
    [string] $companyauthcode
)

# Folders
New-Item -ItemType Directory c:\tmp -Force

# Download backupgateway package 
(New-Object System.Net.WebClient).DownloadFile($packagedownloaduri, "C:\tmp\backupgateway-package.exe")
$packageFile = 'C:\tmp\backupgateway-package.exe'
$packageFolder = 'C:\tmp\backupgateway-package-folder'
$installerPath = 'C:\7z-x64.exe'

# Force use of TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# Download 7-zip package
(New-Object System.Net.WebClient).DownloadFile('https://7-zip.org/a/7z1900-x64.exe', $installerPath)
Start-Process -FilePath $installerPath -Args "/S" -Verb RunAs -Wait
Remove-Item $installerPath
Start-Process -FilePath 'C:\Program Files\7-Zip\7z.exe' -ArgumentList "x $packageFile -o$packageFolder -y" -Verb RunAs -Wait


$localHostname = $vmhostname
$instanceid = 1 # hardcodeed for now
$clientname = "BackupGateway-$instanceid"
$inputfile = "C:\tmp\backupgateway-package-folder\install.xml"
$xml = New-Object XML
$xml.load($inputfile)
$client = $xml.SelectSingleNode("//clientComposition/clientInfo/client")
$clientEntity = $xml.SelectSingleNode("//clientComposition/clientInfo/client/clientEntity")
$jobResulsDir = $xml.SelectSingleNode("//clientComposition/clientInfo/client/jobResulsDir")
$indexCache = $xml.SelectSingleNode("//clientComposition/components/mediaAgent/indexCacheDirectory")
$clientEntity.hostName = $localHostname
$clientEntity.clientName = $clientname
$client.installDirectory = "C:\ContentStore"
$jobResulsDir.path = "C:\JobResults"
$indexCache.path = "C:\IndexCache"
$xml.Save($inputfile)


#backupgateway-install.
C:\tmp\backupgateway-package-folder\Setup.exe /silent /authcode ${companyauthcode}

Wait-Process -InputObject (Get-Process setup)

# files-cleanup
Remove-Item -Recurse -Force 'C:\tmp\backupgateway-package-folder' -ErrorAction SilentlyContinue
