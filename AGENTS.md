# AGENTS.md

## Escopo

Este arquivo existe para reduzir drift operacional quando o `cwd` estiver em `C:\www\you-obd-lab-plugin`.

Fontes principais deste repo:

- `README.md`
- `WORKSPACE.md`
- `docs/`
- `skills/`
- `.codex-plugin/`

## Regras minimas

- Trabalhar em portugues do Brasil.
- Editar o plugin nesta workspace, nao no diretorio interno do Codex, exceto manutencao emergencial.
- Usar `README.md` para onboarding rapido e `WORKSPACE.md` para lembrar a relacao entre workspace e destino ativo do Codex.
- Quando o usuario mencionar `@you-obd-lab`, usar o workflow real multi-agente por padrao:
  - `you-orchestrator` primeiro
  - especialistas so conforme o escopo
  - `you-reviewer` antes do sign-off em mudanca nao trivial

## Modelo operacional

- `gpt-5.4` continua como autoridade para orquestracao, contratos, arbitragem e veredito final
- LLM local via Ollama entra apenas como apoio operacional
- conclusao de LM local nunca substitui revisao final do `gpt-5.4`

## Fechamento natural da rodada

O plugin deve resolver pendencias operacionais de forma natural quando isso fizer parte do escopo autorizado.

Antes de declarar fechamento, verificar:

1. Existe `git commit` e `git push` pendente em algum repo tocado pela rodada?
2. Existe `supabase db push` ou verificacao remota pendente para migrations?
3. Existe sincronizacao pendente entre plugin, app e simulador?

Se a resposta for sim e houver autorizacao do Owner:

- concluir a sincronizacao necessaria
- declarar no fechamento o que foi aplicado localmente e remotamente

Se nao houver autorizacao:

- nao executar `push` ou deploy
- deixar a pendencia explicita no handoff final

## Repos do laboratorio

Quando a rodada tocar o ecossistema YOU, tratar estes repos como fronteiras explicitas:

- `C:\www\YouAutoCarvAPP2`
- `C:\www\YouSimuladorOBD`
- `C:\www\you-obd-lab-plugin`

Nao deixar contratos, rollout ou sincronizacao pela metade sem registrar ownership, risco e proximo owner.
