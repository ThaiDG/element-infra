# ✨ How to Use

Open PowerShell and run:

```powershell
.\terraform-deploy.ps1 -Action init
.\terraform-deploy.ps1 -Action plan
.\terraform-deploy.ps1 -Action apply -AutoApprove
.\terraform-deploy.ps1 -Action destroy
```

By default, it runs in the current directory (`"."`). You can pass `-TerraformDir "infra"` or any folder that holds your `.tf` files.
