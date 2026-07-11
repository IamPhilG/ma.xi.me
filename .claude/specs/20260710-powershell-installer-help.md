## Spec : aide intégrée de l’installateur PowerShell
**Quoi** : ajouter une aide comment-based PowerShell à `install/install.ps1`, décrivant les options, les cibles, le mode repo-only, les sauvegardes et les exemples de lancement.
**Pourquoi** : `Get-Help` ne fournit actuellement que la signature des paramètres.
**Fichiers touchés** : `install/install.ps1`.
**Approche** :
1. Insérer l’aide standard PowerShell avant `[CmdletBinding()]`.
2. Décrire `Target`, `CopilotScope`, `WorkspaceRoot`, `WhatIf` et `Confirm`.
3. Inclure les exemples depuis mA.xI.me et depuis un autre répertoire.
4. Vérifier le rendu via `Get-Help` et la syntaxe du script.
**Risques / alternatives écartées** : pas de paramètre `-Help` supplémentaire ni de menu interactif; `Get-Help` et `-?` sont les conventions natives.
**Taille** : S
