$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceConfig = Join-Path $HOME '.kube\config'
$targetConfig = Join-Path $repositoryRoot '.jenkins-kubeconfig'

if (-not (Test-Path $sourceConfig)) {
    throw "Kubeconfig introuvable : $sourceConfig"
}

$currentContext = (& kubectl --kubeconfig $sourceConfig config current-context).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Impossible de lire le contexte Kubernetes courant.'
}

$server = (& kubectl --kubeconfig $sourceConfig config view --minify `
    -o jsonpath='{.clusters[0].cluster.server}').Trim()
if ($LASTEXITCODE -ne 0 -or -not $server) {
    throw 'Impossible de lire l’URL du cluster Kubernetes.'
}

$serverUri = [uri]$server
if ($serverUri.Host -ne '127.0.0.1' -and $serverUri.Host -ne 'localhost') {
    throw "Le cluster ($($serverUri.Host)) n'est pas exposé sur la boucle locale. Préparez son accès réseau depuis Docker avant d'utiliser ce script."
}

$contextCluster = (& kubectl --kubeconfig $sourceConfig config view --minify `
    -o jsonpath='{.contexts[0].context.cluster}').Trim()
if ($LASTEXITCODE -ne 0 -or -not $contextCluster) {
    throw 'Impossible de déterminer le nom du cluster du contexte courant.'
}

$yaml = & kubectl --kubeconfig $sourceConfig config view --minify --raw --flatten -o yaml
if ($LASTEXITCODE -ne 0) {
    throw 'Impossible de produire une copie autonome du kubeconfig.'
}
$yaml | Set-Content -Path $targetConfig -Encoding ASCII
if ($LASTEXITCODE -ne 0) {
    throw 'Impossible d’écrire le kubeconfig préparé.'
}

$env:KUBECONFIG = $targetConfig
$dockerServer = "https://host.docker.internal:$($serverUri.Port)"
& kubectl --kubeconfig $targetConfig config set-cluster $contextCluster `
    --server=$dockerServer --tls-server-name=127.0.0.1
if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $targetConfig -Force -ErrorAction SilentlyContinue
    throw 'Impossible de configurer le kubeconfig pour le réseau Docker.'
}

Write-Output "Kubeconfig préparé pour le contexte '$currentContext' : $targetConfig"
Write-Output 'Ce fichier contient des clés privées. Ne le publiez pas et téléversez-le dans Jenkins comme credential de type Secret file.'
