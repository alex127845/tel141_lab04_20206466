#!/usr/bin/env bash
# Uso: ./init_ofs.sh <NombreOVS> <interfaz1> <interfaz2> ...

OVS_NAME=$1
shift
INTERFACES=$@

if [ -z "$OVS_NAME" ] || [ -z "$INTERFACES" ]; then
  echo "Uso: $0 <NombreOVS> <interfaz1> <interfaz2> ..."
  exit 1
fi

# Crear OVS si no existe
ovs-vsctl br-exists $OVS_NAME 2>/dev/null
if [ $? -ne 0 ]; then
  echo "[i] Creando bridge $OVS_NAME ..."
  ovs-vsctl add-br $OVS_NAME
fi

# Limpiar IPs y agregar interfaces como puertos troncales
for IFACE in $INTERFACES; do
  echo "[i] Conectando $IFACE a $OVS_NAME como trunk ..."
  ip addr flush dev $IFACE
  ip link set $IFACE up
  ovs-vsctl --may-exist add-port $OVS_NAME $IFACE trunks=1-4094
done

echo "OFS $OVS_NAME inicializado con puertos troncales"
