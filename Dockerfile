#Dockerfile este template-ul folosit de Docker pentru construirea imaginii validatorului.
#Dockerfile > docker build > imagine Docker > docker run > container care executa validator.py
 

#FROM python:3.13-slim -> Pornim de la o imagine Linux mica, in care Python 3.13 este deja instalat.
#WORKDIR /app > Stabileste /app ca director de lucru in interiorul imaginii.
#COPY src/validator.py /app/validator.py > copiaza validatorul meu in imagine.
#COPY supported_technologies.json /app/supported_technologies.json > copiaza lista tehnologiilor acceptate.
#RUN mkdir -p /app/generated > creeaza directorul in care validatorul va scrie rezultatul.
#ENTRYPOINT ["python3", "/app/validator.py"] > spune ce comanda trebuie executata automat atunci cand porneste containerul.

#config.json de pe Ubuntu > /app/config.json din container
#ca sa nu reconstruim imaginea de fiecare data cand userul schimba lista tehnologiilor.

FROM python:3.13-slim

WORKDIR /app

COPY src/validator.py /app/validator.py
COPY supported_technologies.json /app/supported_technologies.json

RUN mkdir -p /app/generated

ENTRYPOINT ["python3", "/app/validator.py"]


