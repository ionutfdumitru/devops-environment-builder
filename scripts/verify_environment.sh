#!/usr/bin/env bash

set -u

VARIABLES_FILE="${1:-generated/generated_vars.json}"

if [[ ! -f "$VARIABLES_FILE" ]]; then
    echo "[ERROR] Fisierul de variabile nu exista: $VARIABLES_FILE"
    exit 2
fi

failures=0

echo "Verific tehnologiile din: $VARIABLES_FILE"


# #!/usr/bin/env bash selecteaza Bash drept interpretor
# set -u trateaza folosirea unei variabile nedefinite ca eroare
# ${1:-...} foloseste primul argument sau calea implicita
# -f verifica daca fisierul exista
# failures va numara verificarile esuate

#=========================================================================



#1. Bucata Python citeste JSON-ul generat
#2. Pentru fiecare tehnologie trimite patru valori separate prin tab
#3. Bucla Bash primeste valorile in variabilele name, expected_version, command si version_argument
#4. command -v verifica daca executabilul exista
#5. Comanda de versiune este rulata, iar rezultatul este comparat cu versiunea ceruta
#6. Pentru latest verificam doar ca tehnologia exista si comanda raspunde




while IFS=$'\t' read -r name expected_version command version_argument; do
    echo
    echo "Verific: $name"

    if ! command -v "$command" >/dev/null 2>&1; then
        echo "[ERROR] Comanda nu a fost gasita: $command"
        failures=$((failures + 1))
        continue
    fi

    output=$("$command" "$version_argument" 2>&1)
    command_status=$?

    if [[ $command_status -ne 0 ]]; then
        echo "[ERROR] Comanda pentru $name a returnat o eroare."
        failures=$((failures + 1))
        continue
    fi

    if [[ "$expected_version" != "latest" &&
          "$output" != *"$expected_version"* ]]; then
        echo "[ERROR] $name nu are versiunea asteptata: $expected_version"
        echo "        Rezultat primit: $output"
        failures=$((failures + 1))
        continue
    fi

    echo "[OK] $name este instalat si raspunde corect."
    echo "     $output"

done < <(
    python3 - "$VARIABLES_FILE" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    data = json.load(file)

for technology in data["requested_technologies"]:
    print(
        "\t".join(
            [
                technology["name"],
                technology["version"],
                technology["command"],
                technology["version_argument"],
            ]
        )
    )
PYTHON
)


#==============================================================

# Acest bloc transforma rezultatele individuale intr-un rezultat final:
# daca exista cel putin o problema, scriptul returneaza 1;
# daca toate verificarile trec, returneaza 0.


echo

if [[ $failures -gt 0 ]]; then
    echo "[ERROR] Verificarea s-a terminat cu $failures problema/probleme."
    exit 1
fi

echo "[OK] Toate tehnologiile cerute sunt instalate si functionale."
exit 0