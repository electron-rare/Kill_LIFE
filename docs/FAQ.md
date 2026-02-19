# Easter Egg musique expérimentale

_« La FAQ se lit comme une partition acousmatique : chaque question résonne, chaque réponse module le silence. »_ — François Bayle
# FAQ

## Est-ce que les evidence packs rêvent de conformité ?
Oui, mais seulement dans les dystopies techniques où chaque gate est une fête, chaque README une serviette, et chaque agent QA un replicant en quête de validation. Ne panique jamais, même si le sanitizer te retire ta phrase préférée.

## Peut-on survivre à une apocalypse technique façon Liu Cixin ?
"Quand le pipeline observe, il n’y a plus de place pour l’erreur. Comme dans Le Problème à trois corps, chaque evidence pack est une trace laissée pour les civilisations futures."

## Pourquoi des labels `ai:*` ?
Ils servent à deux choses :
1) déclencher des étapes agentiques (spec/plan/tasks/impl/qa/docs)
2) définir le **scope autorisé** via le scope guard (allowlist par label).

## Comment arrêter l’automation ?
Ajoute le label `ai:hold` sur l’issue ou la PR. Traite ensuite le ticket manuellement.

## Pourquoi le sanitizer est “agressif” ?
Les issues/PR contiennent du texte non fiable (copié/collé, URLs, snippets). Le sanitizer retire ces zones à risque avant injection dans un prompt.

## Pourquoi OpenClaw est en “observateur” ?
Pour réduire la surface d’attaque : OpenClaw ne fait que labels/commentaires. Les actions d’écriture passent par les workflows GitHub (audités) et leurs gates.

## Le scope guard bloque ma PR, que faire ?
Soit :
- change le label `ai:*` vers celui qui correspond à tes modifications
- ou découpe en deux PRs (ex: docs vs firmware)

## Je ne veux pas que les templates d’issues déclenchent l’automation
Les templates Feature/Bug/Compliance/Agentics ajoutent maintenant des labels `ai:*` par défaut.
Si tu veux un mode “triage d’abord”, enlève le label `ai:*` après création, ou ajuste les templates.
