# FSCK-Email
Python script which can be run at Linux boot time to report results of systemd-fsck service results

## Email credentials

The Gmail app password is read from the `FSCK_EMAIL_PASSWORD` environment
variable and must not be committed to this repository.

### Guided setup

Run the interactive setup wizard and follow its prompts:

```bash
./setup.sh
```

The wizard pauses until the exposed password has been revoked, accepts the new
password without echoing it, installs the protected environment file and
systemd unit, enables the service, and optionally sends a test email.

### Manual setup

For the included systemd service, create `/etc/fsck-email.env` as root:

```text
FSCK_EMAIL_FROM=sender@example.com
FSCK_EMAIL_TO=recipient@example.com
FSCK_EMAIL_PASSWORD=your-gmail-app-password
FSCK_EMAIL_SMTP_HOST=smtp.gmail.com
FSCK_EMAIL_SMTP_PORT=587
```

Restrict the file and reload the service definition:

```bash
sudo chmod 600 /etc/fsck-email.env
sudo cp systemd/FSCK-Email.service /etc/systemd/system/FSCK-Email.service
sudo systemctl daemon-reload
```

Generate the password as a Google app password, not the account's primary
password. Revoke and replace it immediately if it is ever committed or shared.

## Boot-time network delays and retries

The service requests `network-online.target` and runs after it. DNS or SMTP
can still be unavailable at that point, so failed attempts are retried after
30 seconds. Each attempt has a 60-second timeout, with at most 10 starts
within a 15-minute interval. If that limit is reached, automatic retries stop.
After correcting the problem, reset the limit and try again:

```bash
sudo systemctl reset-failed FSCK-Email.service
sudo systemctl start FSCK-Email.service
```

A successful one-shot run normally ends as `inactive (dead)` with
`Result=success`; it is not restarted after success. The email contains the
current boot's filesystem-check log entries; restarting this service does not
run another filesystem check. Retrying after an ambiguous SMTP failure can
occasionally send a duplicate report.

To apply these settings to an existing installation without changing credentials:

```bash
sudo cp systemd/FSCK-Email.service /etc/systemd/system/FSCK-Email.service
sudo systemctl daemon-reload
```

Existing systemd drop-ins still take precedence. An identical retry drop-in can
remain installed; review any conflicting overrides with
`systemctl cat FSCK-Email.service`.
