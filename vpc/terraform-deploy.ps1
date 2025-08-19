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
        # Get the current workspace
        $workspace = terraform workspace show
        $env:TF_VAR_workspace = $workspace

        terraform plan
    }

    "apply" {
        # Get the current workspace
        $workspace = terraform workspace show
        $env:TF_VAR_workspace = $workspace

        if ($AutoApprove) {
            terraform apply -auto-approve
        } else {
            terraform apply
        }
    }

    "destroy" {
        # Get the current workspace
        $workspace = terraform workspace show
        $env:TF_VAR_workspace = $workspace

        if ($AutoApprove) {
            terraform destroy -auto-approve
        } else {
            terraform destroy
        }
    }
}

Write-Host "Terraform '$Action' completed" -ForegroundColor Green
