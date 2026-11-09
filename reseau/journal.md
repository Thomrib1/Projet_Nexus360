<!-- markdownlint-disable MD060 -->
# Journal d'exploitation, rôle Réseau et postes

| Date et heure | Machine | Action | Résultat | Preuve |
|---|---|---|---|---|
| 2026-10-22 14:00 | PC hôte | Vérification VMware, RAM, disque | à compléter | - |

| 2026-10-22 21:03 | PC hôte | Création VMnet10 à VMnet15 (host-only, sans DHCP, sans carte hôte) | OK | preuves/phase1-vmnet-editeur.png |
| 2026-10-22 21:04 | PC hôte | Sous-réseau VMnet8 relevé : 192.168.157.0/24 | OK | - |

| 2026-10-22 23:32 | GW-TEMPLATE | Installation Rocky 10.1 minimal, mises à jour, paquets, test des interfaces ens160 ens192 ens224 | OK | - |
| 2026-10-22 23:33 | PC hôte | Clé SSH id_nexus360 créée, connexion par clé testée sur GW-TEMPLATE | OK | - |
| 2026-10-22 23:34 | GW-TEMPLATE | Snapshot template-propre | OK | - |

| 2026-10-24 21:45 | LNX-GW04 | Relais DHCP dhcrelay-gw actif vers 10.36.11.10 et 10.36.12.11 | OK | preuves/A8-gw04-relais-dhcp.png |

| 2026-10-25 00:00 | LNX-GW01 | Clone, identité régénérée, gw-build.sh 1 (deux exécutions) | OK | preuves/A8-gw01-build-run1.png, preuves/A8-gw01-build-run2.png |
| 2026-10-25 00:01 | LNX-GW01 | gw-selftest.sh 1 : 14 PASS, 0 FAIL | OK | preuves/A8-selftest-gw01.png |
| 2026-10-25 00:02 | LNX-GW01 / LNX-GW04 | Ping du backbone et routage entre les sites 1 et 4 | OK | preuves/A8-gw01-gw04-routage.png |
| 2026-10-25 00:03 | LNX-GW01 | Snapshot gw-ok | OK | preuves/A8-gw01-snapshot.png |

| 2026-10-25 01:04 | TMP-DHCP | Kea actif, configuration de substitution des étendues 10.36.14.0/24 et 10.36.15.0/24 | OK | preuves/A8-tmpdhcp-kea-config.png, preuves/A8-tmpdhcp-kea-actif.png |
| 2026-10-25 01:04 | TMP-DHCP | Snapshot kea-ok | OK | preuves/A8-tmpdhcp-snapshot.png |

| 2026-10-27 18:27 | LNX-GW04 / TMP-DHCP / TST-DHCP | Relais DHCP validé : bail 10.36.14.110 obtenu via LNX-GW04, giaddr 10.36.14.1 | OK | preuves/A8-relais-dhcp-giaddr.png, preuves/A8-tstdhcp-bail.png, preuves/A8-tmpdhcp-bail.png |

| 2026-10-27 18:30 | TST-DHCP / TMP-DHCP | Routage de bout en bout entre les sites 4 et 1 (connexion SSH à travers LNX-GW04 et LNX-GW01) | OK | preuves/A8-routage-bout-en-bout.png |
| 2026-10-27 18:45 | TMP-DHCP | Absence de NAT entre sites : pair vu en 10.36.14.110 | OK | preuves/A8-pas-de-nat-entre-sites.png |
| 2026-10-27 19:00 | LNX-GW04 | MSS ramené de 1460 à 1240 sur le backbone | OK | preuves/A8-mss-lan-1460.png, preuves/A8-mss-1240.png |
| 2026-10-27 19:15 | TST-DHCP | MTU du backbone : 1252 passe, 1300 refusé avec mtu = 1280 | OK | preuves/A8-mtu-1280.png |

| 2026-10-27 20:00 | LNX-GW01 / LNX-GW04 / TMP-DHCP / TST-DHCP | Redémarrage dans l'ordre passerelles, serveur, client : services actifs, adresses revenues, ping de bout en bout 0 % de perte | OK | preuves/C4-redemarrage-gw01.png, preuves/C4-redemarrage-gw04.png, preuves/C4-redemarrage-tmpdhcp.png, preuves/C4-redemarrage-tstdhcp.png |

| 2026-10-27 20:13 | TST-DHCP | Snapshot client-ok | OK | preuves/A8-tstdhcp-snapshot.png |

| 2026-10-27 22:24 | LNX-GW04-bis | Reconstruction de LNX-GW04 depuis le dépôt : clone du modèle, gw-build.sh 4, selftest 14 PASS, bail et ping de bout en bout depuis TST-DHCP. Durée : 51 minutes entre la création du clone (21:33) et la fin du test, pauses de captures comprises | OK | preuves/A8-reconstruction-build.png, preuves/A8-reconstruction-selftest.png, preuves/A8-reconstruction-tstdhcp.png, preuves/A8-reconstruction-chrono.png |

| 2026-10-28 01:00 | CLI-W10-test | Connectivité du poste de test : passerelle 10.36.14.1, trajet par 10.36.0.1 jusqu'à 10.36.11.10, port 22 joignable, sortie Internet par le NAT | OK | preuves/A8-cli-w10-connectivite.png, preuves/A8-cli-w10-internet.png |
| 2026-10-28 01:01 | TMP-DHCP | Bail de 10.36.14.101 enregistré pour la MAC 00:50:56:2e:14:01 (réservation) | OK | preuves/A8-cli-w10-bail-kea.png |

| 2026-10-28 19:34 | CLI-W11-01 | Renommage du poste en CLI-W11-01 (par les Paramètres après un refus de Rename-Computer), réservation 10.36.14.101 conservée | OK | preuves/A8-cli-w11-renommage-erreur.png, preuves/A8-cli-w11-renommage.png, preuves/A8-cli-w11-bail-kea-renomme.png |
| 2026-10-28 19:44 | CLI-W11-01 | Snapshot cli-w11-01-pret | OK | preuves/A8-cli-w11-snapshot.png |

| 2026-10-28 19:45 | CLI-W11-01 | Installation de Windows 11 Pro : écran réseau obligatoire à la configuration initiale (erreur 0xe000022f), compte local créé par contournement | OK | preuves/A8-cli-w11-oobe-reseau.png, preuves/A8-cli-w11-edition.png |

| 2026-10-28 20:35 | LNX-GW05 | Clone de GW-TEMPLATE, identité régénérée, gw-build.sh 5 | OK | preuves/A8-gw05-cartes-vmware.png, preuves/A8-gw05-interfaces-avant.png, preuves/A8-gw05-fichiers-installes.png, preuves/A8-gw05-build.png |
| 2026-10-28 20:35 | LNX-GW05 | gw-selftest.sh 5 : 14 PASS, 0 FAIL ; relais DHCP actif vers 10.36.11.10 et 10.36.12.11 | OK | preuves/A8-selftest-gw05.png, preuves/A8-gw05-relais-dhcp.png |
| 2026-10-28 20:36 | LNX-GW05 / LNX-GW01 | Ping du backbone et routage entre les sites 5 et 1 | OK | preuves/A8-gw05-routage.png |
| 2026-10-28 20:36 | LNX-GW05 | Snapshot gw-ok | OK | preuves/A8-gw05-snapshot.png |

| 2026-10-28 21:35 | CLI-W11-02 | Adresse 10.36.15.110 obtenue via le relais DHCP de LNX-GW05, trajet par 10.36.15.1 et 10.36.0.1 jusqu'à 10.36.11.10, adresse source conservée sans NAT | OK | preuves/A8-cli-w11-02-bail.png, preuves/A8-cli-w11-02-connectivite.png |
| 2026-10-28 21:49 | CLI-W11-02 | Renommage du poste en CLI-W11-02 (Rename-Computer), bail renouvelé via le relais | OK | preuves/A8-cli-w11-02-renommage.png, preuves/A8-cli-w11-02-bail-kea.png |
| 2026-10-28 21:50 | CLI-W11-02 | Snapshot cli-w11-02-pret | OK | preuves/A8-cli-w11-02-snapshot.png |

| 2026-10-28 22:11
 | Dépôt Git | Preuves de CLI-W11-02 commitées directement sur main (branche oubliée), sans pull request ; contenu limité au journal et à des captures | OK | preuves/E3-historique-git.png |

 | 2026-10-29 23:12 | LNX-GW04 | Tailscale installé et connecté au tailnet (adresse 100.86.136.5) ; selftest toujours à 14 PASS ; machines partagées visibles mais hors ligne | OK | preuves/A8-gw04-tailscale-build.png, preuves/A8-gw04-tailscale-status.png, preuves/A8-tailscale-console-gw04.png |

 | 2026-10-29 23:51 | Tailnet | Politique d'accès écrite (tailnet-policy.hujson) avec autogroup:shared, validée dans l'éditeur d'ACL ; test négatif refusé par le validateur (8.8.8.8:53, got: Drop), test deny accepté | OK | preuves/B5-tailnet-tests-verts.png, preuves/B5-tailnet-test-negatif.png, preuves/B5-tailnet-tests-deny.png |

 | 2026-11-09 12:00 | CLI-LNX01 | Ubuntu 26.04.1 LTS Desktop sur VMnet14, MAC 00:50:56:2E:14:02, réservation 10.36.14.102 obtenue via le relais DHCP, connectivité vers le site 1 et Internet | OK | preuves/A2-cli-lnx01-installation.png, preuves/A2-cli-lnx01-bail-reservation.png, preuves/A2-cli-lnx01-connectivite.png, preuves/A2-cli-lnx01-bail-kea.png |
| 2026-11-09 12:00 | CLI-LNX01 | DNS du domaine uniquement (FallbackDNS vidé) : apt update ne résout plus les noms Internet sans les DC | OK | preuves/A2-cli-lnx01-dns-seul.png |
| 2026-11-09 12:03 | CLI-LNX01 | Nom cli-lnx01, chrony configuré vers 10.36.11.10 et 10.36.12.11 (sources inaccessibles chez moi, synchronisation non vérifiable sans les DC) | OK | preuves/A2-cli-lnx01-chrony.png |
| 2026-11-09 12:04 | CLI-LNX01 | dhcp-identifier mac ajouté dans netplan (profil NetworkManager netplan-ens33) : réservation par MAC compatible avec les DC. Activation échouée une première fois car TMP-DHCP était éteinte, résolue en allumant TMP-DHCP | OK | preuves/A2-cli-lnx01-netplan-identifier.png, preuves/A2-cli-lnx01-dhcp-identifier.png |
| 2026-11-09 12:07 | CLI-LNX01 | Snapshot cli-lnx01-pret | OK | preuves/A2-cli-lnx01-snapshot.png |
| 2026-11-09 12:10 | Thomas / DHCP | Réponse reçue : options d'étendue, relais vers les deux DC (équilibrage 50/50), réservations acceptées, OU des postes (Windows, Pilote, Linux) | OK | preuves/E1-reponse-thomas-dhcp-ou.png |