FROM jenkins/jenkins:lts-jdk21

USER root

ARG DOCKER_CLI_VERSION=28.3.3
ARG KUBECTL_VERSION=v1.33.4
ARG HELM_VERSION=v3.19.0

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl tar \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" \
       | tar -xz -C /tmp \
    && install /tmp/docker/docker /usr/local/bin/docker \
    && rm -rf /tmp/docker \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
       -o /usr/local/bin/kubectl \
    && chmod 0755 /usr/local/bin/kubectl \
    && curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
       | tar -xz -C /tmp \
    && install /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /tmp/linux-amd64 \
    && usermod -aG root jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins
