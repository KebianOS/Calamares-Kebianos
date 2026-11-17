#!/bin/bash
# Actualiza el sistema recién instalado dentro del chroot de Calamares.
# NUNCA debe romper la instalación: ante cualquier fallo sale con 0.

ROOT="$1"

if [ -z "$ROOT" ] || [ ! -d "$ROOT/etc/apt" ]; then
    echo "update-system: ROOT inválido ('$ROOT'), omitiendo"
    exit 0
fi

# Sin internet no hay nada que actualizar
if ! getent hosts deb.debian.org >/dev/null 2>&1; then
    echo "update-system: sin conexión, omitiendo actualización"
    exit 0
fi

RESOLV="$ROOT/etc/resolv.conf"
RESOLV_BAK="$ROOT/etc/resolv.conf.kebian-bak"
POLICY="$ROOT/usr/sbin/policy-rc.d"
HAD_RESOLV=0
MADE_POLICY=0

cleanup() {
    [ "$MADE_POLICY" = 1 ] && rm -f "$POLICY"
    rm -f "$RESOLV"
    if [ "$HAD_RESOLV" = 1 ]; then
        mv -f "$RESOLV_BAK" "$RESOLV"
    fi
}
trap cleanup EXIT

# DNS dentro del chroot (resolv.conf del target puede ser symlink roto)
if [ -e "$RESOLV" ] || [ -L "$RESOLV" ]; then
    mv -f "$RESOLV" "$RESOLV_BAK" && HAD_RESOLV=1
fi
cp -L /etc/resolv.conf "$RESOLV" 2>/dev/null

# Evitar que apt intente arrancar/reiniciar servicios dentro del chroot
if [ ! -e "$POLICY" ]; then
    printf '#!/bin/sh\nexit 101\n' > "$POLICY"
    chmod +x "$POLICY"
    MADE_POLICY=1
fi

export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

echo "update-system: apt-get update"
if ! chroot "$ROOT" apt-get update; then
    echo "update-system: apt-get update falló, omitiendo"
    exit 0
fi

echo "update-system: apt-get dist-upgrade"
chroot "$ROOT" apt-get "${APT_OPTS[@]}" dist-upgrade \
    || echo "update-system: dist-upgrade terminó con errores (la instalación continúa)"

chroot "$ROOT" apt-get clean

exit 0
