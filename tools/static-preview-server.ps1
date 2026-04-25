[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    [Parameter(Mandatory = $true)]
    [int]$Port
)

$ErrorActionPreference = "Stop"

$resolvedRoot = Resolve-Path -LiteralPath $Root -ErrorAction Stop
$rootPath = [System.IO.Path]::GetFullPath($resolvedRoot.Path)
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")

$contentTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm" = "text/html; charset=utf-8"
    ".css" = "text/css; charset=utf-8"
    ".js" = "text/javascript; charset=utf-8"
    ".mjs" = "text/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".svg" = "image/svg+xml"
    ".png" = "image/png"
    ".jpg" = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".webp" = "image/webp"
    ".ico" = "image/x-icon"
    ".txt" = "text/plain; charset=utf-8"
}

function Send-Text {
    param(
        [System.Net.HttpListenerContext]$Context,
        [int]$StatusCode,
        [string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = "text/plain; charset=utf-8"
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.Close()
}

try {
    $listener.Start()
    Write-Host "Static preview server listening on http://127.0.0.1:$Port/ from $rootPath" -ForegroundColor Green

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $requestPath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart("/"))
            if ([string]::IsNullOrWhiteSpace($requestPath)) {
                $requestPath = "index.html"
            }

            $targetPath = [System.IO.Path]::GetFullPath((Join-Path $rootPath $requestPath))
            if (!$targetPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                Send-Text -Context $context -StatusCode 403 -Text "Forbidden"
                continue
            }

            if ((Test-Path -LiteralPath $targetPath -PathType Container)) {
                $targetPath = Join-Path $targetPath "index.html"
            }

            if (!(Test-Path -LiteralPath $targetPath -PathType Leaf)) {
                Send-Text -Context $context -StatusCode 404 -Text "Not found"
                continue
            }

            $extension = [System.IO.Path]::GetExtension($targetPath).ToLowerInvariant()
            $contentType = if ($contentTypes.ContainsKey($extension)) { $contentTypes[$extension] } else { "application/octet-stream" }
            $bytes = [System.IO.File]::ReadAllBytes($targetPath)

            $context.Response.StatusCode = 200
            $context.Response.ContentType = $contentType
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $context.Response.Close()
        } catch {
            try {
                Send-Text -Context $context -StatusCode 500 -Text $_.Exception.Message
            } catch {
                $context.Response.Close()
            }
        }
    }
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
