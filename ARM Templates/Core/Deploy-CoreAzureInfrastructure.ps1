#Requires -Version 3.0

function Deploy-ArmTemplate ($TemplatePath,$OptionalParameters) {

    $TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($TemplatePath, $TemplateFile))
    $TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($TemplatePath, $TemplateParametersFile))

    New-AZResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $TemplateParametersFile `
        @OptionalParameters `
        -Force -Verbose `
        -ErrorVariable ErrorMessages
    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}

# Variables 
[string]$script:TemplateFile = 'azuredeploy.json'
[string]$script:TemplateParametersFile = 'azuredeploy.parameters.json'

$ResourceGroupLocation = Read-Host "Please enter the Resource Group location (uksouth/ukwest)"
while("uksouth","ukwest" -notcontains $ResourceGroupLocation)
{
    $ResourceGroupLocation = Read-Host "Please enter the Resource Group location (uksouth/ukwest)"
}

$environment = Read-Host "What environment is this being deployed to (prod/dev)"
while("prod","dev" -notcontains $environment )
{
    $environment = Read-Host "Please enter the environment this is being deployed to (prod/dev)?"
}
$department = Read-Host "Please enter the department who will own this resource?"
$publicOrPrivate = Read-Host "Is this resouce to be used by Public (Internet) facing resources or Private resources (public/private)?" 
while("public","private" -notcontains $publicOrPrivate  )
{
    $publicOrPrivate = Read-Host "Is this resource to be used by Public (Internet) facing resources or Private resources (public/private)?" 
}

# Create the resource group only when it doesn't already exist
$ResourceGroupName = "rg-core-" + $department + "-" + $environment + "-" + $ResourceGroupLocation
if ((Get-AZResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -ErrorAction SilentlyContinue) -eq $null) {
    New-AZResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force -ErrorAction Stop
}

$Parameters = @{
    "department" = $department
    "environment" = $environment
    "publicOrPrivate" = $publicOrPrivate
}

# # Get all NSG Template folders, loop through and deploy
# foreach ($RootTemplateFolder in get-childitem $PSScriptRoot | where-object {$_.name -like "NSG*"}){ 

#     $TemplateFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RootTemplateFolder.fullName, $RootTemplateFolder.name))
#     Deploy-ArmTemplate $TemplateFolder $Parameters
# }

# Deploy Resources VNET
$vnetCIDRBlock = Read-Host "Please enter the CIDR block for the VNET"
$octets = $vnetCIDRBlock.split(".")

#Import param file so we can update JSON
$paramFile = Get-Content "C:\Users\extph009\source\repos\houghtp\Azure\ARM Templates\Core\VNET Resources\VNET Resources\azuredeploy.parameters.json" | ConvertFrom-Json

# Update VNET CIDR block
$vnet = @{
    addressPrefixes = $vnetCIDRBlock
}

# Create Subnet object to update params file
$subnets = @()
$i = 0
foreach($subnet in $paramFile.parameters.subnetSettings.value){    
    $subnetPrefix = $octets[0] + "." + $octets[1] + ".$i.0/24"
    $op = [ordered]@{
        "name" = $subnet.name
        "addressPrefix" = $subnetPrefix
    }
    $i++
    $obj = new-object PSObject -Property $op
    $subnets += $obj    
}

# Update params object with new value and export
$paramFile.parameters.vnetSettings.value = $vnet
$paramFile.parameters.subnetSettings.value = $subnets
$paramFile | ConvertTo-Json -Depth 4 | Set-Content "C:\Users\extph009\source\repos\houghtp\Azure\ARM Templates\Core\VNET Resources\VNET Resources\azuredeploy.parameters.json"

# Deploy VNET resources template
$RootTemplateFolder = get-childitem $PSScriptRoot | where-object {$_.name -like "VNET Resources"}
$TemplateFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RootTemplateFolder.fullName, $RootTemplateFolder.name))
Deploy-ArmTemplate $TemplateFolder $parameters

# Remove Public or Private parameter option from hashtable as we don't use that for Transit VNET / or VNET peering
$Parameters.Remove("publicOrPrivate")

# # Deploy Transit VNET with VPN
$gatewaySku = Read-Host "Please select VPN SKU (Basic/Standard/HighPerformance)"
while("Basic","Standard","HighPerformance" -cnotcontains $gatewaySku )
{
    $gatewaySku = Read-Host "Please select VPN SKU (Basic/Standard/HighPerformance)"
}
$vpnType = Read-Host "Please select VPN routing type (PolicyBased/RouteBased)"
while("PolicyBased","RouteBased" -cnotcontains $vpnType)
{
    $vpnType = Read-Host "Please select VPN routing type (policyBased/routeBased)"
}
$sharedKey = Read-Host "Please enter a Shared Key for the VPN connection" -AsSecureString
$vpnParameters = @{
    "gatewaySku" = $gatewaySKU
    "vpnType" = $vpnType
    "sharedKey" = $sharedKey
}
$Parameters = $Parameters + $vpnParameters
$RootTemplateFolder = get-childitem $PSScriptRoot | where-object {$_.name -like "VNET Transit Gateway"}
$TemplateFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RootTemplateFolder.fullName, $RootTemplateFolder.name))
Deploy-ArmTemplate $TemplateFolder $Parameters




# Configure VNET peering
$existingTransitVirtualNetworkName = "vnet-transit-" + $department + "-" + $environment + "-" + $ResourceGroupLocation
$existingRemoteVirtualNetworkName = "vnet-resources-" + $department + "-" + $publicOrPrivate + "-" + $environment + "-" + $ResourceGroupLocation

# Remove gatewaySKU,vpnType,sharedKey parameters as we don't use that for VNET peering
$Parameters.Remove("publicOrPrivate")
$Parameters.Remove("sharedKey")
$Parameters.Remove("gatewaySku")
$Parameters.Remove("vpnType")
$Parameters.Remove("sharedKey")

$vnetPeeringParameters = @{
    "existingTransitVirtualNetworkName" = $existingTransitVirtualNetworkName
    "existingRemoteVirtualNetworkName" = $existingRemoteVirtualNetworkName
}
$Parameters = $Parameters + $vnetPeeringParameters
$RootTemplateFolder = get-childitem $PSScriptRoot | where-object {$_.name -like "VNET Peering"}
$TemplateFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RootTemplateFolder.fullName, $RootTemplateFolder.name))
Deploy-ArmTemplate $TemplateFolder $Parameters