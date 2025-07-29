param (
    [ValidateSet("init", "plan", "apply", "destroy")]
    [string]$Action = "apply",

    [switch]$AutoApprove
)

Write-Host "Running Terraform '$Action'" -ForegroundColor Cyan

# Run Terraform action
switch ($Action) {
    "init" {
        terraform init `
            -backend=true `
            -input=false `
            -reconfigure
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
