#!/usr/bin/env bash
# comando: ./init_worker.sh <nombreOvS> <interfaz1> <interfaz2> ...

OVS_NAME=$1
shift
INTERFACES=$@

if [ -z "$OVS_NAME" ] || [ -z "$INTERFACES" ]; then
  echo "Uso: $0 <nombreOvS> <interfaz1> [<interfaz2> ...]"
  exit 1
fi

# Creamos el OVS
ovs-vsctl br-exists $OVS_NAME 2>/dev/null
if [ $? -ne 0 ]; then
  echo "[i] Creando bridge $OVS_NAME ..."
  ovs-vsctl add-br $OVS_NAME
fi

# Agregamos interfaces al OVS
for IFACE in $INTERFACES; do
  echo "[i] Conectando $IFACE a $OVS_NAME ..."
  ip link set $IFACE down
  ovs-vsctl --may-exist add-port $OVS_NAME $IFACE
  ip link set $IFACE up
done

echo "Worker inicializado con $OVS_NAME"
