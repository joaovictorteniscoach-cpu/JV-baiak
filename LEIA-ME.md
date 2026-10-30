# JV Baiak — kit do servidor

Servidor **Baiak 8.60** pronto para VPS, com cliente para **PC (Windows)** e **celular (Android)**.

## Instalação (VPS Ubuntu 22.04/24.04, x86_64 ou arm64, 4 GB+ de RAM)

```bash
curl -fsSL https://raw.githubusercontent.com/joaovictorteniscoach-cpu/JV-baiak/main/instalar.sh | sudo bash
```

Opcional, antes do comando: `NOME_SERVIDOR="Meu Baiak"` e `ENDERECO_SERVIDOR=1.2.3.4`.
O instalador pode ser rodado de novo para reparar ou atualizar: ele não apaga contas, personagens, mapa nem o `config.lua`.

## O que é instalado

| Serviço | O que faz | Porta |
|---|---|---|
| `servidor` | Baiak Thunder 8.60 (TFS 1.3) compilado do código-fonte, x86_64 ou arm64 | 7171, 7172 |
| `db` | MariaDB 10.11 (fechado para a internet) | — |
| `portal` | Site para criar conta e personagem, ranking e downloads | 80 |
| `clientes` | Ferramenta que gera o cliente Windows (.zip) e o APK Android | — |

Tudo fica em `/opt/jvbaiak`. Senhas aleatórias em `/opt/jvbaiak/.env`; conta GM em `/root/jvbaiak-credenciais.txt`.

## Fontes usadas (versões fixas)

| Item | Origem | Versão |
|---|---|---|
| Servidor + mapa Baiak | [moviebr/baiakthunder](https://github.com/moviebr/baiakthunder) | commit `265d458` |
| Cliente PC/Android | [OTCv8/otclientv8](https://github.com/OTCv8/otclientv8) | commit `aacfe3f` (SHA-256 conferido) |
| Sprites 8.60 | [vinisdl/tibia-client-860-linux](https://github.com/vinisdl/tibia-client-860-linux) | commit `9e896e2` (SHA-256 conferido) |
| Assinatura do APK | [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer) | v1.3.0 (SHA-256 conferido) |

## O que o JV Baiak muda no Baiak Thunder

- **Treino automático** (`servidor-imagem/extras/data/scripts/custom/treino_automatico.lua`): dentro das salas de trainers o servidor treina sozinho a skill da arma, shielding e magic level, sem bot e sem queda por inatividade. Comando `!treino`. Ajustes no topo do arquivo.
- **Patch C++** `patches/0001-player-resetIdleTime.patch`: adiciona `player:resetIdleTime()` ao Lua (usado pelo treino).
- **config.lua inicial**: `antiBot = false` (bot liberado), `freePremium = true`, `spoofEnabled = false`, IP, banco e nome.

## Jogar no iPhone (beta)

Não existe cliente 8.60 nativo para iOS. O kit tem um modo web experimental: HTTPS com Caddy, ponte WebSocket para as portas do jogo e o OTClient Redemption compilado em WebAssembly, servido em `https://<dominio>/jogar/`.

```bash
jvbaiak web meubaiak.duckdns.org SEU-TOKEN-DUCKDNS   # domínio grátis do duckdns.org
jvbaiak web-status                                   # acompanha a compilação (1 a 2 horas)
```

## Administração

`jvbaiak ajuda` lista tudo: `status`, `online`, `logs`, `reiniciar`, `backup`, `restaurar`, `gm`, `senha`, `config`, `clientes`, `endereco`.
Backup automático todo dia às 05:30 (14 dias guardados em `/opt/jvbaiak/backups`).

## Testes do kit

```bash
python3 testes/teste_portal.py                          # site (usa SQLite no lugar do MariaDB)
luajit testes/teste_treino.lua servidor-imagem/extras/data/scripts/custom/treino_automatico.lua
```

## Aviso sobre direitos

O mapa e os sprites derivam do Tibia, da CipSoft. Para uso pessoal o risco é baixo; ao abrir ao público, e principalmente ao cobrar (VIP/donate), há risco de derrubada. O caminho seguro a longo prazo é trocar nome, mapa e arte por conteúdo próprio.
