#!/bin/bash

# 🌈🐱 彩色 Banner 美化（字体自绘 DaNaoDai，边框全对齐）
echo -e "\e[1;35m"
cat << EOF
┌──────────────────────────────────────────────┐
│  $(echo -e "\e[1;36m ____        _   _               ____        _     _    \e[1;35m") │
│  $(echo -e "\e[1;36m|  _ \  __ _| |_| |__   ___ _ __|  _ \  __ _| |__ | |   \e[1;35m") │
│  $(echo -e "\e[1;36m| | | |/ _\` | __| '_ \ / _ \ '__| | | |/ _\` | '_ \| |   \e[1;35m") │
│  $(echo -e "\e[1;36m| |_| | (_| | |_| | | |  __/ |  | |_| | (_| | | | | |   \e[1;35m") │
│  $(echo -e "\e[1;36m|____/ \__,_|\__|_| |_|\___|_|  |____/ \__,_|_| |_|_|   \e[1;35m") │
│        $(echo -e "\e[1;33mDaNaoDai 🐾  JupyterLab 自动安装器     \e[1;35m")       │
└──────────────────────────────────────────────┘
EOF
echo -e "\e[0m"

# Default settings
INSTALL_DIR="$HOME/jupyterlab-dnd"
VENV_DIR="$INSTALL_DIR/venv"
PORT=8888
JUPYTER_LOG="$INSTALL_DIR/jupyterlab.log"
CACHE_IP_FILE="$INSTALL_DIR/.public_ip"

function get_cached_ip() {
  if [[ -f "$CACHE_IP_FILE" ]]; then
    cat "$CACHE_IP_FILE"
  else
    PUBLIC_IP=$(curl -s ifconfig.me)
    echo "$PUBLIC_IP" > "$CACHE_IP_FILE"
    echo "$PUBLIC_IP"
  fi
}

function open_ufw_port() {
  if command -v ufw >/dev/null 2>&1; then
    ufw status | grep -qw active
    if [ $? -eq 0 ]; then
      ufw status | grep -q "$PORT"
      if [ $? -ne 0 ]; then
        echo -e "\e[1;34m[+] 检测到 ufw 已启用，自动放行端口 $PORT ...\e[0m"
        sudo ufw allow $PORT
      fi
    fi
  fi
}

function setup_jupyter_password() {
  source "$VENV_DIR/bin/activate"
  echo -e "\e[1;35m\n>>> 设置/修改 JupyterLab 密码\e[0m"
  jupyter lab password
  echo -e "\e[1;32m密码设置完成，正在重启 JupyterLab 服务...\e[0m"
  stop_lab
  start_lab
}

function install_all() {
  echo -e "\e[1;34m[+] 安装依赖并配置 JupyterLab...\e[0m"
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "检测到有其他 apt/dpkg 进程正在运行，等待中..."
    sleep 5
  done
  sudo apt update && sudo apt install -y python3 python3-venv python3-pip curl net-tools git
  mkdir -p "$INSTALL_DIR"
  python3 -m venv "$VENV_DIR"
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip
  pip install jupyterlab jupyter-server jupyterlab-lsp
  ln -sf "$(realpath "$0")" /usr/local/bin/dnd-jl && chmod +x /usr/local/bin/dnd-jl
  open_ufw_port
  echo -e "\e[1;34m[+] 正在生成 JupyterLab 配置文件...\e[0m"
  jupyter lab --generate-config
  setup_jupyter_password
  echo -e "\n\e[1;32mJupyterLab 安装与配置已完成，可通过 dnd-jl 启动菜单。\e[0m"
}

function service_status() {
  if pgrep -af jupyter-lab > /dev/null; then
    echo -e "\e[1;32mJupyterLab 服务状态：运行中\e[0m"
    PUBLIC_IP=$(get_cached_ip)
    echo -e "公网访问地址: \e[1;33mhttp://$PUBLIC_IP:$PORT/\e[0m"
  else
    echo -e "\e[1;31mJupyterLab 服务状态：未运行\e[0m"
  fi
}

function start_lab() {
  stop_lab
  open_ufw_port
  source "$VENV_DIR/bin/activate"
  nohup jupyter lab --ip=0.0.0.0 --port=$PORT --no-browser --allow-root > "$JUPYTER_LOG" 2>&1 &
  echo -e "\e[1;32m后台启动成功，日志在 $JUPYTER_LOG\e[0m"
}

function start_lab_interactive() {
  stop_lab
  open_ufw_port
  source "$VENV_DIR/bin/activate"
  jupyter lab --ip=0.0.0.0 --port=$PORT --no-browser --allow-root 2>&1 | tee "$JUPYTER_LOG"
}

function stop_lab() {
  pkill -f jupyter-lab
}

function enter_venv() {
  echo -e "\e[1;34m[+] 进入 Jupyter venv 环境，输入 \e[1;33mexit\e[0m \e[1;34m可退出。\e[0m"
  bash --rcfile <(echo "source $VENV_DIR/bin/activate")
}

function show_menu() {
  while true; do
    echo -e "\e[1;35m┌───────────────────────────────────────┐\e[0m"
    echo -e "\e[1;35m│            DaNaoDai 菜单              │\e[0m"
    echo -e "\e[1;35m└───────────────────────────────────────┘\e[0m"
    echo -e "\e[1;36m[1]\e[0m 安装 JupyterLab"
    echo -e "\e[1;36m[2]\e[0m 启动 JupyterLab"
    echo -e "\e[1;36m[3]\e[0m 停止 JupyterLab"
    echo -e "\e[1;36m[4]\e[0m 状态查询"
    echo -e "\e[1;36m[5]\e[0m 交互启动"
    echo -e "\e[1;36m[6]\e[0m 进入 venv 环境"
    echo -e "\e[1;36m[7]\e[0m 修改 JupyterLab 密码"
    echo -e "\e[1;36m[8]\e[0m 退出"
    read -p "请选择操作: " choice
    case $choice in
      1) install_all;;
      2) start_lab;;
      3) stop_lab;;
      4) service_status;;
      5) start_lab_interactive;;
      6) enter_venv;;
      7) setup_jupyter_password;;
      8) exit;;
      *) echo "无效选项，请重新选择。";;
    esac
  done
}

# 检测是否是交互终端，防止 wget|bash 等方式死循环
if [ ! -t 0 ]; then
  echo "❌ 本脚本需要在交互式终端（如 bash dnd-jl.sh）运行，不支持管道或非交互执行。"
  exit 1
fi

show_menu
