#!/usr/bin/env bash
# modules/ssh.sh - Configuración de OpenSSH + seguridad + banner HTML

GREEN="\e[32m"
RESET="\e[0m"

echo -e "${GREEN}>>> Instalando y configurando OpenSSH...${RESET}"

# -------------------------------
# 1. Instalar SSH si no existe
# -------------------------------
apt update -y >/dev/null 2>&1
apt install -y openssh-server fail2ban >/dev/null 2>&1

systemctl enable ssh
systemctl start ssh

# -------------------------------
# 2. Crear banner personalizado
# -------------------------------
BANNER_PATH="/etc/ssh/banner.html"

cat > "$BANNER_PATH" << 'EOF'
<div style="color:#00ff00; font-family: monospace; text-align:center; padding:8px;">
  <span style="font-size: 26px; font-weight: bold;">
    S C R I P T   D E A L E R
  </span>
</div>
EOF

chmod 644 "$BANNER_PATH"

# -------------------------------
# 3. Configurar SSH
# -------------------------------
SSHD_CONFIG="/etc/ssh/sshd_config"

# Remover configuraciones duplicadas
sed -i '/^Banner/d' "$SSHD_CONFIG"
sed -i '/^MaxAuthTries/d' "$SSHD_CONFIG"
sed -i '/^PermitRootLogin/d' "$SSHD_CONFIG"

# Insertar configuraciones
echo "Banner $BANNER_PATH" >> "$SSHD_CONFIG"
echo "MaxAuthTries 3" >> "$SSHD_CONFIG"
echo "PermitRootLogin yes" >> "$SSHD_CONFIG"

# Puerto por defecto
if ! grep -q "^Port 22" "$SSHD_CONFIG"; then
  echo "Port 22" >> "$SSHD_CONFIG"
fi

systemctl restart ssh

# -------------------------------
# 4. Configurar Fail2Ban
# -------------------------------
echo -e "${GREEN}>>> Configurando Fail2Ban...${RESET}"

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 10m
findtime = 10m
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl restart fail2ban

# -------------------------------
# 5. Finalización
# -------------------------------
echo -e "${GREEN}SSH configurado correctamente.${RESET}"
echo -e "${GREEN}Banner activado: $BANNER_PATH${RESET}"
echo -e "${GREEN}Fail2Ban activo y protegiendo SSH.${RESET}"
