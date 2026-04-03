<#
.SYNOPSIS
    Nightly cost optimization runbook: stops/deallocates a VM and downgrades its OS disk.

.DESCRIPTION
    This runbook authenticates via Managed Identity, stops and deallocates the target VM,
    then changes the OS disk SKU from Premium_LRS to Standard_LRS to reduce overnight costs.
    Intended to run on a daily schedule at 18:00 UTC.
#>

try {
    Write-Output "Connecting to Azure using Managed Identity..."
    Connect-AzAccount -Identity | Out-Null

    $resourceGroupName = Get-AutomationVariable -Name 'ResourceGroupName'
    $vmName = Get-AutomationVariable -Name 'VmName'

    Write-Output "Target: VM '$vmName' in resource group '$resourceGroupName'"

    # Step 1: Stop and deallocate the VM
    Write-Output "Stopping and deallocating VM '$vmName'..."
    Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

    $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status
    $powerState = ($vm.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus

    if ($powerState -ne 'VM deallocated') {
        throw "VM is not deallocated. Current state: $powerState"
    }
    Write-Output "VM deallocated successfully."

    # Step 2: Change OS disk SKU from Premium to Standard
    $vmConfig = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
    $diskName = $vmConfig.StorageProfile.OsDisk.Name

    Write-Output "Changing disk '$diskName' from Premium_LRS to Standard_LRS..."
    $disk = Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName $diskName

    if ($disk.Sku.Name -eq 'Standard_LRS') {
        Write-Output "Disk is already Standard_LRS. No change needed."
    }
    else {
        $disk.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new('Standard_LRS')
        Update-AzDisk -ResourceGroupName $resourceGroupName -DiskName $diskName -Disk $disk | Out-Null
        Write-Output "Disk SKU changed to Standard_LRS."
    }

    Write-Output "Cost optimization complete. VM is deallocated with Standard HDD."
}
catch {
    Write-Error "Runbook failed: $_"
    throw
}
