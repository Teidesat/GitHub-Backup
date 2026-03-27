#!/bin/bash
set -euo pipefail

# Configuración de colores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Directorio de salida
BACKUP_DIR="$HOME/Desktop/github-backup"
ORG="Teidesat" 

mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

echo -e "${BLUE}Recuperando lista de repositorios de ${YELLOW}$ORG${NC}..."

# Obtener nombres de repos sin dependencias externas
REPOS=$(gh repo list "$ORG" --limit 1000 | cut -f1 | cut -d'/' -f2)

if [ -z "$REPOS" ]; then
    echo -e "${RED}Error: No se han encontrado repos. Revisa el login de gh.${NC}"
    exit 1
fi

for REPO in $REPOS; do
    echo -e "\n${YELLOW}>>> Backup de:${NC} $REPO"
    DATE=$(date +%Y-%m-%d)
    
    # Clonar o actualizar
    if [[ ! -d "$REPO" ]]; then
        gh repo clone "$ORG/$REPO" "$REPO" -- --quiet
    else
        (cd "$REPO" && git pull --quiet)
    fi

    # Comprimir y limpiar
    FILE="${REPO}_${DATE}.tar.gz"
    echo -e "${BLUE}Comprimiendo...${NC}"
    
    if tar -czf "$FILE" "$REPO"; then
        rm -rf "$REPO"
        echo -e "${GREEN}OK: $FILE generado.${NC}"
    else
        echo -e "${RED}Error comprimiendo $REPO${NC}"
    fi
done

echo -e "\n${GREEN}Finalizado. Backups guardados en $BACKUP_DIR${NC}"