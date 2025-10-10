#!/usr/bin/env bash
# Uso: sudo bash init_ofs.sh <NombreOVS> <interfaz1> <interfaz2> ... --vlans 100,200,300 --gw-base 10. --uplink ethX
#  - Si pasas --vlans: crea subinterfaces tipo "vlan<id>" en el host OFS y setea IPs GW 10.<vid>.0.1/24
#  - Si pasas --uplink: aplicará MASQUERADE para salida a Internet vía esa interfaz
#  - Si omites flags, se comporta como tu versión básica (solo trunk)

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Uso: $0 <NombreOVS> <if1> [<if2> ...] [--vlans v1,v2,...] [--gw-base 10.] [--uplink ethX]"
  exit 1
fi

OVS_NAME=$1; shift
INTERFACES=()
VLAN_LIST=""
GW_BASE="10."
UPLINK_IF=""

# Parseo simple
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vlans) VLAN_LIST="$2"; shift 2;;
    --gw-base) GW_BASE="$2"; shift 2;;
    --uplink) UPLINK_IF="$2"; shift 2;;
    *) INTERFACES+=("$1"); shift;;
  esac
done

# Crear OVS si no existe
if ! ovs-vsctl br-exists "$OVS_NAME" 2>/dev/null; then
  echo "[OFS] Creando bridge $OVS_NAME ..."
  ovs-vsctl add-br "$OVS_NAME"
fi

# Limpiar IPs y agregar interfaces como puertos troncales
for IFACE in "${INTERFACES[@]}"; do
  echo "[OFS] Conectando $IFACE a $OVS_NAME como trunk ..."
  ip addr flush dev "$IFACE" || true
  ip link set "$IFACE" up
  ovs-vsctl --may-exist add-port "$OVS_NAME" "$IFACE" trunks=1-4094
done

# (Opcional) Gateways por VLAN en el OFS
if [[ -n "$VLAN_LIST" ]]; then
  IFS=',' read -r -a VIDS <<< "$VLAN_LIST"
  for VID in "${VIDS[@]}"; do
    IF_VLAN="vlan${VID}"
    GW_IP="${GW_BASE}${VID}.0.1/24"
    echo "[OFS] Creando interfaz GW $IF_VLAN para VLAN $VID con IP $GW_IP ..."
    # Creamos una interfaz interna de OVS para esa VLAN
    ovs-vsctl --may-exist add-port "$OVS_NAME" "$IF_VLAN" tag="$VID" -- set Interface "$IF_VLAN" type=internal
    ip link set "$IF_VLAN" up
    ip addr flush dev "$IF_VLAN" || true
    ip addr add "$GW_IP" dev "$IF_VLAN"
  done
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
fi

# (Opcional) NAT en el OFS
if [[ -n "$UPLINK_IF" ]]; then
  echo "[OFS] Configurando NAT (MASQUERADE) via $UPLINK_IF ..."
  iptables -t nat -C POSTROUTING -o "$UPLINK_IF" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o "$UPLINK_IF" -j MASQUERADE
  iptables -C FORWARD -i "$UPLINK_IF" -o "$OVS_NAME" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i "$UPLINK_IF" -o "$OVS_NAME" -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -C FORWARD -i "$OVS_NAME" -o "$UPLINK_IF" -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i "$OVS_NAME" -o "$UPLINK_IF" -j ACCEPT
fi

echo "[OFS] Inicialización completada para $OVS_NAME"
