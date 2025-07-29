# Element Infrastructure Project

## ✨ How to Use

Open PowerShell and run:

```powershell
.\terraform-deploy.ps1 -Action init
.\terraform-deploy.ps1 -Action plan
.\terraform-deploy.ps1 -Action apply -AutoApprove
.\terraform-deploy.ps1 -Action destroy
```

By default, it runs in the current directory (`"."`). You can pass `-TerraformDir "infra"` or any folder that holds your `.tf` files.

## Resources must create manual

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
