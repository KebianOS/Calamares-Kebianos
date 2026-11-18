#!/bin/bash
# Ajusta las opciones de cada entrada btrfs del fstab según SU disco:
#   HDD (rotacional) -> autodefrag
#   SSD/NVMe         -> ssd,discard=async
ROOT="$1"
FSTAB="$ROOT/etc/fstab"
[ -f "$FSTAB" ] || exit 0

# Devuelve 0 si algún nivel (partición, cifrado, disco) es rotacional
is_rotational() {
    lsblk -rsno ROTA "$1" 2>/dev/null | grep -qx '1'
}

# Agrega cada opción de una lista (separada por comas) si no está ya presente
add_opts() {
    local opts="$1" new="$2" o key
    for o in ${new//,/ }; do
        key="${o%%=*}"
        if ! [[ ",$opts," == *",$key,"* || ",$opts," == *",$key="* ]]; then
            opts="$opts,$o"
        fi
    done
    echo "$opts"
}

TMP=$(mktemp)

while IFS= read -r line || [ -n "$line" ]; do
    # Comentarios, líneas vacías y entradas que no son btrfs: se copian igual
    if [[ "$line" =~ ^[[:space:]]*# ]] || ! [[ "$line" =~ [[:space:]]btrfs[[:space:]] ]]; then
        echo "$line" >> "$TMP"
        continue
    fi

    read -r SRC MNT FS OPTS DUMP PASS <<< "$line"

    # Resolver el dispositivo (UUID=, LABEL=, PARTUUID= o ruta /dev/...)
    if [[ "$SRC" == /dev/* ]]; then
        DEV="$SRC"
    else
        DEV=$(findfs "$SRC" 2>/dev/null)
    fi

    # Si no se puede resolver, dejar la línea intacta
    if [ -z "$DEV" ]; then
        echo "$line" >> "$TMP"
        echo "No se pudo resolver $SRC ($MNT): sin cambios"
        continue
    fi

    if is_rotational "$DEV"; then
        NEWOPTS=$(add_opts "$OPTS" "autodefrag")
        echo "$MNT en $DEV: HDD -> autodefrag"
    else
        NEWOPTS=$(add_opts "$OPTS" "ssd,discard=async")
        echo "$MNT en $DEV: SSD/NVMe -> ssd,discard=async"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$SRC" "$MNT" "$FS" "$NEWOPTS" "${DUMP:-0}" "${PASS:-0}" >> "$TMP"
done < "$FSTAB"

cat "$TMP" > "$FSTAB"
rm -f "$TMP"
exit 0
