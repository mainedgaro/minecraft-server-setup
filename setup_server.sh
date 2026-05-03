#!/bin/bash
# ==============================================================================
#  setup_server.sh
#  Instalador automatizado de Servidor Minecraft + CraftControl + Playit.gg
#  Ambiente alvo: GitHub Codespaces (Ubuntu)
#  Autor: gerado com assistência de Claude (Anthropic)
# ==============================================================================

set -e          # Interrompe o script imediatamente em caso de erro
set -u          # Trata variáveis não definidas como erro
set -o pipefail # Propaga erros em pipelines (ex: cmd1 | cmd2)

# ==============================================================================
# CONSTANTES E CONFIGURAÇÕES
# ==============================================================================

readonly WORK_DIR="/workspaces/servidor"
readonly MINECRAFT_DIR="${WORK_DIR}/Minecraft"
readonly PANEL_ZIP="${WORK_DIR}/panel.zip"
readonly START_PANEL="${WORK_DIR}/start_panel.sh"
readonly LOG_FILE="${WORK_DIR}/setup.log"

readonly PANEL_RELEASE_URL="https://github.com/craftcontrol/panel/releases/latest/download/panel-linux.zip"
readonly CRAFTCONTROL_INSTALL_URL="https://craftcontrol.com/install.sh"
readonly PLAYIT_GPG_URL="https://playit-cloud.github.io/ppa/key.gpg"
readonly PLAYIT_CLAIM_URL="https://playit.gg/claim"

# ==============================================================================
# PALETA DE CORES
# ==============================================================================

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_MAGENTA='\033[0;35m'
C_WHITE='\033[1;37m'

# ==============================================================================
# FUNÇÕES DE LOG E SAÍDA
# ==============================================================================

# Registra tudo que aparece no terminal também no arquivo de log
exec > >(tee -a "${LOG_FILE}") 2>&1

_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log_info()    { echo -e "${C_BLUE}[INFO]${C_RESET}  $(_timestamp) — $*"; }
log_ok()      { echo -e "${C_GREEN}[OK]${C_RESET}    $(_timestamp) — $*"; }
log_warn()    { echo -e "${C_YELLOW}[AVISO]${C_RESET} $(_timestamp) — $*"; }
log_erro()    { echo -e "${C_RED}[ERRO]${C_RESET}  $(_timestamp) — $*" >&2; }
log_passo()   { echo -e "\n${C_BOLD}${C_CYAN}══► $*${C_RESET}"; }

banner() {
  echo -e "${C_CYAN}"
  cat <<'BANNER'
  ██████╗ ███████╗████████╗██╗   ██╗██████╗
  ██╔══██╗██╔════╝╚══██╔══╝██║   ██║██╔══██╗
  ██████╔╝███████╗   ██║   ██║   ██║██████╔╝
  ██╔═══╝ ╚════██║   ██║   ██║   ██║██╔═══╝
  ██║     ███████║   ██║   ╚██████╔╝██║
  ╚═╝     ╚══════╝   ╚═╝    ╚═════╝ ╚═╝
    Minecraft + CraftControl + Playit.gg
    Ambiente: GitHub Codespaces (Ubuntu)
BANNER
  echo -e "${C_RESET}"
}

# ==============================================================================
# FUNÇÕES UTILITÁRIAS
# ==============================================================================

# Verifica se um comando existe no PATH
cmd_existe() { command -v "$1" &>/dev/null; }

# Verifica se um pacote apt está instalado
pkg_instalado() { dpkg -s "$1" &>/dev/null 2>&1; }

# Verifica se um pacote Python está instalado
pip_instalado() { python3 -c "import $1" &>/dev/null 2>&1; }

# Garante que um diretório existe
garantir_dir() {
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
    log_ok "Diretório criado: $1"
  else
    log_info "Diretório já existe: $1 — ignorando."
  fi
}

# ==============================================================================
# VERIFICAÇÕES PRÉ-INSTALAÇÃO
# ==============================================================================

verificar_ambiente() {
  log_passo "Verificando ambiente de execução..."

  # Confirma que estamos em um ambiente Ubuntu/Debian
  if [ ! -f /etc/debian_version ]; then
    log_erro "Este script requer Ubuntu/Debian. Sistema atual não é compatível."
    exit 1
  fi

  # Confirma acesso à internet com timeout rápido
  if ! curl -s --max-time 5 https://github.com > /dev/null; then
    log_erro "Sem acesso à internet. Verifique sua conexão antes de continuar."
    exit 1
  fi

  # Cria o diretório de trabalho raiz e de log
  garantir_dir "${WORK_DIR}"

  log_ok "Ambiente verificado. Ubuntu detectado. Internet acessível."
}

# ==============================================================================
# ETAPA 1 — ATUALIZAÇÃO DO SISTEMA
# ==============================================================================

atualizar_sistema() {
  log_passo "ETAPA 1/6 — Atualizando o sistema..."

  # Evita prompts interativos durante o upgrade
  export DEBIAN_FRONTEND=noninteractive

  log_info "Executando apt update..."
  sudo apt update -qq

  log_info "Executando apt upgrade..."
  sudo apt upgrade -y -qq

  log_ok "Sistema atualizado com sucesso."
}

# ==============================================================================
# ETAPA 2 — DEPENDÊNCIAS BASE
# ==============================================================================

instalar_dependencias() {
  log_passo "ETAPA 2/6 — Instalando dependências base..."

  local pkgs=(
    "curl"
    "wget"
    "unzip"
    "screen"
    "python3"
    "python3-pip"
    "openjdk-21-jdk-headless"
  )

  for pkg in "${pkgs[@]}"; do
    if pkg_instalado "$pkg"; then
      log_info "Pacote '${pkg}' já instalado — pulando."
    else
      log_info "Instalando '${pkg}'..."
      sudo apt install -y -qq "$pkg"
      log_ok "'${pkg}' instalado."
    fi
  done

  # Dependência Python: distro
  if pip_instalado "distro"; then
    log_info "Módulo Python 'distro' já instalado — pulando."
  else
    log_info "Instalando módulo Python 'distro'..."
    pip install distro --quiet --break-system-packages
    log_ok "Módulo Python 'distro' instalado."
  fi
}

# ==============================================================================
# ETAPA 3 — CRAFTCONTROL
# ==============================================================================

instalar_craftcontrol() {
  log_passo "ETAPA 3/6 — Instalando CraftControl..."

  # Idempotência: verifica se o instalador já foi executado
  if cmd_existe craftcontrol; then
    log_info "CraftControl já instalado — pulando instalação do agente."
  else
    log_info "Executando instalador oficial do CraftControl..."
    curl -sL "${CRAFTCONTROL_INSTALL_URL}" | sudo bash
    log_ok "Agente CraftControl instalado."
  fi
}

# ==============================================================================
# ETAPA 4 — PAINEL CRAFTCONTROL
# ==============================================================================

configurar_painel() {
  log_passo "ETAPA 4/6 — Configurando painel CraftControl..."

  garantir_dir "${MINECRAFT_DIR}"

  # Verifica se o painel já foi descompactado (idempotência)
  if [ -f "${MINECRAFT_DIR}/main.py" ]; then
    log_info "Painel já configurado em ${MINECRAFT_DIR} — pulando download."
    return
  fi

  log_info "Baixando panel-linux.zip da release mais recente..."
  curl -L --progress-bar \
       "${PANEL_RELEASE_URL}" \
       -o "${PANEL_ZIP}"

  log_info "Descompactando painel em ${MINECRAFT_DIR}..."
  unzip -q "${PANEL_ZIP}" -d "${MINECRAFT_DIR}"
  rm -f "${PANEL_ZIP}"

  # Torna executável o script principal, se existir
  if [ -f "${MINECRAFT_DIR}/main.py" ]; then
    chmod +x "${MINECRAFT_DIR}/main.py"
    log_ok "Painel descompactado e configurado em ${MINECRAFT_DIR}."
  else
    # O zip pode conter um subdiretório — tenta encontrar main.py
    local main_encontrado
    main_encontrado=$(find "${MINECRAFT_DIR}" -name "main.py" -maxdepth 3 | head -n 1 || true)

    if [ -n "$main_encontrado" ]; then
      # Move tudo para o nível correto
      local subdir
      subdir=$(dirname "$main_encontrado")
      mv "${subdir}"/* "${MINECRAFT_DIR}/" 2>/dev/null || true
      rmdir "$subdir" 2>/dev/null || true
      chmod +x "${MINECRAFT_DIR}/main.py"
      log_ok "Painel encontrado em subdiretório e movido para ${MINECRAFT_DIR}."
    else
      log_warn "main.py não encontrado após extração. O painel pode ter estrutura diferente."
      log_warn "Verifique manualmente o conteúdo de ${MINECRAFT_DIR}."
    fi
  fi
}

# ==============================================================================
# ETAPA 5 — PLAYIT.GG
# ==============================================================================

instalar_playit() {
  log_passo "ETAPA 5/6 — Instalando Playit.gg..."

  # Idempotência: verifica se já está instalado
  if cmd_existe playit; then
    log_info "Playit.gg já instalado — pulando."
    return
  fi

  # 5.1 — Adiciona chave GPG
  log_info "Adicionando chave GPG do Playit.gg..."
  curl -SsL "${PLAYIT_GPG_URL}" \
    | gpg --dearmor \
    | sudo tee /etc/apt/trusted.gpg.d/playit.gpg > /dev/null
  log_ok "Chave GPG adicionada."

  # 5.2 — Adiciona repositório APT
  log_info "Configurando repositório APT do Playit.gg..."
  echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" \
    | sudo tee /etc/apt/sources.list.d/playit-cloud.list > /dev/null
  log_ok "Repositório adicionado."

  # 5.3 — Instala o pacote
  log_info "Atualizando lista de pacotes e instalando playit..."
  sudo apt update -qq
  sudo apt install -y -qq playit
  log_ok "Playit.gg instalado com sucesso."
}

# ==============================================================================
# ETAPA 6 — CRIAR ATALHO start_panel.sh
# ==============================================================================

criar_atalho_painel() {
  log_passo "ETAPA 6/6 — Criando atalho start_panel.sh..."

  # Descobre o caminho real do main.py
  local main_py="${MINECRAFT_DIR}/main.py"

  if [ ! -f "$main_py" ]; then
    # Tenta localizar dinamicamente
    local encontrado
    encontrado=$(find "${MINECRAFT_DIR}" -name "main.py" -maxdepth 3 | head -n 1 || true)
    if [ -n "$encontrado" ]; then
      main_py="$encontrado"
    else
      log_warn "main.py não localizado. O atalho apontará para o caminho padrão."
      main_py="${MINECRAFT_DIR}/main.py"
    fi
  fi

  # Cria o script de atalho
  cat > "${START_PANEL}" <<ATALHO
#!/bin/bash
# -------------------------------------------------------
# start_panel.sh — Atalho para iniciar o painel CraftControl
# Gerado automaticamente por setup_server.sh
# -------------------------------------------------------

echo -e "\033[0;32m[CraftControl]\033[0m Iniciando painel..."
sudo python3 ${main_py} "\$@"
ATALHO

  chmod +x "${START_PANEL}"
  log_ok "Atalho criado em: ${START_PANEL}"
}

# ==============================================================================
# MENSAGEM FINAL
# ==============================================================================

mensagem_final() {
  local ip_local
  ip_local=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

  echo ""
  echo -e "${C_BOLD}${C_MAGENTA}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "${C_BOLD}${C_MAGENTA}║          INSTALAÇÃO CONCLUÍDA COM SUCESSO!                   ║${C_RESET}"
  echo -e "${C_BOLD}${C_MAGENTA}╚══════════════════════════════════════════════════════════════╝${C_RESET}"

  echo ""
  echo -e "${C_BOLD}${C_WHITE}  DIRETÓRIOS${C_RESET}"
  echo -e "  ${C_CYAN}Trabalho:${C_RESET}   ${WORK_DIR}"
  echo -e "  ${C_CYAN}Minecraft:${C_RESET}  ${MINECRAFT_DIR}"
  echo -e "  ${C_CYAN}Log setup:${C_RESET}  ${LOG_FILE}"

  echo ""
  echo -e "${C_BOLD}${C_WHITE}  COMO INICIAR${C_RESET}"
  echo -e "  ${C_YELLOW}Painel CraftControl:${C_RESET}"
  echo -e "  ${C_GREEN}  bash ${START_PANEL}${C_RESET}"
  echo -e "  ${C_YELLOW}Playit.gg (tunnel):${C_RESET}"
  echo -e "  ${C_GREEN}  playit${C_RESET}"

  echo ""
  echo -e "${C_BOLD}${C_WHITE}  PRÓXIMO PASSO — VINCULAR SUA CONTA PLAYIT.GG${C_RESET}"
  echo -e "  ${C_YELLOW}1.${C_RESET} Execute no terminal:  ${C_GREEN}playit${C_RESET}"
  echo -e "  ${C_YELLOW}2.${C_RESET} Acesse o link abaixo e cole o código exibido:"
  echo ""
  echo -e "  ${C_BOLD}${C_GREEN}  ➜  ${PLAYIT_CLAIM_URL}${C_RESET}"
  echo ""
  echo -e "  ${C_YELLOW}3.${C_RESET} Após vincular, seu endereço público aparecerá no terminal."
  echo -e "  ${C_YELLOW}4.${C_RESET} Compartilhe esse endereço com seus amigos para conectarem."
  echo ""
  echo -e "${C_BOLD}${C_MAGENTA}══════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
}

# ==============================================================================
# MAIN — ORQUESTRAÇÃO
# ==============================================================================

main() {
  banner
  log_info "Iniciando setup. Log salvo em: ${LOG_FILE}"
  echo ""

  verificar_ambiente
  atualizar_sistema
  instalar_dependencias
  instalar_craftcontrol
  configurar_painel
  instalar_playit
  criar_atalho_painel
  mensagem_final
}

main
