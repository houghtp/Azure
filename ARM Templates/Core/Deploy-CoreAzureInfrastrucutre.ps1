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
    $publicOrPrivate = Read-Host "Is this resouce to be used by Public (Internet) facing resources or Private resources (public/private)?" 
}

# Create the resource group only when it doesn't already exist
$ResourceGroupName = "rg-core-" + $department + "-" + $environment + "-" + $ResourceGroupLocation
if ((Get-AZResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -ErrorAction SilentlyContinue) -eq $null) {
    New-AZResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force -ErrorAction Stop
}

$BaseParameters = @{
    "department" = $department
    "environment" = $environment
    "publicOrPrivate" = $publicOrPrivate
}

# Get all NSG Template folders, loop through and deploy
foreach ($RootTemplateFolder in get-childitem $PSScriptRoot | where-object {$_.name -like "NSG*"}){ 

    $TemplateFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RootTemplateFolder.fullName, $RootTemplateFolder.name))
    Deploy-ArmTemplate $TemplateFolder $BaseParameters

}

# Deploy Resources VNET
$RootTemplateFolder = get-childitem $PSScriptRoot | where-object {$_.name -like "VNET Resources"}
$TemplateFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RootTemplateFolder.fullName, $RootTemplateFolder.name))
Deploy-ArmTemplate $TemplateFolder $BaseParameters

# Deploy Transit VNET with VPN
$RootTemplateFolder = get-childitem $PSScriptRoot | where-object {$_.name -like "VNET Resources"}
$TemplateFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RootTemplateFolder.fullName, $RootTemplateFolder.name))
Deploy-ArmTemplate $TemplateFolder $BaseParameters

# Configure VNET peering