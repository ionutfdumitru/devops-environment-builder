# Environment Builder - proiect final DevOps

Scopul proiectului este sa configureze automat un server in functie de tehnologiile trecute intr-un fisier `config.json`.

Am ales sa suport urmatoarele tehnologii:

- Docker
- Python
- Git
- Nginx

Nginx este tehnologia adaugata pentru cerinta extra.

## Cum functioneaza

Utilizatorul completeaza fisierul `config.json`.

Scriptul Python verifica daca tehnologiile si versiunile sunt suportate. Daca exista o problema, afiseaza eroarea si se opreste.

Daca fisierul este valid, scriptul genereaza `generated/generated_vars.json`. Acest fisier este folosit de Ansible pentru a instala pachetele cerute pe serverul EC2.

Dupa instalare, scriptul Bash verifica daca fiecare comanda exista si daca raspunde corect.

Fluxul general este:

```text
config.json
> validator Python
> generated_vars.json
> Ansible
> server EC2
> verificare Bash
```

Jenkins automatizeaza acest proces, construieste imaginea Docker si o publica pe Docker Hub.

Terraform este folosit pentru crearea si administrarea instantei EC2, a Security Group-ului si a key pair-ului.

Pentru partea optionala am adaugat si un deploy local in Minikube, format din ConfigMap, Deployment si Service.

## Fisiere importante

1. `config.json` - configuratia introdusa de utilizator
2. `supported_technologies.json` - lista unica a tehnologiilor suportate
3. `src/validator.py` - validarea si generarea variabilelor
4. `scripts/verify_environment.sh` - verificarea dupa instalare
5. `Dockerfile` - imaginea validatorului
6. `docker-compose.yml` - rularea validatorului in container
7. `ansible/playbook.yml` - instalarea tehnologiilor
8. `terraform/main.tf` - infrastructura AWS
9. `Jenkinsfile` - pipeline-ul proiectului
10. `kubernetes/` - fisierele pentru Minikube




## Cerinte pentru rulare

Pe masina de pe care se ruleaza proiectul trebuie sa existe:

- Git
- Python 3
- Docker si Docker Compose
- Ansible
- Terraform
- AWS CLI configurat
- Jenkins

Pentru partea AWS este necesar un cont AWS si o cheie SSH.

## Configuratia utilizatorului

Fisierul `config.json` contine tehnologiile care trebuie instalate.

Exemplu:

```json
{
  "technologies": [
    {
      "name": "docker",
      "version": "latest"
    },
    {
      "name": "python",
      "version": "3"
    },
    {
      "name": "git",
      "version": "latest"
    },
    {
      "name": "nginx",
      "version": "latest"
    }
  ]
}
```

Daca o tehnologie sau o versiune nu este acceptata, validatorul afiseaza eroarea si returneaza codul `1`.

## Validarea locala

Validatorul poate fi rulat direct cu Python:

```bash
python3 src/validator.py
```

Pentru testarea unei configuratii gresite:

```bash
python3 src/validator.py --config config-invalid.json
```

Cand configuratia este valida se genereaza:

```text
generated/generated_vars.json
```

## Rularea cu Docker Compose

Construirea imaginii:

```bash
docker compose build
```

Rularea validatorului:

```bash
docker compose run --rm validator
```

Imaginea publica este disponibila pe Docker Hub:

```text
mufarin/devops-environment-validator:latest
```


## Crearea infrastructurii cu Terraform

Copiaza fisierul exemplu:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

In `terraform/terraform.tfvars`, inlocuieste valoarea cu IP-ul public de pe care se face conexiunea:

```hcl
ssh_allowed_cidr = "YOUR_PUBLIC_IP/32"
```

Comenzile Terraform sunt:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform fmt
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

Terraform creeaza sau administreaza:

- instanta EC2;
- Security Group-ul pentru SSH;
- key pair-ul SSH;
- output-urile cu ID-urile si IP-ul public.

State-ul Terraform si fisierul `terraform.tfvars` nu sunt publicate in Git.

## Configurarea serverului cu Ansible

Copiaza inventory-ul exemplu:

```bash
cp ansible/inventory.example.yml ansible/inventory.yml
```

In `ansible/inventory.yml` completeaza:

- IP-ul public EC2;
- utilizatorul SSH;
- calea catre cheia privata.

Testeaza conexiunea:

```bash
ansible -i ansible/inventory.yml aws -m ansible.builtin.ping
```

Ruleaza instalarea:

```bash
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml
```

Playbook-ul instaleaza numai pachetele cerute, porneste serviciile Docker si Nginx, apoi ruleaza scriptul Bash de verificare.

O a doua rulare trebuie sa fie idempotenta si sa afiseze `changed=0`.


## Pipeline Jenkins

Job-ul Jenkins foloseste optiunea `Pipeline script from SCM` si citeste `Jenkinsfile` din branch-ul `main`.

Credentialele necesare in Jenkins sunt:

- `dockerhub-credentials` - username si access token Docker Hub;
- `aws-ssh-key` - utilizatorul `ubuntu` si cheia privata SSH.

La pornirea build-ului trebuie completat parametrul:

```text
EC2_HOST
```

Acesta este IP-ul public curent al instantei EC2.

Pipeline-ul executa:

1. checkout din GitHub;
2. construirea imaginii validatorului;
3. validarea configuratiei;
4. verificarea fisierelor Terraform;
5. configurarea EC2 cu Ansible;
6. verificarea instalarii;
7. publicarea imaginii `latest` si a imaginii cu numarul build-ului pe Docker Hub.

## Deploy local in Minikube

Pornirea clusterului:

```bash
minikube start --driver=docker
```

Aplicarea configuratiei:

```bash
minikube kubectl -- apply -f kubernetes/configmap.yml
minikube kubectl -- apply -f kubernetes/deployment.yml
minikube kubectl -- apply -f kubernetes/service.yml
```

Verificarea Pod-ului:

```bash
minikube kubectl -- get pods
```

Logul validatorului:

```bash
minikube kubectl -- logs deployment/environment-builder -c validator
```

Service-ul expune prin Nginx fisierul `generated_vars.json`.

Portul se poate afla cu:

```bash
minikube kubectl -- get service environment-builder
```

IP-ul clusterului se poate afla cu:

```bash
minikube ip
```

Rezultatul poate fi accesat la:

```text
http://MINIKUBE_IP:NODE_PORT/generated_vars.json
```

## Fisiere care nu se publica

Repository-ul ignora:

- state-ul Terraform;
- `terraform.tfvars`;
- inventory-ul Ansible local;
- cheile SSH;
- token-urile si fisierele `.env`;
- fisierele generate la rulare.

Credentialele AWS, Docker Hub si cheia privata SSH nu sunt scrise in cod.

## Oprirea resurselor

Pentru a opri instanta fara sa fie stearsa:

```bash
aws ec2 stop-instances --instance-ids INSTANCE_ID --region eu-west-1
```

Pentru eliminarea completa a infrastructurii administrate de configuratia Terraform:

```bash
terraform -chdir=terraform destroy
```

Comanda `destroy` trebuie folosita numai atunci cand resursele nu mai sunt necesare.

