# FSCK-Email
Python script which can be run at Linux boot time to report results of systemd-fsck service results

## Email credentials

The Gmail app password is read from the `FSCK_EMAIL_PASSWORD` environment
variable and must not be committed to this repository.

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
