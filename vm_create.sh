#!/usr/bin/env bash
# se trabaja en root y por eso la ubicacion de disco se cambia
# Uso: ./vm_create.sh <NombreVM> <NombreOVS> <VLAN_ID> <PuertoVNC>

VM_NAME=$1
OVS_NAME=$2
VLAN_ID=$3
VNC_PORT=$4

if [ -z "$VM_NAME" ] || [ -z "$OVS_NAME" ] || [ -z "$VLAN_ID" ] || [ -z "$VNC_PORT" ]; then
  echo "Uso: $0 <NombreVM> <NombreOVS> <VLAN_ID> <PuertoVNC>"
  exit 1
fi

TAP_IF="${VM_NAME}-tap"
MAC=$(printf '52:54:%02x:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

# Ruta a la imagen
IMG="/home/ubuntu/cirros-0.5.1-x86_64-disk.img"

# Crear interfaz TAP (si no existe)
ip link show "$TAP_IF" &>/dev/null || ip tuntap add mode tap name "$TAP_IF"
ip link set "$TAP_IF" up

# Conectar TAP al OVS con VLAN (idempotente)
ovs-vsctl --may-exist add-port "$OVS_NAME" "$TAP_IF" tag="$VLAN_ID"

# Usar KVM sólo si /dev/kvm existe
KVM_FLAG=""
if [ -e /dev/kvm ]; then
  KVM_FLAG="-enable-kvm"
fi

# Lanzar VM (sin snapshots innecesarios)
qemu-system-x86_64 \
  $KVM_FLAG \
  -name "$VM_NAME" \
  -vnc 0.0.0.0:"$VNC_PORT" \
  -netdev tap,id=net0,ifname="$TAP_IF",script=no,downscript=no \
  -device e1000,netdev=net0,mac="$MAC" \
  -daemonize \
  -snapshot \
  "$IMG"

echo "VM $VM_NAME creada en $OVS_NAME con VLAN $VLAN_ID (VNC :$VNC_PORT)"

