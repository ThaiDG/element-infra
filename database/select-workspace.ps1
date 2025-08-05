# Check if ENV is set
if (-not $env:ENV -or $env:ENV -eq "") {
    Write-Host "ENV is not set. Using default workspace: dev." -ForegroundColor Yellow
    Write-Host -NoNewline "Would you like to continue? [Y/n]: " -ForegroundColor Yellow
    $reply = Read-Host

    if ($reply -eq "" -or $reply -eq "Y" -or $reply -eq "y") {
        $env:ENV = "dev"
        Write-Host "Proceeding with workspace: $env:ENV" -ForegroundColor Cyan
        # Select the workspace
        terraform workspace select $env:ENV
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Workspace '$env:ENV' does not exist." -ForegroundColor Red
            Write-Host -NoNewline "Would you like to create a new one? [Y/n]: " -ForegroundColor Yellow
            $reply = Read-Host
            if ($reply -eq "" -or $reply -eq "Y" -or $reply -eq "y") {
                Write-Host "Creating new workspace: $env:ENV" -ForegroundColor Cyan
                # Initialize the workspace
                terraform workspace new $env:ENV
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Failed to create workspace '$env:ENV'. Exiting." -ForegroundColor Red
                    exit 1
            }
            } else {
                Write-Host "Aborting workspace creation." -ForegroundColor Red
                exit 1
            }
        }
        Write-Host "Workspace '$(terraform workspace show -no-color)' is now selected." -ForegroundColor Green
    } else {
        Write-Host "Aborting initialization." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "ENV is set to: $env:ENV"
    Write-Host "Proceeding with workspace: $env:ENV" -ForegroundColor Green
    # Select the workspace
    terraform workspace select $env:ENV
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Workspace '$env:ENV' does not exist." -ForegroundColor Red
        Write-Host -NoNewline "Would you like to create a new one? [Y/n]: " -ForegroundColor Yellow
        $reply = Read-Host
        if ($reply -eq "" -or $reply -eq "Y" -or $reply -eq "y") {
            Write-Host "Creating new workspace: $env:ENV" -ForegroundColor Cyan
            # Initialize the workspace
            terraform workspace new $env:ENV
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to create workspace '$env:ENV'. Exiting." -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Aborting workspace creation." -ForegroundColor Red
            exit 1
        }
    }
    Write-Host "Workspace '$(terraform workspace show -no-color)' is now selected." -ForegroundColor Green
}
