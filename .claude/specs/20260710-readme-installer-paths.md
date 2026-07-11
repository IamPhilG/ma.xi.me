## Spec : chemins d'installation README
**Quoi** : corriger les exemples d'installation avec repo cible explicite afin qu'ils désignent toujours le script situé dans le dépôt mA.xI.me.
**Pourquoi** : `install\install.ps1` ou `./install/install.sh` est résolu depuis le répertoire courant et échoue depuis un répertoire tiers.
**Fichiers touchés** : `README.md`.
**Approche** :
1. Remplacer les exemples « autre répertoire » par le chemin complet vers le script du dépôt mA.xI.me.
2. Ajouter les formes relatives valables depuis la racine de mA.xI.me.
3. Aligner les exemples de prévisualisation et macOS/Linux.
4. Vérifier le diff et les espaces.
**Risques / alternatives écartées** : aucune modification des installateurs; ne pas supposer que le répertoire courant est mA.xI.me quand l'exemple annonce le contraire.
**Taille** : S
