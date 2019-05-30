# variables
$resourceGroup = "rg-home-cdc-dev-uksouth"
$location = "uksouth"
$vnet = "vnet-home-cdc-dev-uksouth"
$subnet = "sub-web-home-cdc-dev-uksouth"
$nsg = "nsg-web-home-cdc-dev-uksouth"


$sourceAddressPrefix = @("195.191.66.225","92.232.97.224")
$rule1 = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Remote Management Allow" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix $sourceAddressPrefix -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name $nsg -SecurityRules $rule1

$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup -Name $vnet
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnet
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name $nsg 
$subnet.NetworkSecurityGroup = $nsg
Set-AzVirtualNetwork -VirtualNetwork $vnet