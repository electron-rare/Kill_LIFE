# Veille OSS — observabilité légère et incidents Mascarade (2026-03-21)

## Objectif

Identifier des briques open source ou officiellement documentées pour renforcer:

- le brief d'incident quotidien
- le registre d'incidents horodaté
- la synthèse hebdomadaire opératoire
- l'observabilité légère d'une pile locale/LLM

## Références retenues

| Projet | Source primaire | Ce qui est utile pour Kill_LIFE | Réutilisation concrète |
| --- | --- | --- | --- |
| Uptime Kuma | [Site officiel](https://uptimekuma.org/) et [wiki status page](https://github.com/louislam/uptime-kuma/wiki/Status-Page) | monitoring simple auto-hébergé, status pages, incidents légers, historique visuel | bon modèle pour garder une vue “status + incident + latest” lisible par opérateur sans stack lourde |
| Gatus | [Repo officiel](https://github.com/TwiN/gatus) | status page orientée développeur, alerting, incidents, configuration simple | pattern intéressant pour des checks déclaratifs Kill_LIFE/Mascarade et une sortie orientée endpoints/workflows |
| OpenObserve | [Site officiel](https://openobserve.ai/) et [repo officiel](https://github.com/openobserve/openobserve) | logs, metrics, traces, dashboards, alerts dans une seule brique open source | candidat naturel si la couche Mascarade/Ollama dépasse la TUI légère et demande une vraie observabilité centralisée |
| Grafana OnCall OSS | [Intro officielle](https://grafana.com/docs/oncall/latest/intro/) et [note de maintenance officielle](https://grafana.com/blog/grafana-oncall-maintenance-mode/) | workflow incident/on-call mature, mais maintenance mode documenté officiellement | utile comme référence UX/process, mais à éviter comme dépendance stratégique nouvelle vu son statut de maintenance |
| Netdata | [Open source](https://www.netdata.cloud/open-source/) et [alert notifications](https://learn.netdata.cloud/docs/alerts-%26-notifications/notifications/agent-dispatched-notifications/agent-notifications-reference) | observabilité temps réel légère, alertes par agent, faible coût d'entrée | bonne référence pour enrichir des snapshots temps réel et des alertes simples avant d'aller vers une pile plus lourde |

## Synthèse opérationnelle

- `Uptime Kuma` et `Gatus` sont les meilleures références pour un niveau “health + incident + statut opérateur” léger.
- `OpenObserve` est la meilleure piste si Kill_LIFE veut centraliser logs/metrics/traces autour de Mascarade, mesh et lanes opératoires.
- `Grafana OnCall OSS` reste utile comme benchmark de workflow incident, mais son statut de maintenance au 21 mars 2026 en fait une référence d'UX plus qu'une cible d'adoption.
- `Netdata` est la meilleure référence pour une observabilité locale très rapide à déployer si l'objectif est de compléter les scripts TUI par de l'alerte temps réel.

## Décision de lot

- Continuer en priorité avec la voie locale légère: `brief Markdown + registre d'incidents + TUI/logs`.
- Garder `OpenObserve` comme option de montée en puissance.
- Ne pas introduire de nouvelle dépendance incident lourde tant que la voie cockpit/TUI couvre correctement les besoins opératoires.

## Complément orienté incident knowledge / LLM observability

| Projet | Source primaire | Ce qui est utile pour Kill_LIFE | Réutilisation concrète |
| --- | --- | --- | --- |
| TheHive | [Introducing TheHive](https://blog.thehive-project.org/2016/11/07/introducing-thehive/) | workflow incident/alert/case collaboratif | bon benchmark pour faire évoluer le registre d'incidents horodaté vers une logique de cas et d'escalade |
| incident.io | [Understanding priority, urgency, and severity](https://docs.incident.io/articles/6990078692-understanding-priority%252C-urgency%252C-and-severity) | taxonomie claire entre sévérité, urgence et priorité | très utile pour garder un registre et une queue d'incidents sans ambiguïté de vocabulaire opératoire |
| Material for MkDocs | [Site officiel](https://squidfunk.github.io/mkdocs-material/) | publication Markdown rapide, searchable, maintenable | bon support si les briefs et synthèses doivent devenir un runbook vivant consultable hors repo brut |
| OpenTelemetry | [Docs officielles](https://opentelemetry.io/docs/) | standard neutre pour traces, métriques et logs | piste de normalisation si Kill_LIFE souhaite unifier plus tard la télémétrie agents/services/scripts |
| OpenTelemetry AI Agent Observability | [Blog officiel](https://opentelemetry.io/blog/2025/ai-agent-observability/) | instrumentation et corrélation spécifiques aux workflows d'agents IA | référence primaire utile si la couche Mascarade doit passer du simple brief/log à de vraies traces d'agents et spans métier |
| Grafana Loki | [Docs officielles](https://grafana.com/docs/loki/latest/) | agrégation de logs légère avec labels et requêtes | bonne référence si les logs cockpit/Mascarade deviennent trop volumineux pour la seule voie TUI |
| Langfuse | [Site officiel](https://langfuse.com/) | observabilité LLM, traces, evals, prompts, métriques | très pertinent pour comparer les runs des agents Mascarade et détecter les régressions de comportement |

Synthèse complémentaire:
- `incident.io` donne la meilleure base officielle pour distinguer `severity` et `priority`; c'est utile pour stabiliser la sémantique du registre et de la queue d'incidents.
- `TheHive` et `Material for MkDocs` sont surtout des références d'organisation et de publication du savoir opératoire.
- `OpenTelemetry` et sa note `AI Agent Observability` sont les meilleures pistes si la couche locale légère doit un jour devenir une vraie chaîne d'observabilité standardisée pour agents, services et scripts.
- `Langfuse` est la référence la plus directement exploitable pour une future observabilité spécifique aux agents et modèles Mascarade.

## Complément orienté watchboard / status page opérateur

| Projet | Source primaire | Ce qui est utile pour Kill_LIFE | Réutilisation concrète |
| --- | --- | --- | --- |
| OpenStatus | [Docs officielles](https://www.openstatus.dev/docs) | vues status/incidents très lisibles, timeline simple, endpoints publics orientés statut | bon benchmark pour faire évoluer `incident-watch` vers une vue publique ou semi-publique plus structurée |
| OneUptime | [Docs officielles](https://oneuptime.com/docs/introduction) | pile open source incidents + monitoring + status pages + on-call | référence intéressante si la couche cockpit devait un jour agréger dépendances, incidents et notifications dans une seule stack |

Synthèse watchboard:
- `OpenStatus` est une bonne référence de lisibilité pour les vues courtes `watch/status/latest`.
- `OneUptime` est plus large et plus lourd, mais reste un bon benchmark si Kill_LIFE veut unifier plus tard `monitoring + incidents + status pages`.
- Pour le lot courant, la bonne décision reste de conserver la voie légère locale `incident-watch` en TUI, sans introduire une nouvelle dépendance de prod.

## Complément orienté mémoire / reprise / confiance

| Projet | Source primaire | Ce qui est utile pour Kill_LIFE | Réutilisation concrète |
| --- | --- | --- | --- |
| LangChain Memory | [Concepts memory](https://docs.langchain.com/oss/python/concepts/memory) | distinction nette entre mémoire court terme de thread et mémoire long terme | confirme le découpage `ops = thread courant`, `kill_life = reprise durable / mémoire long terme` |
| LangGraph Memory | [Add memory](https://docs.langchain.com/oss/python/langgraph/add-memory) | `checkpointer`, persistance et reprise entre étapes / sous-graphes | renforce le choix d'un `resume_ref` stable et d'un artefact `latest` relu par plusieurs surfaces |
| AutoGen Memory | [Memory and RAG](https://microsoft.github.io/autogen/dev/user-guide/agentchat-user-guide/memory.html) | stores mémoire, query, update_context, stratégies de rappel | utile si `kill_life` doit évoluer d'une mémoire fichier vers un store plus riche inter-runs |
| OpenTelemetry AI Agent Observability | [Blog officiel](https://opentelemetry.io/blog/2025/ai-agent-observability/) | traces agents, corrélation tool calls / décisions / spans | valide le couple `trust_level + routing + artifacts` avant une instrumentation plus lourde |

Synthèse mémoire:
- garder une mémoire `latest` légère et lisible tant que le contrat produit continue d'évoluer.
- ne passer à un vrai store mémoire d'agent qu'après stabilisation de `resume_ref`, `trust_level`, `routing` et `memory_entry`.

## Complément orienté handoff léger / reprise opérateur

| Projet | Source primaire | Ce qui est utile pour Kill_LIFE | Réutilisation concrète |
| --- | --- | --- | --- |
| incident.io Scribe | [Documentation officielle](https://docs.incident.io/ai/scribe) | synthèse rapide pour quelqu'un qui rejoint ou reprend un incident sans relire toute la discussion | confirme l'intérêt d'un handoff court `latest + next steps + decisions` dans Kill_LIFE |
| incident.io On-call | [Getting started with On-call](https://docs.incident.io/on-call/getting-started) | explicite les `handover times` et la préparation de reprise côté astreinte | valide la présence d'une reprise courte et régulière dans les surfaces opérateur |
| PagerDuty My On-Call Shifts | [Documentation officielle](https://support.pagerduty.com/main/lang-ja/docs/my-on-call-shifts) | vue compacte `current + next` des responsabilités | bon benchmark pour les vues `watch + resume_ref + next_step` les plus courtes |

Synthèse handoff:
- garder une vue de reprise très courte, accessible sans navigation profonde, reste le meilleur pattern.
- la valeur n'est pas dans plus d'IA, mais dans une continuité visible: état courant, prochain pas, responsable, reprise.

## Complément orienté contrôle humain / exécution durable

| Projet | Source primaire | Ce qui est utile pour Kill_LIFE | Réutilisation concrète |
| --- | --- | --- | --- |
| LangGraph | [Overview officielle](https://docs.langchain.com/oss/python/langgraph/overview) | met en avant les agents stateful, le contrôle humain et la durabilité d'exécution | confirme qu'un contrat de reprise léger doit précéder toute orchestration plus profonde |
| AutoGen | [Memory and RAG](https://microsoft.github.io/autogen/dev/user-guide/agentchat-user-guide/memory.html) | montre comment la mémoire structure le rappel, le contexte et la reprise inter-runs | valide l'usage d'une mémoire `kill_life` commune avant d'ouvrir un store plus riche |
| OpenTelemetry | [AI Agent Observability](https://opentelemetry.io/blog/2025/ai-agent-observability/) | relie exécution d'agents, traces et supervision humaine | utile pour garder `trust_level + routing + artifacts` comme base d'explicabilité instrumentable plus tard |

Synthèse HITL/durable:
- la bonne séquence reste: `contrat produit stable -> mémoire de reprise lisible -> audit statique -> instrumentation plus lourde`.
- l'extension de surface seule n'apporte pas de fiabilité ; la valeur vient de la continuité et de la supervision humaine explicite.
- d'après la doc LangGraph sur le HITL et les interruptions, un bon système de reprise doit pouvoir `pause -> inspect -> approve/edit/reject -> resume`; c'est cohérent avec `resume_ref`, `trust_level` et un handoff court unique.
- la doc incident.io Scribe confirme qu'une synthèse et des moments clés servent surtout à permettre une reprise sans interrompre l'exécution en cours; c'est exactement le rôle du handoff produit minimal.
