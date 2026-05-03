# Minecraft Server Setup — Codespaces

Instalador automatizado de servidor Minecraft + CraftControl + Playit.gg para GitHub Codespaces (Ubuntu).

## Comando único de instalação

```bash
bash <(curl -sL https://raw.githubusercontent.com/mainedgaro/minecraft-server-setup/refs/heads/main/setup_server.sh)
```

> Substitua `SEU_USUARIO` e `SEU_REPOSITORIO` pelo seu usuário e nome do repo no GitHub.

---

## O que é instalado

| Componente | Descrição |
|---|---|
| Java 21 | Runtime obrigatório para Minecraft |
| Python 3 + distro | Dependência do painel CraftControl |
| CraftControl | Painel web de gerenciamento do servidor |
| Playit.gg | Túnel para jogar com amigos sem portforward |

---

## Após a instalação

### Iniciar o painel

```bash
bash /workspaces/servidor/start_panel.sh
```

### Iniciar o túnel Playit.gg

```bash
playit
```

Acesse **https://playit.gg/claim** e cole o código exibido no terminal para vincular sua conta.

---

## Estrutura do repositório

```
.
├── setup_server.sh   ← script principal de instalação
└── README.md         ← este arquivo
```

## Log de instalação

Tudo é registrado automaticamente em `/workspaces/servidor/setup.log`.

```bash
cat /workspaces/servidor/setup.log
```

---

## Executar novamente (idempotente)

O script é seguro para executar mais de uma vez. Ele verifica o que já está instalado e pula as etapas concluídas.

```bash
bash <(curl -sL https://raw.githubusercontent.com/mainedgaro/minecraft-server-setup/refs/heads/main/setup_server.sh)
```
