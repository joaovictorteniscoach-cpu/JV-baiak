# Abre o cliente do PC (o mesmo .zip do site) numa maquina Windows de verdade,
# entra com a conta de teste e tira fotos da tela.
# Uso: windows_cliente.ps1 <pasta-com-zip-e-conta.json> <pasta-fotos>
param([string]$Pasta, [string]$Fotos)
$ErrorActionPreference = "Continue"
New-Item -ItemType Directory -Force -Path $Fotos | Out-Null
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$wsh = New-Object -ComObject WScript.Shell
$script:n = 0
function Foto([string]$nome) {
	$script:n++
	$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
	$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
	$bmp.Save((Join-Path $Fotos ("{0:D2}-{1}.png" -f $script:n, $nome)), [System.Drawing.Imaging.ImageFormat]::Png)
	$g.Dispose(); $bmp.Dispose()
}
function Teclas([string]$t) { [System.Windows.Forms.SendKeys]::SendWait($t); Start-Sleep -Milliseconds 300 }

$conta = Get-Content (Join-Path $Pasta "conta.json") | ConvertFrom-Json
$zip = Get-ChildItem $Pasta -Filter *-Windows.zip | Select-Object -First 1
"zip: $($zip.Name) ($([math]::Round($zip.Length/1MB,1)) MB)" | Tee-Object -FilePath (Join-Path $Fotos "resultado.txt")
$dest = Join-Path $env:RUNNER_TEMP "cliente"
Expand-Archive $zip.FullName -DestinationPath $dest -Force
$pastaCli = Get-ChildItem $dest -Directory | Select-Object -First 1
$resolucao = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
"tela do Windows: $($resolucao.Width)x$($resolucao.Height)" | Add-Content (Join-Path $Fotos "resultado.txt")

foreach ($exe in @("otclient_dx.exe", "otclient_gl.exe")) {
	$p = Start-Process -FilePath (Join-Path $pastaCli.FullName $exe) -WorkingDirectory $pastaCli.FullName -PassThru
	Start-Sleep -Seconds 25
	$vivo = -not $p.HasExited
	"$exe aberto depois de 25 s: $vivo" | Add-Content (Join-Path $Fotos "resultado.txt")
	Foto "$exe-abriu"
	if ($vivo) { break }
}
if ($p.HasExited) { "o cliente fechou sozinho" | Add-Content (Join-Path $Fotos "resultado.txt"); exit 1 }

$wsh.AppActivate($p.Id) | Out-Null
Start-Sleep -Seconds 2
# fecha qualquer aviso inicial e preenche o login (o campo da conta ja vem com foco)
Teclas $conta.conta
Teclas "{TAB}"
Teclas $conta.senha
Foto "login-preenchido"
Teclas "{ENTER}"
Start-Sleep -Seconds 10
Foto "depois-do-login"
Teclas "{ENTER}"
Start-Sleep -Seconds 3
Foto "lista-de-personagens"
Teclas "{ENTER}"
Start-Sleep -Seconds 15
Foto "entrou-no-jogo"
Teclas "{ESC}"
foreach ($t in @("{RIGHT}", "{RIGHT}", "{LEFT}", "{LEFT}", "{DOWN}", "{UP}")) { Teclas $t; Start-Sleep -Milliseconds 500 }
Start-Sleep -Seconds 2
Foto "depois-de-andar"
Teclas "oi robo do pc{ENTER}"
Start-Sleep -Seconds 2
Foto "falou-oi"
"cliente ainda aberto no fim: $(-not $p.HasExited)" | Add-Content (Join-Path $Fotos "resultado.txt")
Get-ChildItem -Path $pastaCli.FullName, $env:APPDATA -Recurse -Include *.log -ErrorAction SilentlyContinue |
	Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) } |
	ForEach-Object { Copy-Item $_.FullName (Join-Path $Fotos ("log-" + $_.Name)) }
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
