# Jenkins CI/CD - FastAPI microservices

Ce dépôt contient deux API FastAPI (`cast-service` et `movie-service`), leurs bases PostgreSQL, un reverse proxy Nginx, un chart Helm et un pipeline Jenkins.

## Environnements Kubernetes

Le pipeline utilise un namespace Kubernetes par environnement : `dev`, `qa`, `staging` et `prod`. Le chart `charts/` y installe les deux API, les deux bases PostgreSQL avec volumes persistants et Nginx. Les migrations et valeurs spécifiques aux environnements peuvent être ajoutées au chart selon les besoins.

Il faut fournir au cluster une StorageClass par défaut pour les volumes PostgreSQL et configurer un contrôleur Ingress si une URL HTTP externe est souhaitée. Sans Ingress, accéder à l’application avec, par exemple :

```sh
kubectl -n dev port-forward service/app-fastapiapp 8080:8080
```

Puis ouvrir `http://localhost:8080/api/v1/movies/docs` ou `http://localhost:8080/api/v1/casts/docs`.

Pour créer un cluster local, installer Docker Desktop avec Kubernetes activé ou Minikube, puis vérifier `kubectl cluster-info` et `helm version`. Les ressources ne créent pas de cluster chez un fournisseur cloud : elles déploient dans le cluster défini par le kubeconfig Jenkins.

## Jenkins et prérequis

Une configuration Docker Compose est fournie pour Windows avec Docker Desktop, Jenkins LTS, les plugins requis, Docker CLI, `kubectl` et Helm dans l’image Jenkins. Depuis la racine du dépôt :

```powershell
docker compose -f docker-compose.jenkins.yml up -d --build
docker compose -f docker-compose.jenkins.yml logs -f jenkins
```

Quand Jenkins a terminé de démarrer, ouvrir `http://localhost:8081`. Récupérer le mot de passe initial dans un autre terminal :

```powershell
docker compose -f docker-compose.jenkins.yml exec jenkins `
  cat /var/jenkins_home/secrets/initialAdminPassword
```

Déverrouiller Jenkins, choisir l’installation des plugins suggérés (les plugins requis sont déjà inclus dans l’image), puis créer le compte administrateur. Docker Desktop doit rester démarré ; le socket Docker est monté pour permettre au pipeline de construire les images.

Le job multibranche `examjenkins-multibranch` est déjà configuré pour le dépôt public `https://github.com/WTsotetzo/examjenkins.git`, avec `Jenkinsfile` comme script et un scan périodique de la source. Jenkins utilise la source Git directe afin d’éviter les limites de quota de l’API GitHub. Comme Jenkins est local, un webhook GitHub ne peut pas l’atteindre sans endpoint public.

Créer les credentials Jenkins suivants (type et identifiant exacts) :

| ID Jenkins | Type | Contenu |
| --- | --- | --- |
| `dockerhub-credentials` | Username with password | Compte DockerHub autorisé à publier les images |
| `kubeconfig` | Secret file | Kubeconfig avec droits de création/gestion des ressources dans les quatre namespaces |
| `db-credentials-dev` | Username with password | Identifiants PostgreSQL pour `dev` |
| `db-credentials-qa` | Username with password | Identifiants PostgreSQL pour `qa` |
| `db-credentials-staging` | Username with password | Identifiants PostgreSQL pour `staging` |
| `db-credentials-prod` | Username with password | Identifiants PostgreSQL pour `prod` |

Ajouter ces identifiants dans **Manage Jenkins > Credentials > System > Global credentials**. Utiliser un token d’accès DockerHub plutôt que le mot de passe du compte. Les valeurs de base de données doivent être propres à chaque environnement ; choisir des identifiants composés uniquement de lettres, chiffres, `_` ou `-`, afin que l’URI PostgreSQL soit non ambiguë. Le pipeline crée le namespace puis le Secret `app-db-credentials` dans cet environnement. Les mots de passe ne sont pas stockés dans Git.

Le kubeconfig de l’hôte utilise `127.0.0.1`, adresse inaccessible depuis Jenkins dans son conteneur. Préparer une copie locale adaptée au réseau Docker avec :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\prepare-jenkins-kubeconfig.ps1 `
  -ContextName docker-desktop
```

Téléverser ensuite `.jenkins-kubeconfig` comme credential `kubeconfig` de type **Secret file**. Ce fichier contient des clés privées : il est ignoré par Git, ne pas le partager ni le committer. Le paramètre `-ContextName` permet de sélectionner explicitement le contexte, notamment `docker-desktop` si le contexte courant est différent. Le script conserve l’authentification et l’autorité de certification du kubeconfig sélectionné, mais utilise `host.docker.internal` pour joindre le cluster depuis Jenkins.

Le paramètre `DOCKERHUB_NAMESPACE` est initialisé avec `willyddn` ; le modifier dans le Jenkinsfile si le compte DockerHub cible est différent. Créer les dépôts DockerHub `cast-service` et `movie-service` avant le premier lancement si la création automatique n’est pas autorisée.

## Pipeline

À chaque build de branche, Jenkins valide le chart, construit les deux images Docker avec un tag immuable `BUILD_NUMBER-GIT_SHA`, les publie sur DockerHub et déploie `dev`.

Uniquement sur la branche `master`, le pipeline poursuit automatiquement vers `qa` et `staging`, puis attend une approbation manuelle avant de déployer `prod`. Le déploiement de production ne peut pas démarrer depuis une autre branche.

## Lancer l’application en local avec Docker Compose

Depuis la racine du dépôt :

```sh
docker compose up --build
```

Les documentations API sont disponibles sur `http://localhost:8080/api/v1/movies/docs` et `http://localhost:8080/api/v1/casts/docs`.

## Dépôt GitHub personnel

Le dépôt d’origine peut être forké depuis GitHub vers votre compte. Clonez ensuite votre fork, ou remplacez l’URL du remote `origin` par celle-ci avant de pousser votre branche `master`. L’accès à un compte GitHub/DockerHub et les secrets de cluster ne sont pas présents dans ce dépôt et doivent être configurés dans vos comptes respectifs.
