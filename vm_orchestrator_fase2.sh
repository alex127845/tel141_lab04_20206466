#!/usr/bin/env bash
set -euo pipefail

PASS="adrian123"
SSHP="sshpass -p $PASS ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Parámetros base
OVS_HN="br-int"
HN_DATA_IF="ens4"
HN_UPLINK_IF="ens3"
VLANS=("100" "200" "300")

echo "[Fase2] Inicializando HeadNode (LOCAL)..."
sudo bash ~/init_headnode.sh $OVS_HN $HN_DATA_IF ${HN_UPLINK_IF:-}

echo "[Fase2] Creando namespaces + DHCP por VLAN..."
for VID in "${VLANS[@]}"; do
  case "$VID" in
    100) NET="192.168.10" ;;
    200) NET="192.168.20" ;;
    300) NET="192.168.30" ;;
    *) echo "[ERR] VLAN $VID sin mapeo"; exit 1 ;;
  esac

  CIDR="${NET}.0/24"
  GW="${NET}.1"
  DHCP_RANGE="${NET}.50,${NET}.200"

  # Ejecución LOCAL (sin SSH)
  sudo bash ~/ns_create.sh red${VID} $OVS_HN $VID "$CIDR" "$DHCP_RANGE" "$GW"
done

# NAT en HeadNode
if [[ -n "$HN_UPLINK_IF" ]]; then
  echo "[Fase2] Configurando NAT local via $HN_UPLINK_IF..."
  sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
  sudo iptables -t nat -C POSTROUTING -o "$HN_UPLINK_IF" -j MASQUERADE 2>/dev/null || \
    sudo iptables -t nat -A POSTROUTING -o "$HN_UPLINK_IF" -j MASQUERADE
  sudo iptables -C FORWARD -i "$HN_UPLINK_IF" -o "$OVS_HN" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
    sudo iptables -A FORWARD -i "$HN_UPLINK_IF" -o "$OVS_HN" -m state --state RELATED,ESTABLISHED -j ACCEPT
  sudo iptables -C FORWARD -i "$OVS_HN" -o "$HN_UPLINK_IF" -j ACCEPT 2>/dev/null || \
    sudo iptables -A FORWARD -i "$OVS_HN" -o "$HN_UPLINK_IF" -j ACCEPT
fi

echo "[Fase2] Completado: VLANs 100/200/300, redes 192.168.10/20/30.0/24"
