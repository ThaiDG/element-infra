param (
    [ValidateSet("init", "plan", "apply", "destroy")]
    [string]$Action = "apply",

    [string]$TerraformDir = ".",

    [switch]$AutoApprove
)

# Navigate to Terraform directory
Set-Location $TerraformDir

Write-Host "Running Terraform '$Action' in directory: $TerraformDir" -ForegroundColor Cyan

# Run Terraform action
switch ($Action) {
    "init" {
        terraform init `
            -backend-config="key=demo/element/terraform.tfstate" `
            -backend=true `
            -input=false
    }

    "plan" {
        terraform plan -var-file="terraform.tfvars"
    }

    "apply" {
        if ($AutoApprove) {
            terraform apply -auto-approve -var-file="terraform.tfvars"
        } else {
            terraform apply -var-file="terraform.tfvars"
        }
    }

    "destroy" {
        if ($AutoApprove) {
            terraform destroy -auto-approve -var-file="terraform.tfvars"
        } else {
            terraform destroy -var-file="terraform.tfvars"
        }
    }
}

Write-Host "Terraform '$Action' completed" -ForegroundColor Green
