import argparse #   argparse va citi caile primite din linia de comanda
import json #   json citeste configuratia
import sys #   sys ne va permite sa oprim programul cu un cod de eroare
from pathlib import Path #   Path lucreaza mai sigur cu fisierele

#=======================================================================s

#   "load_json" verifica daca fisierul exista si daca JSON-ul este valid.

def load_json(file_path):
    """Citeste un fisier JSON și returneaza conținutul sau."""
    path = Path(file_path)

    if not path.is_file():
        raise ValueError(f"Fisierul nu exista: {path}")

    try:
        with path.open(encoding="utf-8") as file:
            return json.load(file)
    except json.JSONDecodeError as error:
        raise ValueError(
            f"Fisierul {path} nu contine JSON valid: {error.msg}"
        ) from error





#   Functia "validate_config" NU se oprește la prima eroare. Ea aduna toate erorile, astfel incat userul sa poata corecta configuratia.

def validate_config(config, supported):
    """Valideaza structura configuratiei, tehnologiile si versiunile."""
    errors = []

    if not isinstance(config, dict):
        return ["Configuratia trebuie sa fie un obiect JSON."]

    technologies = config.get("technologies")

    if not isinstance(technologies, list) or not technologies:
        return ['Campul "technologies" trebuie sa fie o lista nevida.']

    seen_names = set()

    for index, technology in enumerate(technologies, start=1):
        if not isinstance(technology, dict):
            errors.append(
                f"Intrarea {index} trebuie sa fie un obiect cu name si version."
            )
            continue

        name = technology.get("name")
        version = technology.get("version")

        if not isinstance(name, str) or not name.strip():
            errors.append(f"Intrarea {index}: numele tehnologiei lipseste.")
            continue

        name = name.strip().lower()

        if name in seen_names:
            errors.append(f'Tehnologia "{name}" apare de mai multe ori.')
            continue

        seen_names.add(name)

        if name not in supported:
            errors.append(f'Tehnologia "{name}" nu este suportata.')
            continue

        if not isinstance(version, str) or not version.strip():
            errors.append(f'Tehnologia "{name}" nu are o versiune valida.')
            continue

        version = version.strip()
        valid_versions = supported[name]["valid_versions"]

        if version not in valid_versions:
            allowed = ", ".join(valid_versions)
            errors.append(
                f'Versiunea "{version}" nu este valida pentru "{name}". '
                f"Versiunea acceptata: {allowed}."
            )

    return errors





#  Adaugam functia "build_generated_variables" care transforma configuratia validata in fisierul de variabile folosit ulterior de Ansible si Bash.

def build_generated_variables(config, supported):
    """Construieste variabilele necesare instalarii si verificarii."""
    generated = {"requested_technologies": []}

    for technology in config["technologies"]:
        name = technology["name"].strip().lower()
        version = technology["version"].strip()
        details = supported[name]

        generated["requested_technologies"].append(
            {
                "name": name,
                "version": version,
                "package": details["package"],
                "command": details["command"],
                "version_argument": details["version_argument"]
            }
        )

    return generated


def save_json(data, output_path):
    """Salveaza datele intr-un fisier JSON formatat."""
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", encoding="utf-8") as file:
        json.dump(data, file, indent=2)
        file.write("\n")

#  "build_generated_variables" combina cererea utilizatorului cu informatiile din supported_technologies.json.
#  "save_json" scrie rezultatul pe ssd. Optiunea parents=True are acelasi rol ca mkdir -p: creeaza directoarele parinte daca lipsesc.



#====


# return 0 = succes.
# return 1 = eroare. 
# acest lucru este important pentru Jenkins; pipeline-ul se opreste automat daca validatorul returneaza codul 1.


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Valideaza configuratia Environment Builder."
    )
    parser.add_argument(
        "--config",
        default="config.json",
        help="Calea catre configuratia utilizatorului."
    )
    parser.add_argument(
        "--supported",
        default="supported_technologies.json",
        help="Calea catre lista tehnologiilor suportate."
    )
    parser.add_argument(
        "--output",
        default="generated/generated_vars.json",
        help="Calea fisierului de variabile generat."
    )
    return parser.parse_args()


def main():
    args = parse_arguments()

    try:
        config = load_json(args.config)
        supported = load_json(args.supported)
        errors = validate_config(config, supported)

        if errors:
            print("[ERROR] Configuratia nu este valida:", file=sys.stderr)

            for error in errors:
                print(f"  - {error}", file=sys.stderr)

            return 1

        generated = build_generated_variables(config, supported)
        save_json(generated, args.output)

        print("[OK] Configuratia este valida.")
        print(f"[OK] Variabile generate in: {args.output}")
        return 0

    except (ValueError, OSError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

