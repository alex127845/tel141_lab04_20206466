#!/usr/bin/env bash
#script orquestador fase 1, ejecutar como "bash vm_orquestador_fase1.sh"
set -euo pipefail

PASS="adrian123"
SSHP="sshpass -p $PASS ssh -tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# IPs de management (ens3)
S1=10.0.10.1
S2=10.0.10.2
S3=10.0.10.3
OFS=10.0.10.5

echo "[1] Inicializando Workers..."
$SSHP ubuntu@$S1 "echo $PASS | sudo -S bash ~/init_worker.sh br-int ens4"
$SSHP ubuntu@$S2 "echo $PASS | sudo -S bash ~/init_worker.sh br-int ens4"
$SSHP ubuntu@$S3 "echo $PASS | sudo -S bash ~/init_worker.sh br-int ens4"

echo "[2] Inicializando OFS..."
# Usa el bridge del host OFS
$SSHP ubuntu@$OFS "echo $PASS | sudo -S bash ~/init_ofs.sh OFS ens5 ens6 ens7 ens8"

echo "[3] Creando VMs..."
# Worker 1
$SSHP ubuntu@$S1 "echo $PASS | sudo -S bash ~/vm_create.sh vm1 br-int 100 1"
$SSHP ubuntu@$S1 "echo $PASS | sudo -S bash ~/vm_create.sh vm2 br-int 200 2"
$SSHP ubuntu@$S1 "echo $PASS | sudo -S bash ~/vm_create.sh vm3 br-int 300 3"
# Worker 2
$SSHP ubuntu@$S2 "echo $PASS | sudo -S bash ~/vm_create.sh vm1 br-int 100 4"
$SSHP ubuntu@$S2 "echo $PASS | sudo -S bash ~/vm_create.sh vm2 br-int 200 5"
$SSHP ubuntu@$S2 "echo $PASS | sudo -S bash ~/vm_create.sh vm3 br-int 300 6"
# Worker 3
$SSHP ubuntu@$S3 "echo $PASS | sudo -S bash ~/vm_create.sh vm1 br-int 100 7"
$SSHP ubuntu@$S3 "echo $PASS | sudo -S bash ~/vm_create.sh vm2 br-int 200 8"
$SSHP ubuntu@$S3 "echo $PASS | sudo -S bash ~/vm_create.sh vm3 br-int 300 9"

echo "Orquestador Fase 1 desplegado"
