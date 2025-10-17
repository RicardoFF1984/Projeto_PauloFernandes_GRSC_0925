#!/bin/bash

#!/bin/bash

# Instalar Kea DHCP via repositório oficial da ISC
echo "Instalando Kea DHCP Server..."
sudo dnf install -y curl gnupg
curl -1sLf 'https://dl.cloudsmith.io/public/isc/kea/setup.rpm.sh' | sudo bash
sudo dnf install -y kea-dhcp4 kea-dhcp4-devel kea-hooks

########### DEFINIR IP ESTÁTICO ##############

echo "CONFIGURAR IP ESTÁTICO"

netinterface=$(ip -brief addr | grep UP | awk '{print $1}')

while true; do
  echo "Escolha o teu IP:"
  read ip
  echo "Escreva o prefixo:"
  read cidr
  fullip="${ip}/${cidr}"

  IFS='.' read -r a b c d <<< "$ip"
  if [ "$a" -ge 255 ] || [ "$b" -ge 255 ] || [ "$c" -ge 255 ] || [ "$d" -ge 255 ]; then
    echo "IP Inválido. Insere um novo."
    continue
  elif [[ "$a" == 192 && "$b" == 168 ]] || [[ "$a" == 172 && "$b" -ge 16 && "$b" -le 32 ]] || [[ "$a" == 10 ]]; then
    break
  else
    echo "O IP é público. Deves inserir um privado."
    continue
  fi
done

echo "Defina o gateway:"
read gateway
echo "Escolha o teu DNS:"
read dns

sudo nmcli connection modify "$netinterface" ipv4.addresses "$fullip" ipv4.gateway "$gateway" ipv4.dns "$dns"
sudo nmcli connection modify "$netinterface" ipv4.method manual
sudo nmcli connection down "$netinterface"
sudo nmcli connection up "$netinterface"

############# CONFIGURAR KEA DHCP ################

echo "CONFIGURAR KEA DHCP"

echo "Defina a rede (ex: 192.168.1.0):"
read subnet_dhcp
echo "Defina o prefixo (ex: 24):"
read prefix_dhcp
echo "Defina a range (ex: 192.168.1.100 - 192.168.1.200):"
read range_dhcp
echo "Escolha o DNS:"
read dns_dhcp
echo "Escolha o gateway:"
read gateway_dhcp

# Criar configuração básica do Kea
sudo tee /etc/kea/kea-dhcp4.conf > /dev/null <<EOF
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": [ "$netinterface" ]
    },
    "lease-database": {
      "type": "memfile",
      "persist": true,
      "name": "/var/lib/kea/dhcp4.leases"
    },
    "subnet4": [
      {
        "subnet": "$subnet_dhcp/$prefix_dhcp",
        "pools": [ { "pool": "$range_dhcp" } ],
        "option-data": [
          { "name": "routers", "data": "$gateway_dhcp" },
          { "name": "domain-name-servers", "data": "$dns_dhcp" }
        ]
      }
    ],
    "valid-lifetime": 7200,
    "renew-timer": 600,
    "rebind-timer": 1200
  }
}
EOF

# Abrir porta do Kea DHCP
sudo firewall-cmd --permanent --add-port=67/udp
sudo firewall-cmd --reload

# Ativar e iniciar Kea
sudo systemctl enable kea-dhcp4
sudo systemctl start kea-dhcp4
sudo systemctl status kea-dhcp4

echo "Kea DHCP configurado com sucesso!"

