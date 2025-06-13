#!/bin/bash

set -e

CONFIG_FILE="$HOME/.ssh/ssh-manager-servers.txt"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PUB_KEY="$SSH_KEY.pub"

# Colores para UI
RED='\033[0;31m'
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

function generar_clave_ssh() {
    if [ ! -f "$SSH_KEY" ]; then
        echo -e "${YELLOW}🔐 No se encontró clave SSH ed25519, creando una nueva...${NC}"
        ssh-keygen -t ed25519 -C "$USER@$(hostname)" -f "$SSH_KEY"
    else
        echo -e "${GREEN}✅ Clave SSH ya existe en $SSH_KEY${NC}"
    fi

    # Agregar al agente
    eval "$(ssh-agent -s)"
    ssh-add "$SSH_KEY"
}

function comprobar_o_generar_clave() {
    if [ ! -f "$SSH_KEY" ]; then
        echo -e "${YELLOW}🔐 No se encontró clave SSH. Generándola primero...${NC}"
        generar_clave_ssh
    fi
}

function verificar_clave_en_servidor() {
    listar_servidores
    echo ""
    read -p "🔍 Selecciona el número del servidor a verificar: " NUM
    SERVER=$(sed "${NUM}q;d" "$CONFIG_FILE")
    if [ -z "$SERVER" ]; then
        echo "${RED}Entrada no válida.${NC}"
        return
    fi

    echo -e "${YELLOW}🔎 Verificando existencia de la clave pública local en $SERVER...${NC}"

    PUB_KEY_CONTENT=$(cat "$SSH_PUB_KEY")

    # Comprobar si la clave está en el archivo authorized_keys
    RESULT=$(ssh "$SERVER" "grep -Fxq '$PUB_KEY_CONTENT' ~/.ssh/authorized_keys && echo 'FOUND' || echo 'NOT_FOUND'")

    if [[ "$RESULT" == "FOUND" ]]; then
        echo -e "${GREEN}✅ La clave pública está instalada en el servidor.${NC}"
    else
        echo -e "${YELLOW}⚠️ La clave pública NO está en el servidor.${NC}"
    fi
}

function agregar_servidor() {
    comprobar_o_generar_clave

    read -p "👤 Usuario del servidor (ej: root): " USUARIO
    read -p "🌍 Dirección IP o hostname: " HOST

    FULL="$USUARIO@$HOST"

    if grep -Fxq "$FULL" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠️ El servidor ya está en la lista. No se agregará de nuevo.${NC}"
    else
        echo "$FULL" >> "$CONFIG_FILE"
        echo -e "${GREEN}📦 Servidor guardado: $FULL${NC}"
    fi

    echo "📤 Copiando clave pública al servidor..."
    ssh-copy-id "$FULL"

    echo -e "${GREEN}🔗 Verificando conexión SSH...${NC}"
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$FULL" 'echo "🎉 Conexión exitosa sin contraseña"'
}

function eliminar_servidor() {
    listar_servidores
    echo ""
    read -p "Ingresa el número del servidor a eliminar: " NUM
    if [ -z "$NUM" ]; then
        echo -e "${RED}Entrada no válida.${NC}"
        return
    fi
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}No hay servidores registrados.${NC}"
        return
    fi

    SERVER=$(sed "${NUM}q;d" "$CONFIG_FILE")
    if [ -z "$SERVER" ]; then
        echo -e "${RED}Número inválido.${NC}"
        return
    fi

    read -p "¿Quieres también revocar la clave pública en $SERVER? (s/n): " RESPUESTA
    if [[ "$RESPUESTA" =~ ^[sS]$ ]]; then
        revocar_acceso_por_servidor "$SERVER"
    fi

    echo -e "${YELLOW}⚠️ Eliminando $SERVER de la lista...${NC}"
    sed -i "${NUM}d" "$CONFIG_FILE"
    echo -e "${GREEN}✅ Eliminado.${NC}"
}

function listar_servidores() {
    echo -e "${YELLOW}Lista de servidores registrados:${NC}"
    if [ -f "$CONFIG_FILE" ]; then
        nl "$CONFIG_FILE"
    else
        echo "(Ningún servidor registrado aún)"
    fi
}

function conectar_a_servidor() {
    listar_servidores
    echo ""
    read -p "Selecciona el número del servidor: " NUM
    SERVER=$(sed "${NUM}q;d" "$CONFIG_FILE")
    if [ -z "$SERVER" ]; then
        echo -e "${RED}Entrada no válida.${NC}"
    else
        echo -e "${GREEN}Conectando a $SERVER...${NC}"
        ssh "$SERVER"
    fi
}

function revocar_acceso() {
    listar_servidores
    echo ""
    read -p "Selecciona el número del servidor del que deseas revocar tu acceso: " NUM
    SERVER=$(sed "${NUM}q;d" "$CONFIG_FILE")
    if [ -z "$SERVER" ]; then
        echo -e "${RED}Entrada no válida.${NC}"
        return
    fi

    echo -e "${YELLOW}🚫 Revocando clave pública en $SERVER...${NC}"

    PUB_KEY_CONTENT=$(cat "$SSH_PUB_KEY")

    # Comando remoto seguro y tolerante a errores
    ssh "$SERVER" "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && grep -vF '$PUB_KEY_CONTENT' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys && echo 'Clave eliminada con éxito'" || {
        echo -e "${YELLOW}⚠️ No se pudo conectar o revocar la clave. ¿La clave ya estaba revocada?${NC}"
    }

    echo -e "${GREEN}✅ Revocación intentada. Si la clave existía, fue eliminada.${NC}"
}

function revocar_acceso_por_servidor() {
    local SERVER="$1"
    echo -e "${YELLOW}🚫 Revocando clave pública en $SERVER...${NC}"

    PUB_KEY_CONTENT=$(cat "$SSH_PUB_KEY")

    # Comando remoto seguro y tolerante a errores
    ssh "$SERVER" "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && grep -vF '$PUB_KEY_CONTENT' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys && echo 'Clave eliminada con éxito'" || {
        echo -e "${YELLOW}⚠️ No se pudo conectar o revocar la clave. ¿La clave ya estaba revocada?${NC}"
    }

    echo -e "${GREEN}✅ Revocación intentada. Si la clave existía, fue eliminada.${NC}"
}

function agregar_clave_servidor() {
    listar_servidores
    echo ""
    read -p "Selecciona el número del servidor donde quieres agregar la clave pública: " NUM
    SERVER=$(sed "${NUM}q;d" "$CONFIG_FILE")
    if [ -z "$SERVER" ]; then
        echo -e "${RED}Entrada no válida.${NC}"
        return
    fi

    if [ ! -f "$SSH_PUB_KEY" ]; then
        echo -e "${RED}No se encontró la clave pública local en $SSH_PUB_KEY. Genera una con ssh-keygen primero."
        return
    fi

    echo -e "${YELLOW}Copiando clave pública a $SERVER...${NC}"

    ssh-copy-id -i "$SSH_PUB_KEY" "$SERVER"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Clave pública agregada correctamente a $SERVER.${NC}"
    else
        echo -e "${RED}❌ Falló la copia de la clave pública a $SERVER.${NC}"
    fi
}

function menu() {
    clear
    echo -e "${YELLOW}SSH Manager - Configuración de acceso sin contraseña${NC}"
    echo ""
    echo "1. Generar clave SSH"
    echo "2. Agregar nuevo servidor"
    echo "3. Listar servidores"
    echo "4. Conectar a un servidor"
    echo "5. Revocar acceso (eliminar clave del servidor)"
    echo "6. Agregar clave pública a servidor existente"
    echo "7. Eliminar servidor de la lista"
    echo "8. Verificar clave en servidor"
    echo "9. Salir"
    echo ""

    read -p "Elige una opción: " OPCION
    case $OPCION in
        1) generar_clave_ssh ;;
        2) agregar_servidor ;;
        3) listar_servidores ;;
        4) conectar_a_servidor ;;
        5) revocar_acceso ;;
        6) agregar_clave_servidor ;;
        7) eliminar_servidor ;;
        8) verificar_clave_en_servidor ;;
        9) echo "Adiós..."; exit 0 ;;
        *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
    esac
}

# Bucle principal
while true; do
    menu
    echo ""
    read -p "Pulsa INTRO para continuar..." dummy
done
