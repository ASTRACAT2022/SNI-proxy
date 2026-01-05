#!/bin/bash

# This script is intended for Debian-based systems (e.g., Ubuntu)

# Exit on error
set -e

# --- Functions ---

# Function to display usage
usage() {
    echo "Usage: $0 {install|configure|start|stop|restart|reload|update}"
    exit 1
}

# Function to install Nginx
install_nginx() {
    echo "Installing Nginx..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confnew" nginx-full
}

# Function to configure Nginx
configure_nginx() {
    echo "Configuring Nginx..."

    local script_dir
    script_dir=$(dirname "$0")

    # Create directory for lists
    mkdir -p /etc/nginx/lists

    # Generate config files
    echo "" > /etc/nginx/lists/whitelist_domains.conf
    echo "" > /etc/nginx/lists/whitelist_domains_with_subdomains.conf
    echo "" > /etc/nginx/lists/whitelist_custom.conf
    echo "" > /etc/nginx/lists/banned_ips.conf
    cp "$script_dir/nginx.conf.template" /etc/nginx/nginx.conf

    if [ -f "$script_dir/lists/banned_ips.txt" ]; then
        awk '!/^#/ && NF {print $0 " 1;"}' "$script_dir/lists/banned_ips.txt" > /etc/nginx/lists/banned_ips.conf
    fi

    if [ -f "$script_dir/lists/domains.txt" ]; then
        awk 'NF {print $0 " 1;"}' "$script_dir/lists/domains.txt" > /etc/nginx/lists/whitelist_domains.conf
    fi

    if [ -f "$script_dir/lists/domains_with_subdomains.txt" ]; then
        awk 'NF {
            gsub(/\./, "\\\\.");
            print "~(^|\\\\.)" $0 "$ 1;"
        }' "$script_dir/lists/domains_with_subdomains.txt" > /etc/nginx/lists/whitelist_domains_with_subdomains.conf
    fi

    if [ -f "$script_dir/lists/custom.txt" ]; then
        awk 'NF {
            gsub(/\./, "\\\\.");
            print "~(^|\\\\.)" $0 "$ 1;"
        }' "$script_dir/lists/custom.txt" > /etc/nginx/lists/whitelist_custom.conf
    fi

    if [ "$LOG_ALL" != "true" ]; then
        sed -i 's|LOG_SETTING;|access_log off;|' /etc/nginx/nginx.conf
    else
        sed -i 's|LOG_SETTING;|access_log /var/log/nginx/access.log basic;|' /etc/nginx/nginx.conf
    fi

    nginx -t
}

# Function to start Nginx
start_nginx() {
    echo "Starting Nginx..."
    systemctl start nginx
}

# Function to stop Nginx
stop_nginx() {
    echo "Stopping Nginx..."
    systemctl stop nginx
}

# Function to restart Nginx
restart_nginx() {
    echo "Restarting Nginx..."
    systemctl restart nginx
}

# Function to reload Nginx
reload_nginx() {
    echo "Reloading Nginx..."
    systemctl reload nginx
}

# Function to update lists
update_lists() {
    echo "Updating lists..."
    local script_dir
    script_dir=$(dirname "$0")
    mkdir -p "$script_dir/lists"
    curl -L -o "$script_dir/lists/domains.txt" "https://github.com/ImMALWARE/dns.malw.link/raw/master/lists/domains.txt"
    curl -L -o "$script_dir/lists/domains_with_subdomains.txt" "https://github.com/ImMALWARE/dns.malw.link/raw/master/lists/domains_with_subdomains.txt"
    if [ -n "$BANNED_IPS_URL" ]; then
        curl -L -o "$script_dir/lists/banned_ips.txt" "$BANNED_IPS_URL"
    fi
    echo "Finished updating lists."

    # Configure and reload Nginx
    configure_nginx
    reload_nginx
}

# --- Main Logic ---

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

action="$1"

if [ -z "$action" ]; then
    usage
fi

case "$action" in
    install)
        install_nginx
        ;;
    configure)
        configure_nginx
        ;;
    start)
        start_nginx
        ;;
    stop)
        stop_nginx
        ;;
    restart)
        restart_nginx
        ;;
    reload)
        reload_nginx
        ;;
    update)
        update_lists
        ;;
    *)
        usage
        ;;
esac

echo "Done."
