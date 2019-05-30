# Variables for common values
$vmResourceGroup = "rg-home-file-cdc-dev-uksouth"
$networkResourceGroup = "rg-home-cdc-dev-uksouth"
$location = "uksouth"
$vmName = "file-02"

# Create user object
$userName = "paul"
$password = "B!rmingham01" | ConvertTo-SecureString -AsPlainText -Force 
$cred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password 
$offerName = "WindowsServer"
$skuName = "2016-Datacenter"
$publisherName = "MicrosoftWindowsServer"
$saBootDiag = "rghomecdcdevuksouthdiag"
$saBootDiagRG = "rg-home-cdc-dev-uksouth"

$vmSize = "Standard_A2"
$department = "CDC"
$environment = "Dev"
$project = "exam"
$tags = @{
    "Department" = $department
    "Environment" = $environment
    "Project" = $project
}

# Create the resource group only when it doesn't already exist
if (-not (Get-AZResourceGroup -Name $vmResourceGroup -Location $location -Verbose -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $vmResourceGroup -Location $location -Verbose -Force -ErrorAction Stop
}

$vnet = Get-AzVirtualNetwork -Name "vnet-home-cdc-dev-uksouth" -ResourceGroupName $networkResourceGroup
$subnet = Get-AzVirtualNetworkSubnetConfig -name sub-web-home-cdc-dev-uksouth -VirtualNetwork $vnet

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzNetworkInterface -Name ("$vmName-nic1") -ResourceGroupName $vmResourceGroup -Location $location `
                                   -SubnetId $subnet.Id -PublicIpAddressId "" -NetworkSecurityGroupId ""

# Create a virtual machine configuration
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize |
            Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred |
            Set-AzVMBootDiagnostics -ResourceGroupName (Get-AZResourceGroup $saBootDiagRG).ResourceGroupName -Enable -StorageAccountName $saBootDiag | 
            Set-AzVMSourceImage -PublisherName $publisherName -Offer $offerName -Skus $skuName -Version latest |
            Add-AzVMNetworkInterface -Id $nic.Id

# Create a virtual machine
New-AzVM -ResourceGroupName $vmResourceGroup -Location $location -VM $vmConfig