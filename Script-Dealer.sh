#!/usr/bin/env bash
# Script-Dealer.sh - Instalador principal (esqueleto)
# Soporta: Ubuntu 16.04+ y Debian
# Interfaz: estilo "Matrix / Hacker" (verde sobre negro)
# Nota: este es el scaffold inicial. Cada módulo debe implementarse en ./modules/*.sh

# Ruta del repo (asume que el script se ejecuta desde su carpeta)
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="$BASE_DIR/modules"
UTILS_DIR="$BASE_DIR/utils"

# Colors (verde sobre negro)
GREEN="\e[32m"
BOLD="\e[1m"
RESET="\e[0m"

# ASCII header - Estilo Matrix / Hacker
print_header(){
  clear
  echo -e "${GREEN}${BOLD}█▀\t█▀▀\t█▀█\t█\t█▀▀\t▀█▀\t▄▀█\t█░░\n▄█\t██▄\t█▀▄\t█\t██▄\t░█░\t█▀█\t█▄▄${RESET}\n"
}

# Simple helper to require root
require_root(){
  if [ "$EUID" -ne 0 ]; then
    echo -e "${GREEN}Por favor ejecuta como root: sudo ./Script-Dealer.sh${RESET}"
    exit 1
  fi
}

# Check distro and architecture
check_distro(){
  . /etc/os-release 2>/dev/null
  DISTRO_ID=${ID,,}
  DISTRO_VER=${VERSION_ID}
  echo "Detectado: $PRETTY_NAME"
}

# Ask for key and validate via HTTP
validate_key(){
  read -p "Ingresa tu key: " KEY_INPUT
  echo -e "\nValidando key con https://keys.script-dealer.com/validate?key=${KEY_INPUT} ..."

  RESPONSE=$(curl -s -m 10 "https://keys.script-dealer.com/validate?key=${KEY_INPUT}")
  if [ -z "$RESPONSE" ]; then
    echo "Error: no hubo respuesta del servidor de licencias"
    return 2
  fi

  VALID=$(echo "$RESPONSE" | grep -o '"valid":true' || true)
  if [ -n "$VALID" ]; then
    echo -e "Key válida. Procediendo con la instalación..."
    # opcional: guardar key localmente por la sesión
    echo "$KEY_INPUT" > /etc/script-dealer.key
    return 0
  else
    REASON=$(echo "$RESPONSE" | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')
    echo "Key inválida: ${REASON:-unknown}"
    return 1
  fi
}

# Simple menu (hacker style)
main_menu(){
  while true; do
    print_header
    echo -e "${GREEN}Selección:\n${RESET}"
    echo "1) Instalar todos los servicios (modo rápido)"
    echo "2) Instalar módulos selectivos"
    echo "3) Reparar servicios (autorreparación)"
    echo "4) Ver estado de los servicios"
    echo "5) Salir"

    read -p "Elige una opción: " opt
    case "$opt" in
      1)
        install_all
        ;;
      2)
        install_selective
        ;;
      3)
        repair_services
        ;;
      4)
        status_services
        ;;
      5)
        echo "Saliendo..."
        exit 0
        ;;
      *)
        echo "Opción inválida"
        ;;
    esac
    read -p "Presiona ENTER para continuar..." foo
  done
}

# Stub: instalar todo
install_all(){
  echo "==> Instalar: SSH, NGINX, V2Ray, Python Proxy, WS, SlowDNS, BadVPN, Hysteria, ZIVPN, PSIPHON, SSL, Firewall"
  # Ejemplo de ejecución de módulos (cada módulo debe existir en modules/)
  bash "$MODULES_DIR/check_distro.sh" || true
  bash "$MODULES_DIR/ssh.sh"
  bash "$MODULES_DIR/nginx.sh"
  bash "$MODULES_DIR/v2ray.sh"
  bash "$MODULES_DIR/python_proxy.sh"
  bash "$MODULES_DIR/websocket.sh"
  bash "$MODULES_DIR/slodns.sh" 2>/dev/null || true
  bash "$MODULES_DIR/badvpn.sh"
  bash "$MODULES_DIR/hysteria.sh"
  bash "$MODULES_DIR/zivpn.sh"
  bash "$MODULES_DIR/psiphon.sh"
  bash "$MODULES_DIR/firewall.sh"
  echo "Instalación completa (si no hubo errores)."
}

install_selective(){
  echo "Función de instalación selectiva (pendiente)"
}

repair_services(){
  bash "$MODULES_DIR/repair.sh"
}

status_services(){
  echo "Estado del sistema: (stub)"
  systemctl status nginx || true
  systemctl status v2ray || true
}

# Entrypoint
require_root
check_distro

# Pedir key antes de mostrar menú
ATTEMPTS=0
while [ $ATTEMPTS -lt 3 ]; do
  validate_key
  RET=$?
  if [ $RET -eq 0 ]; then
    main_menu
    break
  fi
  ATTEMPTS=$((ATTEMPTS+1))
  echo "Intentos: $ATTEMPTS/3"
done

if [ $ATTEMPTS -ge 3 ]; then
  echo "Demasiados intentos fallidos. Saliendo."
  exit 1
fi
