# enigma2-ipk-tools

Due script bash indipendenti per creare pacchetti `.ipk` per enigma2 e, se
serve, un repository opkg da distribuire.

## build-ipk.sh — crea un .ipk da una cartella

```
./build-ipk.sh <package-dir> [output-dir]
```

`<package-dir>` deve avere questa struttura (formato standard opkg/ipkg):

```
package-dir/
  CONTROL/
    control       # obbligatorio: richiede almeno Package e Version
    postinst      # opzionali: script di manutenzione
    preinst
    prerm
    postrm
  usr/...          # albero dei file da installare, es.
                    # usr/lib/enigma2/python/Plugins/Extensions/NomePlugin/...
```

Tutto ciò che sta in `package-dir` tranne `CONTROL/` finisce nel pacchetto
con lo stesso percorso relativo. `Architecture` è opzionale (default `all`).

Output: `<output-dir>/<Package>_<Version>_<Architecture>.ipk` (default
`output-dir` = `./dist`).

Vedi `example-package/` per un esempio minimo funzionante:

```
./build-ipk.sh example-package
```

## make-index.sh — crea l'indice di un repository

```
./make-index.sh <ipk-dir>
```

Scansiona tutti i file `.ipk` in `<ipk-dir>` e genera `Packages` e
`Packages.gz` nella stessa cartella, nel formato che opkg si aspetta da un
feed. Basta poi pubblicare quella cartella (es. GitHub Pages, un web server,
una release) e aggiungerla come sorgente opkg sul ricevitore:

```
# /etc/opkg/example-feed.conf
src/gz example-feed https://.../ipk-dir
```

## Requisiti

`bash`, `tar`, `ar`, `gzip`, `md5sum`, `sha256sum` — tutti presenti di
default su una distro Linux.
