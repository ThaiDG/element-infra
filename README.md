# Element Infrastructure Project

## ✨ How to Use

Open PowerShell and run:

### Direct run

```powershell
.\terraform-deploy.ps1 -Action init
.\terraform-deploy.ps1 -Action plan
.\terraform-deploy.ps1 -Action apply -AutoApprove
.\terraform-deploy.ps1 -Action destroy
```

### Run with make command

```shell
make init
make plan
make apply AUTOAPPROVE
make destroy AUTOAPPROVE
```

#### Window user note

If you don't want to specific the OS for every make command then follow the below steps:

- Run the command: `$PROFILE` to get the current shell profile

- Open the profile and add the below content:

    ```powershell
    $env:OS = "windows"
    Write-Host "Default OS set to $env:OS"
    ```

- Save file and reload the terminal.

- Otherwise you can run make file by: `make init OS=windows`

## Resources must be created manually

### SSM Parameter Store

- SMTP Server:
  - /smtp/user
  - /smtp/pass
- Apple Push Notification service (APNs):
  - /sygnal/apns/team_id
  - /sygnal/apns/key_id
  - /sygnal/apns/auth_key_`key_id`
- Google Cloud Messaging/Firebase Cloud Messaging (GCM/FCM):
  - /sygnal/gcm/package-name
  - /sygnal/gcm/project-id
  - /sygnal/gcm/`project-id`-firebase-adminsdk
- LiveKit Cloud:
  - /synapse/livekit/url
  - /synapse/livekit/key
  - /synapse/livekit/secret
- Postgres:
  - /synapse/postgres/user
  - /synapse/postgres/password
  - /synapse/postgres/db - Database name of the Synapse server
- Google reCAPTCHA:
  - /synapse/reCAPTCHA/public_key
  - /synapse/reCAPTCHA/private_key
- ZeroSSL External Account Binding (EAB) - Using for coTURN SSL:
  - /zerossl/eab_kid
  - /zerossl/eab_hmac_key

## Additional Note

- Change in scripts folder which will only being executed at the initial stage of the instance therefore we must to run the refresh command: `aws autoscaling start-instance-refresh --auto-scaling-group-name change-affected-asg --region ap-southeast-1` to apply the change after running the Terraform apply command.
