# Chart Helm

Ce chart déploie les services Cast et Movie, leurs StatefulSets PostgreSQL persistants et un reverse proxy Nginx.

Avant l’installation, créer le namespace et un Secret `app-db-credentials` contenant `POSTGRES_USER`, `POSTGRES_PASSWORD`, `CAST_DATABASE_URI` et `MOVIE_DATABASE_URI`. Le Jenkinsfile crée ce Secret à partir du credential `db-credentials-<environnement>`. Les images Cast et Movie ainsi que leurs tags sont des valeurs surchargeables, voir `values.yaml`.

Le Service Nginx s’appelle `app-fastapiapp` avec le nom de release utilisé dans le Jenkinsfile. L’accès extérieur est ClusterIP par défaut ; utiliser un Ingress configuré ou `kubectl port-forward` pour accéder aux API.
