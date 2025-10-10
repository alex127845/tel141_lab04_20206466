#!/usr/bin/env bash
# ns_create.sh
# Comando: sudo bash ns_create.sh <NombreNS> <NombreOVS> <VLAN_ID> <CIDR_RED> <RANGO_DHCP> <GW_IP>
# Ej:  sudo bash ns_create.sh red100 br-int 100 10.100.0.0/24 10.100.0.50,10.100.0.200 10.100.0.1

set -euo pipefail

NS=${1:-}
OVS=${2:-}
VID=${3:-}
CIDR=${4:-}
DHCP_RANGE=${5:-}
GW=${6:-}

if [[ -z "$NS" || -z "$OVS" || -z "$VID" || -z "$CIDR" || -z "$DHCP_RANGE" || -z "$GW" ]]; then
  echo "Uso: $0 <NombreNS> <NombreOVS> <VLAN_ID> <CIDR_RED> <RANGO_DHCP> <GW_IP>"
  exit 1
fi

VETH_HOST="veth_${NS}_host"
VETH_NS="veth_${NS}_ns"
DNSMASQ_LEASES="/var/run/dnsmasq_${NS}.leases"
DNSMASQ_PIDFILE="/var/run/dnsmasq_${NS}.pid"

# Crear namespace si no existe
ip netns list | grep -qw "$NS" || ip netns add "$NS"

# Crear veth si no existe
if ! ip link show "$VETH_HOST" &>/dev/null; then
  ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
fi

# Conectar extremo NS y configurar IP del GW
ip link set "$VETH_NS" netns "$NS"
ip link set "$VETH_HOST" up
ip netns exec "$NS" ip addr flush dev "$VETH_NS" || true
MASK=$(echo "$CIDR" | cut -d'/' -f2)
ip netns exec "$NS" ip addr add "$GW/$MASK" dev "$VETH_NS"
ip netns exec "$NS" ip link set "$VETH_NS" up
ip netns exec "$NS" ip link set lo up

# Añadir extremo host al OVS con tag VLAN
ovs-vsctl --may-exist add-port "$OVS" "$VETH_HOST" tag=$VID

# Levantar dnsmasq dentro del namespace (DHCP para la VLAN)
# Paramos instancia previa (si existiera)
if [[ -f "$DNSMASQ_PIDFILE" ]]; then
  kill "$(cat "$DNSMASQ_PIDFILE")" || true
  rm -f "$DNSMASQ_PIDFILE"
fi
rm -f "$DNSMASQ_LEASES" || true

ip netns exec "$NS" dnsmasq \
  --interface="$VETH_NS" \
  --bind-interfaces \
  --dhcp-range="$DHCP_RANGE",12h \
  --dhcp-option=3,"$GW" \
  --dhcp-leasefile="$DNSMASQ_LEASES" \
  --pid-file="$DNSMASQ_PIDFILE" \
  --conf-file=

echo "[NS:$NS] VLAN $VID en $OVS lista: GW=$GW, DHCP=$DHCP_RANGE"
