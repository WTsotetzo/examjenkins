param(
    [string]$ContextName
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceConfig = Join-Path $HOME '.kube\config'
$targetConfig = Join-Path $repositoryRoot '.jenkins-kubeconfig'

if (-not (Test-Path $sourceConfig)) {
    throw "Kubeconfig introuvable : $sourceConfig"
}

$contextArguments = @()
if ($ContextName) {
    $contextArguments = @('--context', $ContextName)
} else {
    $ContextName = (& kubectl --kubeconfig $sourceConfig config current-context).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw 'Impossible de lire le contexte Kubernetes courant.'
    }
}

$currentContext = $ContextName
$server = (& kubectl --kubeconfig $sourceConfig @contextArguments config view --minify `
    -o jsonpath='{.clusters[0].cluster.server}').Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Impossible de lire l’URL du cluster Kubernetes.'
}
if (-not $server) {
    throw 'L’URL du cluster Kubernetes est vide.'
}

$serverUri = [uri]$server
$allowedHosts = @('127.0.0.1', 'localhost', 'kubernetes.docker.internal')
if ($serverUri.Host -notin $allowedHosts) {
    throw "Le cluster ($($serverUri.Host)) n'est pas un endpoint local pris en charge."
}

$contextCluster = (& kubectl --kubeconfig $sourceConfig @contextArguments config view --minify `
    -o jsonpath='{.contexts[0].context.cluster}').Trim()
if ($LASTEXITCODE -ne 0 -or -not $contextCluster) {
    throw 'Impossible de déterminer le nom du cluster du contexte courant.'
}

$yaml = & kubectl --kubeconfig $sourceConfig @contextArguments config view --minify --raw --flatten -o yaml
if ($LASTEXITCODE -ne 0) {
    throw 'Impossible de produire une copie autonome du kubeconfig.'
}
$yaml | Set-Content -Path $targetConfig -Encoding ASCII
if ($LASTEXITCODE -ne 0) {
    throw 'Impossible d’écrire le kubeconfig préparé.'
}

$env:KUBECONFIG = $targetConfig
$dockerServer = "https://host.docker.internal:$($serverUri.Port)"
$tlsServerName = $serverUri.Host
if ($tlsServerName -eq '127.0.0.1') {
    $tlsServerName = 'localhost'
}
& kubectl --kubeconfig $targetConfig config set-cluster $contextCluster `
    --server=$dockerServer --tls-server-name=$tlsServerName
if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $targetConfig -Force -ErrorAction SilentlyContinue
    throw 'Impossible de configurer le kubeconfig pour le réseau Docker.'
}

Write-Output "Kubeconfig préparé pour le contexte '$currentContext' : $targetConfig"
Write-Output 'Ce fichier contient des clés privées. Ne le publiez pas et téléversez-le dans Jenkins comme credential de type Secret file.'
