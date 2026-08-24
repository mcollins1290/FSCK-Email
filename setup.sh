#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=/etc/fsck-email.env
SERVICE_FILE=/etc/systemd/system/FSCK-Email.service
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SERVICE_SOURCE="$SCRIPT_DIR/systemd/FSCK-Email.service"

say() {
    printf '\n%s\n' "$*"
}

ask_yes_no() {
    local prompt=$1
    local default=${2:-no}
    local answer
    local hint='[y/N]'

    if [[ $default == yes ]]; then
        hint='[Y/n]'
    fi

    read -r -p "$prompt $hint " answer
    if [[ -z $answer ]]; then
        [[ $default == yes ]]
        return
    fi
    [[ $answer =~ ^[Yy]([Ee][Ss])?$ ]]
}

prompt_required() {
    local variable_name=$1
    local prompt=$2
    local value

    while true; do
        read -r -p "$prompt: " value
        if [[ -n $value ]]; then
            printf -v "$variable_name" '%s' "$value"
            return
        fi
        printf 'A value is required.\n'
    done
}

if [[ ${EUID} -ne 0 ]]; then
    say 'Root access is required to protect credentials and configure systemd.'
    exec sudo -- "$0" "$@"
fi

say 'FSCK-Email guided setup'
printf '%s\n' \
    'This wizard configures the local service, but it cannot access your Google account.' \
    'Before continuing:' \
    '  1. Revoke the previously exposed Gmail app password.' \
    '  2. Generate a new Gmail app password for this service.' \
    '  3. Keep the new password ready; input will be hidden.'

if ! ask_yes_no 'Have you revoked the old password and generated a replacement?' no; then
    say 'Setup stopped. Complete those Google account steps, then run this script again.'
    exit 1
fi

prompt_required from_address 'Sender email address'
prompt_required to_address 'Recipient email address'

read -r -p 'SMTP host [smtp.gmail.com]: ' smtp_host
smtp_host=${smtp_host:-smtp.gmail.com}

while true; do
    read -r -p 'SMTP port [587]: ' smtp_port
    smtp_port=${smtp_port:-587}
    if [[ $smtp_port =~ ^[0-9]+$ ]] && (( smtp_port >= 1 && smtp_port <= 65535 )); then
        break
    fi
    printf 'Enter a port between 1 and 65535.\n'
done

while true; do
    read -r -s -p 'New Gmail app password: ' app_password
    printf '\n'
    app_password=${app_password//[[:space:]]/}
    if [[ -n $app_password ]]; then
        break
    fi
    printf 'A password is required.\n'
done

say 'Configuration summary'
printf '  Sender:    %s\n' "$from_address"
printf '  Recipient: %s\n' "$to_address"
printf '  SMTP:      %s:%s\n' "$smtp_host" "$smtp_port"
printf '  Password:  (hidden)\n'

if ! ask_yes_no 'Install this configuration?' yes; then
    say 'No changes were made.'
    exit 0
fi

umask 077
temp_env=$(mktemp /etc/fsck-email.env.tmp.XXXXXX)
trap 'find "$temp_env" -maxdepth 0 -type f -delete 2>/dev/null || true' EXIT

printf 'FSCK_EMAIL_FROM=%s\n' "$from_address" > "$temp_env"
printf 'FSCK_EMAIL_TO=%s\n' "$to_address" >> "$temp_env"
printf 'FSCK_EMAIL_PASSWORD=%s\n' "$app_password" >> "$temp_env"
printf 'FSCK_EMAIL_SMTP_HOST=%s\n' "$smtp_host" >> "$temp_env"
printf 'FSCK_EMAIL_SMTP_PORT=%s\n' "$smtp_port" >> "$temp_env"
install -o root -g root -m 600 "$temp_env" "$ENV_FILE"

if [[ -e $SERVICE_FILE ]]; then
    backup_file="$SERVICE_FILE.backup.$(date +%Y%m%d%H%M%S)"
    cp --preserve=mode,ownership,timestamps "$SERVICE_FILE" "$backup_file"
    printf 'Backed up the existing service to %s\n' "$backup_file"
fi

install -o root -g root -m 644 "$SERVICE_SOURCE" "$SERVICE_FILE"
mkdir -p "$SCRIPT_DIR/Log"
systemctl daemon-reload
systemctl enable FSCK-Email.service

unset app_password

say 'Installation complete.'
printf 'Credentials: %s (root-only, mode 600)\n' "$ENV_FILE"
printf 'Service:     %s\n' "$SERVICE_FILE"

if ask_yes_no 'Start the service now to send a test email?' no; then
    if systemctl start FSCK-Email.service; then
        say 'Test completed successfully. Check the recipient inbox.'
    else
        say 'The test failed. Review: systemctl status FSCK-Email.service'
        exit 1
    fi
else
    say 'Test skipped. Run it later with: sudo systemctl start FSCK-Email.service'
fi
