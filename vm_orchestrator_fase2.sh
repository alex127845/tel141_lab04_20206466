#!/usr/bin/env bash
# vm_orchestrator_fase2.sh
# Orquesta Fase 2: HeadNode OVS, namespaces por VLAN con DHCP/GW, y NAT (HeadNode u OFS)

set -euo pipefail

PASS="adrian123"
SSHP="sshpass -p $PASS ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# IPs de management
HEAD=10.0.10.4
OFS=10.0.10.5

# Parámetros base
OVS_HN="br-int"
HN_DATA_IF="ens4"            # troncal HeadNode↔OFS
HN_UPLINK_IF="ens3"          # NAT en HeadNode por ens3

# VLANs a desplegar
VLANS=("100" "200" "300")

# Plantillas por VLAN (ajustadas):
# VLAN 100 -> 192.168.10.0/24 (GW 192.168.10.1, DHCP 192.168.10.50-200)
# VLAN 200 -> 192.168.20.0/24 (GW 192.168.20.1, DHCP 192.168.20.50-200)
# VLAN 300 -> 192.168.30.0/24 (GW 192.168.30.1, DHCP 192.168.30.50-200)

echo "[Fase2] Inicializando HeadNode..."
$SSHP ubuntu@$HEAD "echo $PASS | sudo -S bash ~/init_headnode.sh $OVS_HN $HN_DATA_IF ${HN_UPLINK_IF:-}"

echo "[Fase2] Creando namespaces + DHCP por VLAN en HeadNode..."

# --- BUCLE---
for VID in "${VLANS[@]}"; do
  case "$VID" in
    100) NET="192.168.10" ;;
    200) NET="192.168.20" ;;
    300) NET="192.168.30" ;;
    *) echo "[ERR] VLAN $VID sin mapeo de red"; exit 1 ;;
  esac

  CIDR="${NET}.0/24"
  GW="${NET}.1"
  DHCP_RANGE="${NET}.50,${NET}.200"

  # Mantén el tag VLAN original (100/200/300)
  $SSHP ubuntu@$HEAD "echo $PASS | sudo -S bash ~/ns_create.sh red${VID} $OVS_HN $VID \"$CIDR\" \"$DHCP_RANGE\" \"$GW\""
done


# Opción A: NAT en HeadNode (si definiste HN_UPLINK_IF)
if [[ -n "$HN_UPLINK_IF" ]]; then
  echo "[Fase2] Configurando NAT en HeadNode via $HN_UPLINK_IF ..."
  $SSHP ubuntu@$HEAD "echo $PASS | sudo -S sh -lc '
    sysctl -w net.ipv4.ip_forward=1 >/dev/null
    iptables -t nat -C POSTROUTING -o $HN_UPLINK_IF -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o $HN_UPLINK_IF -j MASQUERADE
    iptables -C FORWARD -i $HN_UPLINK_IF -o $OVS_HN -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -A FORWARD -i $HN_UPLINK_IF -o $OVS_HN -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -C FORWARD -i $OVS_HN -o $HN_UPLINK_IF -j ACCEPT 2>/dev/null || iptables -A FORWARD -i $OVS_HN -o $HN_UPLINK_IF -j ACCEPT
  '"
else
  # Opción B: NAT en OFS
  echo "[Fase2] Preparando NAT en OFS..."
  UPLINK_OFS="ens3"  # AJUSTA si no quieres tocar ens3 del OFS
  VLAN_CSV="100,200,300"
  $SSHP ubuntu@$OFS "echo $PASS | sudo -S bash ~/init_ofs.sh OFS ens5 ens6 ens7 ens8 --vlans $VLAN_CSV --gw-base 192.168. --uplink $UPLINK_OFS"
fi

echo "[Fase2] Red de Fase 2 arriba con VLANs 100/200/300 y rangos 192.168.10/20/30. NAT según opción elegida."
