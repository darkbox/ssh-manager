#!/bin/bash

# Ruta de instalación local
TARGET="$HOME/.local/bin/ssh-manager"

mkdir -p "$(dirname "$TARGET")"

# Descargar el script principal
wget -qO "$TARGET" https://raw.githubusercontent.com/darkbox/ssh-manager/refs/heads/main/ssh-manager.sh

chmod +x "$TARGET"

# Agregar al PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "🔁 PATH actualizado. Reinicia el terminal o ejecuta 'source ~/.bashrc'."
fi

echo "✅ Instalación completada. Puedes usar 'ssh-manager' desde cualquier lugar."
