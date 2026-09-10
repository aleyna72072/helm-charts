# eduMFA chart

> [!IMPORTANT]
> This chart is currently considered experimental and does not offer
  configuration stability until version 1.0.0. Breaking changes can happen in
  any release.

This is a Helm chart for eduMFA. It enables deploying eduMFA in Kubernetes
environments.  
Features:
- supports common eduMFA tasks (audit, JWT blocklist, and challenge cleanup and
  edumfa-cron)
- scaleable deployments
- all secrets passed as files, not environment variables
- runs as non-root with limited capabilities and a read-only filesystem
- no PersistentVolume needed

Caveats:
- Requires a database to already exist (see
  [eduMFA documentation](https://edumfa.readthedocs.io/en/latest/installation/database.html)).
- As eduMFA does not (at the time of writing) communicate which upgrades work
  without restarting eduMFA, this chart goes the safe-by-default route:
  + Deployments use the "recreate" strategy, which means the old pods are killed
    before new ones are started. This avoids two versions running at the same
    time, but also that there is a _small_ downtime between the last pod having
    terminated and the first new pod being ready to serve requests.
  + New pods block until the database migration has finished. This results in
    downtime while the migration job is running during upgrades which have
    those.
- Database maintenance and admin creation happen via a Helm
  post-upgrade/post-install hook. This means that the Helm commands block until
  the hook is finished, and fail if the hook fails.
- Does not yet support running user-defined scripts.


## Installation

This section describes installing this chart into an existing Kubernetes
cluster.

### Prerequisites

To install this chart, you'll need:
- A database for eduMFA to use.
- Helm has to be installed.
- The name of the namespace you want to use.
- If you want to use the below guide to create the essential secret,
  [uv](https://docs.astral.sh/uv/getting-started/installation/)  has to be
  installed. Alternatively, you could use edumfa-manage directly by installing
  it via pip.
 
### Create the essentialSecret

The chart needs a secret (for "essentialSecretName") containing the following
fields:

- ``enckey`` The encryption key for the token secrets in the database.
- ``private.pem`` The audit private key.
- ``public.pem`` The audit public key.
- ``secret_key`` The key for signing JWTs.
- ``pepper`` The pepper for the passwords stored in eduMFA.

Failing to provide these values will mean the Helm deployment fails. Here is an
example how to create a suitable secret:

<!-- TODO: It would be nice to have path options for the uv commands below. -->

1. Create an empty directory, `cd` into it.
2. Create the enckey
- Create a new key and note its path:
  `uv run -w edumfa --prerelease=allow edumfa-manage create_enckey`
- Move the key to your current directory.
3. Create the audit key
- Create the key:
  `uv run -w edumfa --prerelease=allow edumfa-manage create_audit_keys`
- Move the certificate and key to your current directory.
4. Create a secret key for the JWTs:
   `$ tr -dc A-Za-z0-9_ </dev/urandom | head -c48 > secret_key`
5. Create a pepper: `$ tr -dc A-Za-z0-9_ </dev/urandom | head -c48 > pepper`
6. Create a Kubernetes secret from these files:
- Remove the `edumfa.log` file if it was created.
- `$ kubectl create secret generic edumfa-secrets --from-file=. -n $YOUR_NAMESPACE`
- Add `--dry-run=client -o=yaml` to the above command, if you want to take a
  look at it before uploading it to your cluster.
7. **Backup the files in this directory before deleting them!**  Especially the
   enckey is necessary to restore from a database backup as token secrets are
   encrypted.
8. After **backing them up** you may delete the directory and files.

The resulting secret will look like this:

```yaml
apiVersion: v1
data:
  enckey: NlgIQb3CrZ2AEWKF1iy3+I1V+dvX7k8ueWtPW+yVsULdcLg2Nxfo+zp+CiCyy6Y9Jt4rXX+PCmxG3T012phgP7WPL8tTY0zBC+JWd5nLZ3eLccVX1Qsw96XWKg5OL8qX
  pepper: UlJCbG1LazdxMHdIMk5ET1ZpVndldUlBZWQwdF9vTXNKZ2ZTVEl2V3dPSXk1V1hl
  private.pem: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBejJ2bHF3bXZSYkQ3end1eHBtNVJqZTIzTGhZK2pkYXdXREhZR3R0VVJ0ZnhLTndaCk5oNjRzLzRRSWlWSnpzRHBLd09JbW5nTmVGTktldjc1WFFOcTNpV1I4TnEwMUwzdHQ5Y25wSlg0VStybGtGSEkKTHpXTzdtam1xQjhWb0duc0JJREliMkJ3VU02VkFaUkt3NlBMZDFPc3VtbGZDVHNBUzZxNnBWNzJIaC8yV1NSVwpjN1c0ZGRtZFZ5OFRzdlJCbC9uU0szc1EzQTg2d1lsR1p0eVVpYzR2Y3duUGF4c1NxWm0weUhCQjJWb1JuTDRJCjAyT3JKVnJsbFluQ1FmZUlna1RnL0ZUMWRLcEphL01MYmtYUVA0UjVLbkhFTFhzNGpPTlNrcERqalpqWkluWUoKdGsrT1JGSzBYTXBwL3RaMHRxMUhDcm45K3hubFFweXNsTWpRUXdJREFRQUJBb0lCQUM1MkpNUGpMM2VVNVZMRApjOCtyOW1pc1R0UHI5NmNkNS9KWmQrYk1LbHlVRWxqc3RGa0RHS3g0eEhSaGxkN1NKMmlUS2c0dnhoU2wwNUVwCmZBSHh1Z1o0cy9BWGpWbjZFVDJVM0RScHcyNUl0NU5VUGxzVXpDZHJKLytRdHU5dnlvWlhzbzRBTkNobG5jcjAKeEtwK0RoMTBpTVJZeGdqelJtV3NvSkphYXhiaituNUQ2N20wYkFhbXQ1QmVTMi90VXJ1VGREU2tJcXVRalAwOApyZ0JQVXF1THpsbytGWE5SUFovY3NyR2RiVm54WlpqTUdua3JYMVRZTWNMZHR0NzVnZVU3emNSWENRVGxacE5sCm1hZURvaDc0OW53QW5VdjhMSXVBS2MyYjdWRXM0emNkNXBwQS9JMTBseTFRM0c2WnFudkJwRktBeFVYeThBUnYKeWhXMVcwRUNnWUVBOWZ2NmFUbndZQU15NWlnTzc1Ni9VWTc1dVVzdVV2OEFVRW5nUE44VkRjREtTMnlpOTFiRgpUOCtVRGV4cGMydnJUWDRYYUQraGhBNmd1SmRpWkJydEt1RUJnakpCWCtTRm1NS0NBc3Fwa0p1QmJZSlhxQnBFCi9xeTBpbE85WjdaUi9oNU9LdzU5c3VES2wySWV1bEdpcmpNNmFsa0ZWYU1INi9mRk1tTmNXNVVDZ1lFQTE5MzEKYjdWZnJzQXJzd1BHZ21zYm85am10ZEtmTkN3K1Z1ZW9TSUJ1bTJIeHVLdnNGTDNjcG9NUkw3OXN6a3lIdnc4aQp1OVEvMTVDSEFBUncyK2lJbTFDcXNjdUhBVElrTmdUakVJQ0FVWFBUeTlCdm16by90QmQ4WllMeVE2dEs5dGtxCjF0Y2U0eGJJRVRvbGxrdVVLRnJIaXdKQTNsdEdkd0JZMUJTeHhuY0NnWUVBNUo4SWN5cHRkZDhqUEhTNHhRN24KUkRjOWRIRWlvZkx0YUxIdzNzSjcvK2RTWFYyZjdZQlJMTWVDRkpySXU0VHZFbndCNTF0VWs3ZEF1NisvdThpbQo2M1pxLzRZVDZyc3JTL3BqK1pKQW5PMWJFdHZVK3FGSHhPZmhlTHN4eTZYUmVQelRyQUx3NHdNNGFCREMvR3FKClo1eW5TMVpudGRzcnJxMy9Nc0RVZ3kwQ2dZQVJScTFHNUhBazd6SlFJR1E1dWRLN2VUZDFvOGFrQ1VwdjhCaFMKdlJ5ZENPaXNpKzNYOXgzNm9aQzFqbzlwcjB4SjZTOHhjeG9zNlY4MGpDWndJeHNUdXcvK0xMakFTc0FGSnJ6NQpiQjlZNVhrMDNaaWhCcmRrZFdDNlN4R1NndG44Q1lOWk1GeERkbVpLb3FteGJwa0w1Y0FFaXdpZ0F4UVBvQko3CjNyQWZud0tCZ0hzRHdmRUg3c0FoRTJOWUx5Z1F6TldWUDcyUHFDbURiMXJla2lXcHpKbHVleEMwamkrYmNyQ1kKL1Nvekw3YitWMHd6S1BxSWxORnNjcE93RHNXQWNhY25IcTdCdlhLVEI4eXRqMWduMmE4NkZ3SXIwOWdpRDNKUwpqcGNwSG5zRmloVVRwbmVqM3VPYzB6dEY5bFhwTEVyUDlaUkQ0RysyaG1UMXVITGlIYzBxCi0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==
  public.pem: LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF6MnZscXdtdlJiRDd6d3V4cG01UgpqZTIzTGhZK2pkYXdXREhZR3R0VVJ0ZnhLTndaTmg2NHMvNFFJaVZKenNEcEt3T0ltbmdOZUZOS2V2NzVYUU5xCjNpV1I4TnEwMUwzdHQ5Y25wSlg0VStybGtGSElMeldPN21qbXFCOFZvR25zQklESWIyQndVTTZWQVpSS3c2UEwKZDFPc3VtbGZDVHNBUzZxNnBWNzJIaC8yV1NSV2M3VzRkZG1kVnk4VHN2UkJsL25TSzNzUTNBODZ3WWxHWnR5VQppYzR2Y3duUGF4c1NxWm0weUhCQjJWb1JuTDRJMDJPckpWcmxsWW5DUWZlSWdrVGcvRlQxZEtwSmEvTUxia1hRClA0UjVLbkhFTFhzNGpPTlNrcERqalpqWkluWUp0aytPUkZLMFhNcHAvdFowdHExSENybjkreG5sUXB5c2xNalEKUXdJREFRQUIKLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCg==
  secret_key: NkRlSjAxa3lXdEZfTGZJdDhGTl9tRHBVdDlMWUhkSXRtTFJVM0xESURLQ1E2ckhn
kind: Secret
metadata:
  name: edumfa-secrets
  namespace: $YOUR_NAMESPACE
```

### Deployment

After having created the essentialSecret and having a database ready, you can
proceed with the deployment.

1. Download the `values.yaml` for the latest version.
2. Edit `values.yaml` to  your liking. At minimum, change `.edumfa.db`.
3. Install:
   `helm install -n $YOUR_NAMESPACE $RELEASE_NAME -f values.yaml  'oci://ghcr.io/edumfa/helm-charts/edumfa' --version $LATEST_VERSION`

See the list of available versions [here](https://ghcr.io/edumfa/helm-charts/edumfa).
