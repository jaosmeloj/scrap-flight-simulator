# Scrap Flight Simulator

Jogo Roblox (projeto Rojo na raiz desta pasta). Dois desenvolvedores: **jotamelo123** (GitHub jaosmeloj) e
**TLordFelpps / Filippe** (GitHub amrl-writer). Fale em português do Brasil.

## Regras fixas
1. Código mora em arquivos (`src/`). Números ajustáveis em `src/shared/Config/`, regras puras em `src/shared/Rules/`
   (com testes em `tests/`), remotes só em `src/shared/Remotes.luau`, servidor é a autoridade.
2. Antes de dizer que algo está pronto: `rojo build -o build.rbxl`, `lune run run_tests`, `selene src`,
   `stylua --check src tests` (ferramentas em `rokit.toml`; no Bash: `export PATH="$PATH:$HOME/.rokit/bin"`).
3. **Nada de ninguém pode sumir.** Scripts vão para o Studio SÓ pela sincronização nos dois sentidos:
   `python tools/studio_sync.py` em segundo plano + no Studio (MCP execute_luau, Edit):
   `return loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8771/studio_sync.luau", true))()`.
   Rode no começo de cada pedido e depois de cada mudança de código. Conflito: a versão do Studio vai para
   `_studio_capturas/`; junte as duas e rode `python tools/studio_sync.py resolve <arquivo>`.
   Nunca copie arquivos por cima do Studio de outro jeito (foi isso que apagou trabalho).
4. Git: cada um trabalha numa branch própria (`trabalho/<nome>`), faz `git pull` antes de começar e commit + push
   ao terminar. A `main` só recebe o que os dois combinarem.

## Onde está o quê
- `PLANO.md`: plano do jogo. `assets/3d/cart_kit.py`: todos os modelos (Blender) num FBX só para o Import 3D.
- `tools/`: `progress.luau`, `curve.luau`, `gain.luau` (simulador de voo e progressão), `telemetry_server.py`
  (registro de voos do Studio), `studio_sync.py`.
