def deployEnvironment(String targetEnvironment) {
    withCredentials([
        file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG'),
        usernamePassword(
            credentialsId: "db-credentials-${targetEnvironment}",
            usernameVariable: 'DB_USER',
            passwordVariable: 'DB_PASSWORD'
        )
    ]) {
        def secretFile = ".jenkins-app-db-credentials-${targetEnvironment}.yaml"

        try {
            withEnv(["TARGET_ENV=${targetEnvironment}"]) {
                withEnv(["SECRET_FILE=${secretFile}"]) {
                    sh '''
                    set -eu
                    set +x
                    trap 'rm -f "$SECRET_FILE"' EXIT

                    case "$DB_USER" in
                      ''|*[!a-zA-Z0-9_-]*)
                        echo "Le nom d'utilisateur PostgreSQL doit utiliser uniquement des caractères URI sûrs."
                        exit 1
                        ;;
                    esac
                    case "$DB_PASSWORD" in
                      ''|*[!a-zA-Z0-9_-]*)
                        echo "Le mot de passe PostgreSQL doit utiliser uniquement des caractères URI sûrs."
                        exit 1
                        ;;
                    esac

                    encode_secret() {
                      printf '%s' "$1" | base64 | tr -d '\\n'
                    }
                    {
                      printf '%s\\n' 'apiVersion: v1' 'kind: Secret' 'metadata:' \
                        '  name: app-db-credentials' "  namespace: $TARGET_ENV" 'type: Opaque' 'data:'
                      printf '  POSTGRES_USER: %s\\n' "$(encode_secret "$DB_USER")"
                      printf '  POSTGRES_PASSWORD: %s\\n' "$(encode_secret "$DB_PASSWORD")"
                      printf '  CAST_DATABASE_URI: %s\\n' \
                        "$(encode_secret "postgresql://${DB_USER}:${DB_PASSWORD}@cast-db:5432/cast_db")"
                      printf '  MOVIE_DATABASE_URI: %s\\n' \
                        "$(encode_secret "postgresql://${DB_USER}:${DB_PASSWORD}@movie-db:5432/movie_db")"
                    } > "$SECRET_FILE"

                    kubectl create namespace "$TARGET_ENV" --dry-run=client -o yaml | kubectl apply -f -
                    kubectl apply -f "$SECRET_FILE"
                    helm upgrade --install app ./charts \
                      --namespace "$TARGET_ENV" \
                      --set-string services.cast.image.repository="docker.io/${DOCKERHUB_NAMESPACE}/cast-service" \
                      --set-string services.cast.image.tag="$IMAGE_TAG" \
                      --set-string services.movie.image.repository="docker.io/${DOCKERHUB_NAMESPACE}/movie-service" \
                      --set-string services.movie.image.tag="$IMAGE_TAG" \
                      --wait --atomic --timeout 10m
                    '''
                }
            }
        } finally {
            if (fileExists(secretFile)) {
                sh "rm -f '${secretFile}'"
            }
        }
    }
}

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        skipDefaultCheckout(true)
    }

    parameters {
        string(
            name: 'DOCKERHUB_NAMESPACE',
            defaultValue: 'willyddn',
            description: 'Votre namespace/identifiant DockerHub (les dépôts cast-service et movie-service doivent exister ou être créables).'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true
                    ).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('Validate configuration') {
            steps {
                script {
                    if (!(params.DOCKERHUB_NAMESPACE ==~ /[a-z0-9]+([._-][a-z0-9]+)*/)) {
                        error('Définissez le paramètre DOCKERHUB_NAMESPACE avec un identifiant DockerHub valide.')
                    }
                }
                sh 'helm lint ./charts'
            }
        }

        stage('Build and push images') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKERHUB_USERNAME',
                    passwordVariable: 'DOCKERHUB_PASSWORD'
                )]) {
                    sh '''
                        set -eu
                        trap 'docker logout >/dev/null 2>&1 || true' EXIT
                        echo "$DOCKERHUB_PASSWORD" | docker login \
                          --username "$DOCKERHUB_USERNAME" --password-stdin

                        docker build --pull \
                          --tag "docker.io/${DOCKERHUB_NAMESPACE}/cast-service:${IMAGE_TAG}" \
                          ./cast-service
                        docker build --pull \
                          --tag "docker.io/${DOCKERHUB_NAMESPACE}/movie-service:${IMAGE_TAG}" \
                          ./movie-service
                        docker push "docker.io/${DOCKERHUB_NAMESPACE}/cast-service:${IMAGE_TAG}"
                        docker push "docker.io/${DOCKERHUB_NAMESPACE}/movie-service:${IMAGE_TAG}"
                    '''
                }
            }
        }

        stage('Deploy dev') {
            steps {
                script {
                    deployEnvironment('dev')
                }
            }
        }

        stage('Deploy QA') {
            when {
                branch 'master'
            }
            steps {
                script {
                    deployEnvironment('qa')
                }
            }
        }

        stage('Deploy staging') {
            when {
                branch 'master'
            }
            steps {
                script {
                    deployEnvironment('staging')
                }
            }
        }

        stage('Production approval and deployment') {
            when {
                branch 'master'
            }
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    input(
                        message: "Déployer l'image ${env.IMAGE_TAG} en production ?",
                        ok: 'Déployer en production'
                    )
                }
                script {
                    deployEnvironment('prod')
                }
            }
        }
    }
}
