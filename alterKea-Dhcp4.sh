#!/bin/bash
# 🧠 Script: update-kea-dhcp4.sh
# 📅 Purpose: Interactive update of Kea DHCP4 DNS settings
# 🌐 Autor: Paulo Fernandes
# 🇬🇧 This script updates domain-name-servers, domain-name, and domain-search
# 🇵🇹 Este script atualiza os campos DNS no ficheiro kea-dhcp4.conf

CONFIG="/etc/kea/kea-dhcp4.conf"
TMP="/tmp/kea-dhcp4.conf.tmp"
LOG="/var/log/kea-dhcp4-update.log"

# 🧑‍💻 Prompt user for input
read -p "Enter DNS server IP (e.g., 10.0.0.10): " DNS_IP
read -p "Enter domain name (e.g., kalaustudio.com): " DOMAIN

# 🧪 Validate JSON before proceeding
if ! jq empty "$CONFIG" 2>/dev/null; then
  echo "❌ Invalid JSON in $CONFIG. Aborting."
  exit 1
fi

# 🛠 Update option-data block using jq
jq --arg dns "$DNS_IP" --arg dom "$DOMAIN" '
  .Dhcp4."option-data" |= map(
    if .name == "domain-name-servers" then .data = $dns
    elif .name == "domain-name" then .data = $dom
    elif .name == "domain-search" then .data = $dom
    else .
    end
  )
' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"

# 📅 Log the change
echo "$(date '+%Y-%m-%d %H:%M:%S') Updated DNS to $DNS_IP and domain to $DOMAIN" >> "$LOG"

# 🔁 Restart Kea DHCP service
systemctl restart kea-dhcp4 && echo "✅ Kea DHCP4 restarted successfully."

# 🇵🇹 Finalização
echo "✅ Configuração atualizada com sucesso!"
