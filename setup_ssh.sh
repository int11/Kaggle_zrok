#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# Function to export environment variables from a file
export_env_vars_from_file() {
    local env_file=$1
    while IFS= read -r line; do
        if [[ "$line" =~ ^[A-Z0-9_]+=.* ]]; then
            export "$line"
        fi
    done <"$env_file"
}

# Path to the captured environment variables file
ENV_VARS_FILE=/kaggle/working/kaggle_env_vars.txt

if [ -f "$ENV_VARS_FILE" ]; then
    echo "Exporting environment variables from $ENV_VARS_FILE"
    export_env_vars_from_file "$ENV_VARS_FILE"
else
    echo "Environment variables file $ENV_VARS_FILE not found"
fi

# Make authorized keys URL optional
AUTH_KEYS_URL=$1

setup_ssh_directory() {
    mkdir -p /kaggle/working/.ssh
    if [ ! -z "$AUTH_KEYS_URL" ]; then
        if wget -qO /kaggle/working/.ssh/authorized_keys "$AUTH_KEYS_URL"; then
            chmod 700 /kaggle/working/.ssh
            chmod 600 /kaggle/working/.ssh/authorized_keys
            echo "Successfully set up authorized keys from $AUTH_KEYS_URL"
        else
            echo "Failed to download authorized keys from $AUTH_KEYS_URL"
            echo "Continuing without authorized keys setup..."
        fi
    else
        echo "No authorized keys URL provided. Continuing without authorized keys setup..."
    fi
}

create_symlink() {
    if [ -d /kaggle/working/Kaggle_VSCode_Remote_SSH/.vscode ]; then
        [ -L /kaggle/.vscode ] && rm /kaggle/.vscode
        ln -s /kaggle/working/Kaggle_VSCode_Remote_SSH/.vscode /kaggle/.vscode
        echo "Symlink to .vscode folder created."
        ls -l /kaggle/.vscode
    else
        echo ".vscode directory not found in repository."
    fi
}

configure_sshd() {
    mkdir -p /var/run/sshd
    {
        echo "Port 22"
        echo "Protocol 2"
        echo "PermitRootLogin yes"
        echo "PasswordAuthentication yes"
        echo "PubkeyAuthentication yes"
        if [ ! -z "$AUTH_KEYS_URL" ]; then
            echo "AuthorizedKeysFile /kaggle/working/.ssh/authorized_keys"
        fi
        echo "TCPKeepAlive yes"
        echo "X11Forwarding yes"
        echo "X11DisplayOffset 10"
        echo "IgnoreRhosts yes"
        echo "HostbasedAuthentication no"
        echo "PrintLastLog yes"
        echo "ChallengeResponseAuthentication no"
        echo "UsePAM yes"
        echo "AcceptEnv LANG LC_*"
        echo "AllowTcpForwarding yes"
        echo "GatewayPorts yes"
        echo "PermitTunnel yes"
        echo "ClientAliveInterval 60"
        echo "ClientAliveCountMax 2"
    } >>/etc/ssh/sshd_config
}

install_packages() {
    echo "Installing openssh-server..."
    sudo apt-get update
    sudo apt-get install -y openssh-server
}

start_ssh_service() {
    service ssh start
    service ssh enable
    service ssh restart
}

cleanup() {
    [ -f /kaggle/working/kaggle_env_vars.txt ] && rm /kaggle/working/kaggle_env_vars.txt
}

(
    install_packages
    setup_ssh_directory &
    create_symlink &
    configure_sshd &
    wait
    start_ssh_service &
    wait
    cleanup
    chmod +x install_extensions.sh
)

echo "Setup script completed successfully"
echo "All tasks completed successfully"
