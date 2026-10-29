# deploy.ps1 - push files/ overlay to the lab router (keeps its UCI config unless -Config)
param([switch]$Config)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$ex = @()
if (-not $Config) { $ex = @('--exclude=./etc/config/aether') }
$tarfile = Join-Path $root 'deploy.tmp.tar'
& tar -cf $tarfile @ex -C files .
cmd /c "ssh -o BatchMode=yes root@192.168.1.15 `"tar -xf - -C / && chmod 755 /usr/bin/aether-ctl /usr/bin/aether-run /usr/bin/aether-watchdog /etc/init.d/aether /usr/libexec/rpcd/luci-app-aether && chmod 600 /etc/config/aether && rm -f /tmp/luci-indexcache && rm -rf /tmp/luci-modulecache && /etc/init.d/rpcd restart && /etc/init.d/uhttpd restart`" < `"$tarfile`""
Remove-Item $tarfile
