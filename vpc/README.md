# VPC Creation Note

## Client VPN Endpoint

- Follow the blog to setup the Google SAML: <https://www.innablr.com.au/blog/aws-client-vpn-setup-with-google-workspace-formerly-g-suite-authentication>
  - Use FireFox for trick, choose the Edit and Send, looking at the batchexec and find out which one contain https to change into http
  - Google Workspace metadata is stored on S3: s3://767828741221-terraform-state-ap-southeast-1/vpc/GoogleIDPMetadata.xml
- The cert is just for security purpose, can be used any cert on ACM.
- The client_cidr_block must not overlap any subnet cidr.
