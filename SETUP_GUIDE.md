# Azure DevOps Setup Guide

## Step-by-Step Configuration

### 1. Create Azure Service Principal (if not exists)

```powershell
# Login to Azure
az login

# Set subscription
az account set --subscription b5209445-cdfd-4288-8fa8-72138f3aaf7d

# Create service principal (if needed)
az ad sp create-for-rbac --name "sp-terraform-aicap" --role Contributor --scopes /subscriptions/your-azure-subscription-id

# Output will show:
# {
#   "appId": "your-client-id",
#   "displayName": "sp-terraform-aicap",
#   "password": "your-client-secret",
#   "tenant": "your-tenant-id"
# }
```

### 2. Create State Storage Account

```powershell
# Create resource group
az group create --name rg-terraform-state --location centralindia

# Create storage account (use unique name)
$storageAccountName = "sttfstateaicap$(Get-Random -Minimum 1000 -Maximum 9999)"
az storage account create `
  --name $storageAccountName `
  --resource-group rg-terraform-state `
  --location centralindia `
  --sku Standard_LRS `
  --encryption-services blob

# Create blob container
az storage container create `
  --name tfstate `
  --account-name $storageAccountName

# Grant service principal access
$spObjectId = az ad sp show --id "<your-client-id>" --query id -o tsv
az role assignment create `
  --assignee $spObjectId `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/your-azure-subscription-id/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

Write-Host "Storage Account Name: $storageAccountName" -ForegroundColor Green
```

**Important**: Update `azure-pipelines.yml` with your storage account name!

### 3. Configure Azure DevOps Variable Group

#### Option A: Using Azure DevOps Portal

1. Navigate to: **Pipelines** → **Library** → **+ Variable group**

2. Name: `ACC-23377-AZURE-NPRD-AICAP`

3. Add variables:

| Variable Name | Value | Secret? |
|--------------|-------|---------|
| ARM_CLIENT_ID | your-service-principal-client-id | No |
| ARM_TENANT_ID | your-azure-tenant-id | No |
| ARM_SUBSCRIPTION_ID | your-azure-subscription-id | No |
| ARM_CLIENT_SECRET | your-service-principal-secret | Yes ✓ |
| admin_password | your-secure-vm-password | Yes ✓ |

4. Click **Save**

#### Option B: Using Azure CLI

```powershell
# Install Azure DevOps extension
az extension add --name azure-devops

# Login and set defaults
az devops login
az devops configure --defaults organization=https://dev.azure.com/<your-org> project=<your-project>

# Create variable group
az pipelines variable-group create `
  --name "ACC-23377-AZURE-NPRD-AICAP" `
  --variables `
    ARM_CLIENT_ID=your-service-principal-client-id `
    ARM_TENANT_ID=your-azure-tenant-id `
    ARM_SUBSCRIPTION_ID=your-azure-subscription-id

# Add secrets separately
az pipelines variable-group variable create `
  --group-id <group-id-from-previous-command> `
  --name ARM_CLIENT_SECRET `
  --value "your-service-principal-secret" `
  --secret true

az pipelines variable-group variable create `
  --group-id <group-id-from-previous-command> `
  --name admin_password `
  --value "your-secure-vm-password" `
  --secret true
```

### 4. Create Azure Service Connection

1. Navigate to: **Project Settings** → **Service connections** → **New service connection**

2. Select: **Azure Resource Manager**

3. Authentication method: **Service principal (manual)**

4. Fill in details:
   - **Subscription ID**: your-azure-subscription-id
   - **Subscription Name**: Your subscription name
   - **Service Principal Id**: your-service-principal-client-id
   - **Service Principal Key**: your-service-principal-secret
   - **Tenant ID**: your-azure-tenant-id

5. **Service connection name**: `Azure-Service-Connection`

6. Check "Grant access permission to all pipelines"

7. Click **Verify and save**

### 5. Create Environments (for Approvals)

1. Navigate to: **Pipelines** → **Environments** → **New environment**

2. Create two environments:

   **Environment 1: Azure-Production**
   - Name: `Azure-Production`
   - Description: Production deployment environment
   - Add Approval: Yes (add yourself or team as approver)

   **Environment 2: Azure-Production-Destroy**
   - Name: `Azure-Production-Destroy`
   - Description: Infrastructure destruction environment
   - Add Approval: Yes (require multiple approvers recommended)

### 6. Update Pipeline Configuration

Update `azure-pipelines.yml` with your storage account name:

```yaml
backendAzureRmStorageAccountName: '<your-storage-account-name>'
```

### 7. Create and Run Pipeline

#### Option A: Using Azure DevOps Portal

1. Navigate to: **Pipelines** → **New pipeline**

2. Select: **Azure Repos Git** (or your repository location)

3. Select your repository

4. Select: **Existing Azure Pipelines YAML file**

5. Path: `/azure-pipelines.yml`

6. Click **Continue** → **Run**

#### Option B: Using Azure CLI

```powershell
# Create pipeline
az pipelines create `
  --name "Terraform-Azure-Landing-Zone" `
  --description "Deploy Azure Landing Zone Infrastructure" `
  --repository <your-repo-name> `
  --repository-type tfsgit `
  --branch main `
  --yml-path azure-pipelines.yml

# Run pipeline
az pipelines run --name "Terraform-Azure-Landing-Zone"
```

### 8. Monitor Pipeline Execution

1. Navigate to: **Pipelines** → **Terraform-Azure-Landing-Zone**

2. Watch stages execute:
   - ✓ Validate
   - ✓ Plan
   - ⏸ Apply (waiting for approval)

3. Review plan output before approving

4. Approve deployment to proceed

### 9. Verify Deployment

After successful deployment:

```powershell
# List resource groups
az group list --query "[?contains(name, 'rg-')].name" -o table

# Check VNets
az network vnet list --query "[].{Name:name, AddressSpace:addressSpace.addressPrefixes[0], ResourceGroup:resourceGroup}" -o table

# Check VMs
az vm list --query "[].{Name:name, Size:hardwareProfile.vmSize, State:provisioningState, PrivateIP:privateIps}" -o table

# Check peerings
az network vnet peering list --resource-group rg-connectivity-nprd-cin --vnet-name vnet-hub-nprd-cin -o table
```

### 10. Access VMs via Bastion

1. Navigate to Azure Portal → Virtual Machines

2. Select a VM (e.g., vm-listserv)

3. Click **Connect** → **Bastion**

4. Enter credentials:
   - Username: `azureuser`
   - Password: `VmAdmin!1234`

5. Test connectivity between VMs:
   ```bash
   # Ping test
   ping <other-vm-private-ip>
   
   # SSH test
   ssh azureuser@<other-vm-private-ip>
   ```

## Troubleshooting

### Issue: Pipeline fails at Terraform Init

**Solution**: Verify storage account exists and service principal has access:
```powershell
az storage account show --name <your-storage-account> --resource-group rg-terraform-state
az role assignment list --scope /subscriptions/your-azure-subscription-id/resourceGroups/rg-terraform-state
```

### Issue: Variable group not found

**Solution**: Verify variable group name and pipeline access:
```powershell
az pipelines variable-group list --query "[?name=='ACC-23377-AZURE-NPRD-AICAP']"
```

### Issue: Service connection fails

**Solution**: Verify service principal credentials:
```powershell
az login --service-principal `
  -u your-service-principal-client-id `
  -p "your-service-principal-secret" `
  --tenant your-azure-tenant-id
```

### Issue: Terraform plan fails

**Solution**: Check Terraform syntax locally:
```powershell
cd terraform-azure-landing-zone
terraform init
terraform validate
terraform plan
```

## Next Steps

1. **Configure VM extensions**: Install monitoring agents, security updates
2. **Setup backup policies**: Configure VM backups with Recovery Services Vault
3. **Configure alerts**: Set up Azure Monitor alerts for critical resources
4. **Review security**: Run Defender for Cloud recommendations
5. **Document IPs**: Save VM private IPs for application configuration

## Security Best Practices

1. ✓ Rotate secrets regularly (service principal, admin password)
2. ✓ Use Azure Key Vault references in pipeline (future enhancement)
3. ✓ Enable audit logging for pipeline runs
4. ✓ Restrict service connection access to specific pipelines
5. ✓ Use separate service principals for different environments
6. ✓ Enable multi-stage approval for production deployments

## Pipeline Maintenance

### Update Terraform Version

Edit `azure-pipelines.yml`:
```yaml
variables:
  - name: terraformVersion
    value: '1.7.0'  # Update as needed
```

### Add New Environment

1. Create new variable group for the environment
2. Add new stage in pipeline
3. Configure separate state file
4. Create environment in Azure DevOps for approvals

### Enable Destroy Stage

Edit `azure-pipelines.yml`:
```yaml
- stage: Destroy
  condition: true  # Change from false to true (use with caution!)
```

---

**Remember**: Always test infrastructure changes in a development environment first!
