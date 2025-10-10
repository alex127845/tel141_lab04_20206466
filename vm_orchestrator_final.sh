#!/usr/bin/env bash
# vm_orchestrator_final.sh
# Ejecuta Fase 1 (tus VMs/OVS en workers y OFS) y luego Fase 2 (red con DHCP/NAT)

set -euo pipefail

echo "[FINAL] Desplegando Fase 1..."
bash ~/vm_orchestrator_fase1.sh   # usa tu script existente (IPs/puertos ya definidos)

echo "[FINAL] Desplegando Fase 2..."
bash ~/vm_orchestrator_fase2.sh   # usa el nuevo script de Fase 2

echo "[FINAL] Orquestador completo (Fase 1 + Fase 2) desplegado."
