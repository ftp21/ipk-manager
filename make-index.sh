#!/bin/bash
# Genera l'indice opkg (Packages / Packages.gz) per una cartella di file .ipk,
# così da poter usare quella cartella come repository opkg (feed) da
# aggiungere su un ricevitore enigma2.
#
# Uso: ./make-index.sh <ipk-dir>
# Output: <ipk-dir>/Packages e <ipk-dir>/Packages.gz
set -euo pipefail

IPK_DIR="${1:-}"
[ -z "$IPK_DIR" ] && { echo "Uso: $0 <ipk-dir>" >&2; exit 1; }
[ -d "$IPK_DIR" ] || { echo "Errore: '$IPK_DIR' non è una cartella." >&2; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PACKAGES_FILE="$IPK_DIR/Packages"
: > "$PACKAGES_FILE"

shopt -s nullglob
IPKS=("$IPK_DIR"/*.ipk)
shopt -u nullglob

if [ "${#IPKS[@]}" -eq 0 ]; then
	echo "Attenzione: nessun file .ipk trovato in '$IPK_DIR'." >&2
fi

for ipk in "${IPKS[@]}"; do
	NAME="$(basename "$ipk")"
	IPK_ABS="$(cd "$(dirname "$ipk")" && pwd)/$NAME"
	EXTRACT_DIR="$WORKDIR/$NAME"
	mkdir -p "$EXTRACT_DIR"
	( cd "$EXTRACT_DIR" && ar -x "$IPK_ABS" control.tar.gz )
	tar -xzf "$EXTRACT_DIR/control.tar.gz" -C "$EXTRACT_DIR" ./control

	SIZE="$(stat -c%s "$ipk")"
	MD5="$(md5sum "$ipk" | cut -d' ' -f1)"
	SHA256="$(sha256sum "$ipk" | cut -d' ' -f1)"

	{
		# control può non terminare con newline: normalizziamo.
		sed -e '$a\' "$EXTRACT_DIR/control"
		echo "Filename: $NAME"
		echo "Size: $SIZE"
		echo "MD5Sum: $MD5"
		echo "SHA256sum: $SHA256"
		echo
	} >> "$PACKAGES_FILE"
done

gzip -9 -k -f "$PACKAGES_FILE"

echo "Indice creato: $PACKAGES_FILE e $PACKAGES_FILE.gz (${#IPKS[@]} pacchetti)"
