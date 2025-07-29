# Element Infrastructure Project

## ✨ How to Use

Open PowerShell, change directory to `homeserver` and run:

```shell
make init # The command below will always automatically run this command first, so, you don't need to manually run it.
make select-workspace # Optional - This will also trigger the make init. You don't need to run this command manually.
make plan ENV=[dev,staging,prod] # This command will run the make select-workspace first, you can skip the ENV to use the default demo ENV
make apply AUTOAPPROVE ENV=[dev,staging,prod] # This command will run the make select-workspace first, you can skip the ENV to use the default demo ENV
make destroy AUTOAPPROVE ENV=[dev,staging,prod] # This command will run the make select-workspace first, you can skip the ENV to use the default demo ENV
```

### Window user note

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
