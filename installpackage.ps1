<#
    .SYNOPSIS
        some comments
#>

Param (
    [string] $packagedownloaduri,
    [string] $vmhostname,
    [string] $companyauthcode,
    [string] $vmname
)

# Folders
New-Item -ItemType Directory c:\MetallicBackupGatewayPackage -Force

# initialize-disk
$PhysicalDisks = Get-PhysicalDisk -CanPool $True;
New-StoragePool -FriendlyName 'Metallic' -StorageSubsystemFriendlyName 'Windows Storage*' -PhysicalDisks $PhysicalDisks
$VirutalDisk = New-VirtualDisk -FriendlyName 'Metallic' -StoragePoolFriendlyName 'Metallic' -ResiliencySettingName Simple -AutoNumberOfColumns -UseMaximumSize -ProvisioningType Fixed #-Interleave 32768
$Disk = Initialize-Disk -VirtualDisk $VirutalDisk -PartitionStyle GPT -PassThru
New-Volume -Disk $Disk -FileSystem NTFS -DriveLetter E -FriendlyName 'Metallic' #-AllocationUnitSize 32768
Start-Sleep -Seconds 5

# Download backupgateway package 
(New-Object System.Net.WebClient).DownloadFile($packagedownloaduri, "C:\MetallicBackupGatewayPackage\backupgateway-package.exe")
$packageFile = 'C:\MetallicBackupGatewayPackage\backupgateway-package.exe'
$packageFolder = 'C:\MetallicBackupGatewayPackage\backupgateway-package-folder'
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
$clientname = "$vmname-$instanceid"
$inputfile = "C:\MetallicBackupGatewayPackage\backupgateway-package-folder\install.xml"
$xml = New-Object XML
$xml.load($inputfile)
$client = $xml.SelectSingleNode("//clientComposition/clientInfo/client")
$clientEntity = $xml.SelectSingleNode("//clientComposition/clientInfo/client/clientEntity")
$jobResulsDir = $xml.SelectSingleNode("//clientComposition/clientInfo/client/jobResulsDir")
$indexCache = $xml.SelectSingleNode("//clientComposition/components/mediaAgent/indexCacheDirectory")
$clientEntity.hostName = $localHostname
$clientEntity.clientName = $clientname
$client.installDirectory = "E:\ContentStore"
$jobResulsDir.path = "E:\JobResults"
$indexCache.path = "E:\IndexCache"
$xml.Save($inputfile)


#backupgateway-install.
C:\MetallicBackupGatewayPackage\backupgateway-package-folder\Setup.exe /silent /authcode ${companyauthcode}

Wait-Process -InputObject (Get-Process setup)

# files-cleanup
Remove-Item -Recurse -Force 'C:\MetallicBackupGatewayPackage\backupgateway-package-folder' -ErrorAction SilentlyContinue
