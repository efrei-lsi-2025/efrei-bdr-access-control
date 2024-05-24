# Contrôle d'accès à des locaux d'entreprise

Projet du module Bases de données réparties à l'EFREI.

## Installation

- Installer docker
- `cd docker`
- `cp .env.example .env` et modifier les variables si besoin
- `docker compose up -d`

## Structure

* Diagnostics : Scripts sql de test et de diagnotique de la base de données
* docker : fichiers de configuration docker
* load-testing : script de test de charge et de simulation (typescript)
* scripts : Script de configuration de la base de données, numérotés par ordre d'exécution
   -  1-create_tables.sql : création du modèle de données
   -  2-setup.sql : configuration de citus
   -  3-views.sql : création des vues
   -  4-triggers.sql : création des triggers
   -  5-jobs.sql (inutilisé) : fonctions de nettoyage des données
   -  6-business.sql : fonctions de la logique métier
