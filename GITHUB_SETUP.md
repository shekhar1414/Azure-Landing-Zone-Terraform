# GitHub Push Instructions

## Recommended GitHub Repository Name
**azure-landing-zone-terraform**

Alternative names:
- terraform-azure-hub-spoke
- azure-enterprise-landing-zone
- terraform-azure-infrastructure
- azure-cloud-landing-zone

## Step-by-Step GitHub Setup

### 1. Initialize Git Repository (if not already done)
```powershell
cd c:\terraform-azure-landing-zone
git init
```

### 2. Add All Files
```powershell
git add .
```

### 3. Create Initial Commit
```powershell
git commit -m "Initial commit: Azure Landing Zone with hub-spoke topology"
```

### 4. Create GitHub Repository
Go to GitHub (https://github.com/new) and create a new repository with the name:
**azure-landing-zone-terraform**

Settings:
- ✓ Public or Private (your choice)
- ✗ Do NOT initialize with README (we already have one)
- ✗ Do NOT add .gitignore (we already have one)
- ✗ Do NOT add license (we already have one)

### 5. Add Remote Origin
Replace `YOUR-USERNAME` with your GitHub username:
```powershell
git remote add origin https://github.com/YOUR-USERNAME/azure-landing-zone-terraform.git
```

### 6. Rename Branch to Main (if needed)
```powershell
git branch -M main
```

### 7. Push to GitHub
```powershell
git push -u origin main
```

## Alternative: Using SSH
If you prefer SSH authentication:

```powershell
git remote add origin git@github.com:YOUR-USERNAME/azure-landing-zone-terraform.git
git push -u origin main
```

## After Pushing

### Update Repository Settings on GitHub
1. Go to your repository on GitHub
2. Click "Settings"
3. Add topics/tags: `terraform`, `azure`, `infrastructure-as-code`, `landing-zone`, `hub-spoke`, `devops`
4. Add description: "Azure Landing Zone with Hub-Spoke network topology using Terraform"

### Enable GitHub Pages (Optional)
If you want to display the README as a website:
1. Settings → Pages
2. Source: Deploy from a branch
3. Branch: main → /root
4. Save

### Protect Main Branch
1. Settings → Branches
2. Add branch protection rule
3. Branch name pattern: `main`
4. Enable:
   - ✓ Require a pull request before merging
   - ✓ Require status checks to pass before merging

## Quick Reference

```powershell
# Check status
git status

# View remote URL
git remote -v

# View commit history
git log --oneline

# Create a new branch for changes
git checkout -b feature/new-feature

# Push new branch
git push -u origin feature/new-feature
```

## Common Issues

### Issue: Authentication Failed
**Solution:** Use a Personal Access Token (PAT)
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with `repo` scope
3. Use token as password when pushing

### Issue: Remote Already Exists
```powershell
# Remove existing remote
git remote remove origin

# Add new remote
git remote add origin https://github.com/YOUR-USERNAME/azure-landing-zone-terraform.git
```

### Issue: Merge Conflicts
```powershell
# Pull latest changes first
git pull origin main --rebase

# Resolve conflicts, then:
git add .
git rebase --continue
git push origin main
```
