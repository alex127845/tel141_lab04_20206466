#!/usr/bin/env bash
# Comando: sudo bash init_headnode.sh <NombreOVS> <interfaz1> [<interfaz2> ...] [UPLINK_IF]

set -euo pipefail

OVS_NAME=${1:-}
shift || true
UPLINK_IF=${@: -1}             
ARGS=("$@")
# Si el último argumento existe como interfaz del sistema => lo tratamos como uplink
if [[ -n "${UPLINK_IF:-}" && -d "/sys/class/net/${UPLINK_IF}" ]]; then
  INTERFACES=("${ARGS[@]:0:${#ARGS[@]}-1}")
else
  INTERFACES=("${ARGS[@]}")
  UPLINK_IF=""
fi

if [[ -z "$OVS_NAME" || ${#INTERFACES[@]} -eq 0 ]]; then
  echo "Uso: $0 <NombreOVS> <interfaz1> [<interfaz2> ...] [UPLINK_IF]"
  exit 1
fi

# Crear OVS si no existe
if ! ovs-vsctl br-exists "$OVS_NAME" 2>/dev/null; then
  echo "[HeadNode] Creando bridge $OVS_NAME ..."
  ovs-vsctl add-br "$OVS_NAME"
fi

# Conectar interfaces de data al OVS como trunk
for IFACE in "${INTERFACES[@]}"; do
  echo "[HeadNode] Conectando $IFACE a $OVS_NAME como trunk ..."
  ip addr flush dev "$IFACE" || true
  ip link set "$IFACE" up
  ovs-vsctl --may-exist add-port "$OVS_NAME" "$IFACE" trunks=1-4094
done

# Habilitar IP forwarding (por si hacemos NAT o actuamos como GW)
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# (Opcional) marcar UPLINK para NAT si se decide hacer NAT en HeadNode
if [[ -n "$UPLINK_IF" ]]; then
  echo "[HeadNode] Uplink para NAT detectado: $UPLINK_IF (AÚN NO se crean reglas aquí)"
fi

echo "[HeadNode] Inicialización completa para $OVS_NAME"
