# PV de test de restauration - Sauvegarde des partages (C3)

- Date : 10/11/2026
- Machine : SRV-FS01
- Source : E:\Partages
- Destination : C:\Sauvegardes (dossier daté), rétention de 7 jours
- Tâche planifiée : Nexus-Backup-Partages, tous les jours à 02:00

## Procédure
1. Création de E:\Partages\Commun\restore-test.txt et calcul de son empreinte SHA-256.
2. Sauvegarde avec Backup-NexusShares.ps1 (dossier C:\Sauvegardes\20261110-034906).
3. Suppression du fichier.
4. Restauration depuis le dossier daté, puis nouveau calcul de l'empreinte.

## Résultat
- Empreinte avant : 7F36A14E2A4D6B7862BFEBB85B168232F19D0F3C51909DE96A523F319AD5D274
- Empreinte après : 7F36A14E2A4D6B7862BFEBB85B168232F19D0F3C51909DE96A523F319AD5D274
- Fichiers identiques : oui

## Preuves
- preuves/c3-restauration.png
- preuves/c3-sauvegarde.png
- preuves/c3-tache.png

## Limite connue
La destination est sur la même VM que les données : une panne de SRV-FS01 perdrait les deux. À déplacer vers LNX-OPS01 quand le réseau sera en place.
