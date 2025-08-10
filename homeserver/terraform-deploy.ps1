param (
    [ValidateSet("init", "plan", "apply", "destroy")]
    [string]$Action = "apply",

    [switch]$AutoApprove
)

Write-Host "Running Terraform '$Action'" -ForegroundColor Cyan

# A dictionary to map the workspace names to their corresponding root domains
$baseDomain = "tapofthink.com"
# Define the root domains for each workspace
$workspaceDomains = @{
    "dev" = "dev.$baseDomain"
    "staging" = "staging.$baseDomain"
    "prod" = "chat.$baseDomain"
}

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
        # Set the root domain based on the current workspace
        if ($workspaceDomains.ContainsKey($workspace)) {
            $rootDomain = $workspaceDomains[$workspace]
        } else {
            Write-Error "Unknown workspace: $workspace" -ErrorAction Stop
            exit 1
        }
        $env:TF_VAR_root_domain = $rootDomain

        terraform plan
    }

    "apply" {
        # Get the current workspace
        $workspace = terraform workspace show
        $env:TF_VAR_workspace = $workspace
        # Set the root domain based on the current workspace
        if ($workspaceDomains.ContainsKey($workspace)) {
            $rootDomain = $workspaceDomains[$workspace]
        } else {
            Write-Error "Unknown workspace: $workspace" -ErrorAction Stop
            exit 1
        }
        $env:TF_VAR_root_domain = $rootDomain

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
        # Set the root domain based on the current workspace
        if ($workspaceDomains.ContainsKey($workspace)) {
            $rootDomain = $workspaceDomains[$workspace]
        } else {
            Write-Error "Unknown workspace: $workspace" -ErrorAction Stop
            exit 1
        }
        $env:TF_VAR_root_domain = $rootDomain

        if ($AutoApprove) {
            terraform destroy -auto-approve
        } else {
            terraform destroy
        }
    }
}

Write-Host "Terraform '$Action' completed" -ForegroundColor Green
