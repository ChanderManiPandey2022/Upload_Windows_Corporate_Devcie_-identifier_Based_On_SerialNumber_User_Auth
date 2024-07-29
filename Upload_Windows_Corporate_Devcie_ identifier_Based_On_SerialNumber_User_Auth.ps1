#Upload Windows Corporate Devcie identifier based on the serial number Using PowerShell>
#DESCRIPTION
 <# Upload Windows Corporate Devcie identifier based on the serial number Using PowerShell>
 #INPUTS
 < User Imput Needed>
#NOTES
  Version:        1.0
  Author:         Chander Mani Pandey
  Creation Date:  26 July 2024
  Find Author on 
  Youtube:-        https://www.youtube.com/@chandermanipandey8763
  Twitter:-        https://twitter.com/Mani_CMPandey
  LinkedIn:-       https://www.linkedin.com/in/chandermanipandey
  
 #>
 # Set the execution policy to bypass restrictions for the current session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#=============================User Input Section================================

# Paths for serial numbers and log file
$SerialNumberFilePath = "C:\Temp\SerialNumber.txt"


#===============================================================================

# Function to check, install, and import a module
function Ensure-Module {
    param (
        [string]$ModuleName
    )

    $module = Get-Module -Name $ModuleName -ListAvailable
    Write-Host "Checking if '$ModuleName' is installed" -ForegroundColor Yellow

    if ($module -eq $null) {
        Write-Host "'$ModuleName' is not installed" -ForegroundColor Red
        Write-Host "Installing '$ModuleName'" -ForegroundColor Yellow
        Install-Module $ModuleName -Force
        Write-Host "'$ModuleName' has been installed successfully" -ForegroundColor Green
        Write-Host "Importing '$ModuleName' module" -ForegroundColor Yellow
        Import-Module $ModuleName -Force
        Write-Host "'$ModuleName' module imported successfully" -ForegroundColor Green
    } else {
        Write-Host "'$ModuleName' is already installed" -ForegroundColor Green
        Write-Host "Importing '$ModuleName' module" -ForegroundColor Yellow
        Import-Module $ModuleName -Force
        Write-Host "'$ModuleName' module imported successfully" -ForegroundColor Green
    }
}

# Ensure Microsoft.Graph.DeviceManagement is installed and imported
Ensure-Module -ModuleName "Microsoft.Graph.DeviceManagement"

# Ensure Microsoft.Graph.Beta.DeviceManagement is installed and imported
Ensure-Module -ModuleName "Microsoft.Graph.Beta.DeviceManagement"

# Connect to Microsoft Graph with Client Secret
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All"
Write-Host "Connected to Microsoft Graph successfully" -ForegroundColor Green


# Extract the directory path from the serial number file path
$SerialNumberDir = Split-Path -Path $SerialNumberFilePath -Parent

# Define the log file path to be in the same directory as the serial number file
$LogFilePath = Join-Path -Path $SerialNumberDir -ChildPath "DeviceUploadLog.csv"


# Initialize CSV log file
@"
SerialNumber,Status,Message
"@ | Out-File -FilePath $LogFilePath -Encoding UTF8

# Read serial numbers from the .txt file
$SerialNumbers = Get-Content -Path $SerialNumberFilePath
Write-Host "Read $(($SerialNumbers | Measure-Object).Count) serial numbers from the file." -ForegroundColor Yellow

# Query Microsoft Graph for all devices
Write-Host "Querying Microsoft Graph for all devices..." -ForegroundColor Yellow
$AllDevices = Get-MgDeviceManagementManagedDevice | Select-Object DeviceName, EmailAddress, Manufacturer, Model, SerialNumber
Write-Host "Retrieved $(($AllDevices | Measure-Object).Count) devices from Microsoft Graph." -ForegroundColor Green

# Initialize counters
$totalSerials = $SerialNumbers.Count
$foundCount = 0
$uploadedCount = 0
$alreadyExistCount = 0
$notFoundCount = 0

# Filter devices based on serial numbers from the .txt file
$AllWindowsDevices = $AllDevices | Where-Object { $SerialNumbers -contains $_.SerialNumber }
$foundCount = $AllWindowsDevices.Count
Write-Host "Filtered to $foundCount devices based on serial numbers." -ForegroundColor Green

# Process each serial number
foreach ($serial in $SerialNumbers) {
    $device = $AllWindowsDevices | Where-Object { $_.SerialNumber -eq $serial }

    if ($device) {
        try {
            Write-Host "Uploading device identity for $($device.DeviceName)..." -ForegroundColor Yellow

            # Create the JSON payload for each device
            $params = @{
                overwriteImportedDeviceIdentities = $false
                importedDeviceIdentities = @(
                    @{
                        importedDeviceIdentityType = "manufacturerModelSerial"
                        importedDeviceIdentifier = "$($device.Manufacturer),$($device.Model),$($device.SerialNumber)"
                    }
                )
            } | ConvertTo-Json

            # Upload the device identity
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities/importDeviceIdentityList" -Body $params

            Write-Host "Device identity for $($device.DeviceName) uploaded successfully." -ForegroundColor Green
            $uploadedCount++

            # Log success
            "$($device.SerialNumber),Success,Uploaded successfully" | Out-File -Append -FilePath $LogFilePath -Encoding UTF8
        }
        catch {
            Write-Host "Failed to upload device identity for $($device.DeviceName)." -ForegroundColor Red

            # Log failure
            "$($device.SerialNumber),Failure,Error occurred: $_" | Out-File -Append -FilePath $LogFilePath -Encoding UTF8
        }
    } else {
        Write-Host "Device with serial number $serial not found." -ForegroundColor Red
        $notFoundCount++

        # Log not found
        "$serial,NotFound,Device not found" | Out-File -Append -FilePath $LogFilePath -Encoding UTF8
    }
}

# Print summary
$alreadyExistCount = $foundCount - $uploadedCount
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "Total serial numbers in Notepad file: $totalSerials" -ForegroundColor Yellow
Write-Host "Total devices uploaded:               $uploadedCount" -ForegroundColor Green
Write-Host "Serial numbers not found:             $notFoundCount" -ForegroundColor Red

# Log summary
@"
Summary,, 
TotalSerialNumbers,$totalSerials
DevicesUploaded,$uploadedCount
SerialNumbersNotFound,$notFoundCount
"@ | Out-File -Append -FilePath $LogFilePath -Encoding UTF8

# Disconnect from Microsoft Graph
Write-Host "Disconnecting from Microsoft Graph..." -ForegroundColor Yellow
Disconnect-MgGraph
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green


