# Demo Guide: Azure RBAC & Azure Policy — Secure, Automated Cost Optimization

> **Audience:** IT Pros, Azure Admins, Security Engineers
> **Duration:** 30–40 minutes
> **Environment:** `rg-rbac-policy-cost-opt-dev` in East US 2

---

## Pre-Demo Checklist

| Check                     | How to Verify                                                                                                  | Status |
| ------------------------- | -------------------------------------------------------------------------------------------------------------- | ------ |
| Resource group exists     | `az group show -n rg-rbac-policy-cost-opt-dev -o table`                                                        | ☐      |
| VM is running             | `az vm show -g rg-rbac-policy-cost-opt-dev -n vm-demo-dev --show-details --query powerState -o tsv`            | ☐      |
| OS disk is Premium_LRS    | `az disk show -g rg-rbac-policy-cost-opt-dev -n <os-disk-name> --query sku.name -o tsv`                        | ☐      |
| Automation Account exists | `az automation account show -g rg-rbac-policy-cost-opt-dev -n aa-rbac-policy-cost-opt-dev -o table`            | ☐      |
| Custom RBAC role exists   | `az role definition list --custom-role-only true --query "[?contains(roleName,'VM Cost Optimizer')]" -o table` | ☐      |
| Policy assignments active | `az policy assignment list -g rg-rbac-policy-cost-opt-dev --query "[].displayName" -o tsv`                     | ☐      |
| Runbook is published      | Portal → Automation Account → Runbooks → `Stop-VM-ChangeDisk` shows Published                                  | ☐      |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  Resource Group: rg-rbac-policy-cost-opt-dev                       │
│                                                                     │
│  ┌──────────────┐   Custom RBAC Role    ┌─────────────────────┐    │
│  │  Automation   │──────────────────────▶│   Virtual Machine   │    │
│  │  Account      │   (Managed Identity)  │   vm-demo-dev       │    │
│  │  + Runbook    │                       │   + Premium SSD     │    │
│  │  + Schedule   │                       │                     │    │
│  └──────────────┘                       └─────────────────────┘    │
│         │                                        │                  │
│         ▼                                        ▼                  │
│  ┌──────────────┐                       ┌─────────────────────┐    │
│  │ Log Analytics │                       │  NSG + VNet + PIP   │    │
│  │ Workspace     │                       │                     │    │
│  └──────────────┘                       └─────────────────────┘    │
│                                                                     │
│  Azure Policy: Tag Enforcement │ MDE Audit │ MDE Auto-Deploy       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Demo Flow

### Part 1: Managed Identity — Zero Credentials (5 min)

**Talking Point:** _"Managed Identities eliminate credential sprawl. The Automation Account authenticates to Azure without any stored secrets, passwords, or service principal keys."_

**Steps:**

1. Open **Azure Portal** → Resource Group `rg-rbac-policy-cost-opt-dev`
2. Navigate to **Automation Account** `aa-rbac-policy-cost-opt-dev`
3. Go to **Identity** blade → show **System assigned** tab is **On**
   - Highlight: the Object ID is the identity Azure AD manages automatically
   - No certificates, no secrets, no rotation needed
4. Go to **Account Settings** → show there are no Run As Accounts or credentials stored

**Key Message:** The Automation Account uses `Connect-AzAccount -Identity` in its runbook — Azure handles all token issuance and rotation behind the scenes.

**CLI verification:**

```powershell
az automation account show -g rg-rbac-policy-cost-opt-dev -n aa-rbac-policy-cost-opt-dev --query identity -o json
```

---

### Part 2: Custom RBAC Role — Least Privilege (10 min)

**Talking Point:** _"Built-in Contributor can create/delete any resource. Our custom role allows only 5 specific actions — nothing else."_

**Steps:**

1. In **Azure Portal** → Resource Group → **Access control (IAM)**
2. Click **Roles** tab → search for `VM Cost Optimizer`
3. Click into the role → show the **Permissions** tab:

| Action                                                | Purpose                   |
| ----------------------------------------------------- | ------------------------- |
| `Microsoft.Compute/virtualMachines/read`              | Read VM state             |
| `Microsoft.Compute/virtualMachines/powerOff/action`   | Stop the VM               |
| `Microsoft.Compute/virtualMachines/deallocate/action` | Deallocate (stop billing) |
| `Microsoft.Compute/disks/read`                        | Read disk configuration   |
| `Microsoft.Compute/disks/write`                       | Change disk SKU           |

4. Go back to **Role assignments** tab → show the Automation Account MI has this role
5. **Compare** with built-in Contributor: point out Contributor has 1000+ actions

**Key Message:** If the Automation Account's identity were compromised, the attacker could only stop a VM and change a disk — not create resources, access data, or escalate privileges.

**CLI verification:**

```powershell
# Show the custom role permissions
az role definition list --custom-role-only true --query "[?contains(roleName,'VM Cost Optimizer')].permissions[0].actions" -o json

# Show the role assignment
az role assignment list -g rg-rbac-policy-cost-opt-dev --query "[?contains(roleDefinitionName,'VM Cost Optimizer')].{Role:roleDefinitionName, Principal:principalType}" -o table
```

---

### Part 3: Azure Automation Runbook — Cost Optimization (10 min)

**Talking Point:** _"Automation + least-privilege RBAC = safe cost optimization. Every night at 18:00, this runbook deallocates the VM and downgrades the disk from Premium SSD to Standard HDD."_

**Steps:**

1. Navigate to **Automation Account** → **Runbooks** → `Stop-VM-ChangeDisk`
2. Click **View** to show the PowerShell code:
   - `Connect-AzAccount -Identity` — authenticates with Managed Identity
   - `Stop-AzVM` — deallocates the VM (stops compute billing)
   - `Update-AzDisk` — changes Premium_LRS to Standard_LRS (reduces storage cost)
3. Go to **Schedules** → show `daily-1800-utc` schedule is linked
4. **Run the runbook manually** to demonstrate live:
   - Click **Start** on the runbook
   - Watch the **Job output** stream in real time
   - After completion, verify:

```powershell
# Check VM is deallocated
az vm show -g rg-rbac-policy-cost-opt-dev -n vm-demo-dev --show-details --query powerState -o tsv
# Expected: VM deallocated

# Check disk is now Standard
az disk list -g rg-rbac-policy-cost-opt-dev --query "[?contains(name,'OsDisk')].{Name:name, SKU:sku.name}" -o table
# Expected: Standard_LRS
```

**Cost Impact Callout:**

| State               | VM Compute          | OS Disk          | Estimated Monthly |
| ------------------- | ------------------- | ---------------- | ----------------- |
| Running (daytime)   | Standard_B2s billed | Premium_LRS P10  | ~$38 + $19 = $57  |
| Deallocated (night) | $0                  | Standard_LRS S10 | $0 + $5 = $5      |

_"For a single VM this saves ~$50/month. At enterprise scale with hundreds of VMs, this pattern saves thousands."_

---

### Part 4: Azure Policy — Governance at Scale (10 min)

#### 4a: Tag Enforcement (Deny Policy)

**Talking Point:** _"Azure Policy prevents ungoverned resources from ever being created. No tags? No deployment."_

**Steps:**

1. Navigate to **Azure Policy** → **Assignments** → filter by resource group
2. Show `Require CostCenter and Owner tags` assignment
3. **Demonstrate the deny** — try to create a resource without tags:

```powershell
# This will FAIL because of the tag policy
az storage account create -g rg-rbac-policy-cost-opt-dev -n teststnottags$(Get-Random -Max 9999) -l eastus2 --sku Standard_LRS 2>&1
# Expected: RequestDisallowedByPolicy error
```

4. Show that all existing resources in the RG have `CostCenter` and `Owner` tags

**Key Message:** Policy is proactive — it prevents drift before it happens, unlike audit-after-the-fact approaches.

#### 4b: MDE Audit Policy

**Talking Point:** _"Audit policies provide visibility. You can see which VMs are non-compliant without blocking anything."_

**Steps:**

1. Show `Audit MDE on Virtual Machines` assignment
2. Navigate to **Policy compliance** → show compliance state of VMs
3. Explain: audit flags non-compliant resources but doesn't block or change them

#### 4c: MDE Auto-Remediation (DeployIfNotExists)

**Talking Point:** _"DeployIfNotExists is the most powerful policy effect — it automatically fixes non-compliance. If a VM is missing MDE, Azure installs it."_

**Steps:**

1. Show `Deploy MDE on Windows VMs` assignment → note it has a **Managed Identity** (visible in Identity tab)
2. Explain: the policy's MI was auto-assigned `Virtual Machine Contributor` so it can install VM extensions
3. Navigate to **Policy** → **Remediation** → show remediation tasks
4. Show the VM now has the `MDE.Windows` extension:

```powershell
az vm extension list -g rg-rbac-policy-cost-opt-dev --vm-name vm-demo-dev --query "[].{Name:name, Publisher:publisher, Type:typePropertiesType}" -o table
```

**Key Message:** Three policy patterns in one demo — Deny (prevent), Audit (detect), DeployIfNotExists (auto-fix). Together they create a governance framework that scales to thousands of resources.

---

## Wrap-Up: Key Takeaways (3 min)

| Concept              | What We Demonstrated                               | Why It Matters                                    |
| -------------------- | -------------------------------------------------- | ------------------------------------------------- |
| **Managed Identity** | Automation Account authenticates without secrets   | Eliminates credential sprawl, no rotation burden  |
| **Custom RBAC**      | Only 5 actions allowed for the automation identity | Limits blast radius if compromised                |
| **Azure Automation** | Nightly VM deallocate + disk downgrade             | Automated cost savings without human intervention |
| **Policy: Deny**     | Tag enforcement blocks non-compliant resources     | Prevents governance drift proactively             |
| **Policy: Audit**    | MDE compliance visibility                          | Detects security gaps across the estate           |
| **Policy: DINE**     | Auto-install MDE on VMs                            | Self-healing security at scale                    |

---

## Reset for Next Demo

To restore the environment to its demo-ready state (VM running, Premium disk):

```powershell
$rg = "rg-rbac-policy-cost-opt-dev"
$vmName = "vm-demo-dev"

# 1. Start the VM
az vm start -g $rg -n $vmName

# 2. After VM is running, stop and deallocate to change disk back
az vm deallocate -g $rg -n $vmName

# 3. Get the OS disk name
$diskName = az vm show -g $rg -n $vmName --query "storageProfile.osDisk.name" -o tsv

# 4. Upgrade disk back to Premium
az disk update -g $rg -n $diskName --sku Premium_LRS

# 5. Start the VM again
az vm start -g $rg -n $vmName

# 6. Verify
az vm show -g $rg -n $vmName --show-details --query "{Power:powerState}" -o table
az disk show -g $rg -n $diskName --query sku.name -o tsv
```

---

## Contingency Playbook

| Issue                            | Symptom                             | Fix                                                                               |
| -------------------------------- | ----------------------------------- | --------------------------------------------------------------------------------- |
| Runbook fails authentication     | `Connect-AzAccount -Identity` error | Verify MI is enabled: Portal → Automation → Identity → System assigned = On       |
| Runbook can't stop VM            | `AuthorizationFailed`               | Check custom role assignment: IAM → Role assignments → look for VM Cost Optimizer |
| Disk SKU change fails            | `OperationNotAllowed`               | VM must be fully deallocated first — check `powerState` is `VM deallocated`       |
| Tag policy doesn't deny          | Resource created without tags       | Check policy assignment enforcement mode = `Default` (not `DoNotEnforce`)         |
| MDE not auto-installed           | Extension missing after policy      | Trigger manual remediation: Policy → Remediation → Create remediation task        |
| VM won't start after disk change | Allocation error                    | Try a different VM size or region — burstable B-series has high demand            |

---

## Teardown

To delete all resources when the demo is no longer needed:

```powershell
az group delete -n rg-rbac-policy-cost-opt-dev --yes --no-wait
```

> **Note:** Custom role definitions and policy definitions are at subscription scope and must be cleaned up separately if desired:
>
> ```powershell
> az role definition delete --name "VM Cost Optimizer (rg-rbac-policy-cost-opt-dev)"
> az policy definition delete -n require-costcenter-owner-tags
> az policy definition delete -n audit-mde-on-vms
> az policy definition delete -n deploy-mde-on-windows-vms
> ```
