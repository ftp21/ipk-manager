#!/bin/bash
# Costruisce un pacchetto .ipk a partire da una cartella con struttura opkg
# standard:
#
#   <package-dir>/
#     CONTROL/control      (obbligatorio: campi Package e Version richiesti)
#     CONTROL/postinst      (opzionali: script di manutenzione)
#     CONTROL/preinst
#     CONTROL/prerm
#     CONTROL/postrm
#     usr/...               (albero dei file da installare sul ricevitore,
#                             es. usr/lib/enigma2/python/Plugins/...)
#
# Tutto ciò che sta in <package-dir> tranne CONTROL/ viene incluso nel
# pacchetto con lo stesso percorso relativo.
#
# Uso: ./build-ipk.sh <package-dir> [output-dir]
#   - output-dir di default: ./dist
# Output: <output-dir>/<Package>_<Version>_<Architecture>.ipk
set -euo pipefail

usage() {
	echo "Uso: $0 <package-dir> [output-dir]" >&2
	exit 1
}

PKG_DIR="${1:-}"
[ -z "$PKG_DIR" ] && usage
[ -d "$PKG_DIR" ] || { echo "Errore: '$PKG_DIR' non è una cartella." >&2; exit 1; }

OUT_DIR="${2:-dist}"

CONTROL_SRC="$PKG_DIR/CONTROL"
CONTROL_FILE="$CONTROL_SRC/control"
[ -f "$CONTROL_FILE" ] || { echo "Errore: '$CONTROL_FILE' non trovato." >&2; exit 1; }

get_field() {
	# Estrae il valore di un campo "Campo: valore" dal control file.
	sed -n "s/^$1: *//p" "$CONTROL_FILE" | head -n1
}

PKG_NAME="$(get_field Package)"
VERSION="$(get_field Version)"
ARCH="$(get_field Architecture)"
[ -z "$PKG_NAME" ] && { echo "Errore: campo 'Package' mancante in $CONTROL_FILE." >&2; exit 1; }
[ -z "$VERSION" ] && { echo "Errore: campo 'Version' mancante in $CONTROL_FILE." >&2; exit 1; }
[ -z "$ARCH" ] && ARCH="all"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# --- data.tar.gz: tutto tranne CONTROL/ -----------------------------------
DATA_DIR="$WORKDIR/data"
mkdir -p "$DATA_DIR"
( cd "$PKG_DIR" && find . -mindepth 1 -maxdepth 1 ! -name CONTROL -exec cp -a {} "$DATA_DIR/" \; )

find "$DATA_DIR" -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$DATA_DIR" -name "*.pyc" -delete

INSTALLED_SIZE="$(du -sk "$DATA_DIR" | cut -f1)"

tar --numeric-owner --owner=0 --group=0 --sort=name --mtime="@0" \
	-czf "$WORKDIR/data.tar.gz" -C "$DATA_DIR" .

# --- control.tar.gz: control + script di manutenzione ---------------------
CONTROL_DIR="$WORKDIR/control"
mkdir -p "$CONTROL_DIR"
sed \
	-e "/^Installed-Size:/d" \
	-e "/^Description:/i Installed-Size: ${INSTALLED_SIZE}" \
	"$CONTROL_FILE" > "$CONTROL_DIR/control"

for maint in postinst preinst prerm postrm; do
	if [ -f "$CONTROL_SRC/$maint" ]; then
		cp -a "$CONTROL_SRC/$maint" "$CONTROL_DIR/$maint"
		chmod 755 "$CONTROL_DIR/$maint"
	fi
done

tar --numeric-owner --owner=0 --group=0 --sort=name --mtime="@0" \
	-czf "$WORKDIR/control.tar.gz" -C "$CONTROL_DIR" .

# --- debian-binary ----------------------------------------------------------
echo "2.0" > "$WORKDIR/debian-binary"

# --- assemblaggio ipk (= ar di debian-binary + control.tar.gz + data.tar.gz)
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/${PKG_NAME}_${VERSION}_${ARCH}.ipk"
rm -f "$OUT"
ar -rcD "$OUT" \
	"$WORKDIR/debian-binary" "$WORKDIR/control.tar.gz" "$WORKDIR/data.tar.gz"

echo "Creato $OUT (${INSTALLED_SIZE} KB installati)"
