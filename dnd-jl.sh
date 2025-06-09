#!/bin/bash

# 🌈🐱 Welcome Banner (修正彩色打印，不再输出 e[xxm）
echo -e "\e[1;35m"
cat << EOF
┌─────────────────────────────────────────────┐
│  $(echo -e "\e[1;36m  ____        _                _       _     \e[1;35m")│
│  $(echo -e "\e[1;36m |  _ \\  __ _| |_ ___  ___  __| | __ _| |__  \e[1;35m")│
│  $(echo -e "\e[1;36m | | | |/ _\` | __/ _ \\/ _ \\/ _\` |/ _\` | '_ \\ \e[1;35m")│
│  $(echo -e "\e[1;36m | |_| | (_| | ||  __/  __/ (_| | (_| | | | | \e[1;35m")│
│  $(echo -e "\e[1;36m |____/ \\__,_|\\__\\___|\\___|\\__,_|\\__,_|_| |_| \e[1;35m")│
│      $(echo -e "\e[1;33mDaNaoDai 🐾  JupyterLab 自动安装器    \e[1;35m")│
└─────────────────────────────────────────────┘
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
  # 检查 ufw 是否安装
  if command -v ufw >/dev/null 2>&1; then
    # 检查是否启用
    ufw status | grep -qw active
    if [ $? -eq 0 ]; then
      # 检查端口是否已经放行
      ufw status | grep -q "$PORT"
      if [ $? -ne 0 ]; then
        echo -e "\e[1;34m[+] 检测到 ufw 已启用，自动放行端口 $PORT ...\e[0m"
        sudo ufw allow $PORT
      else
        echo -e "\e[1;32m端口 $PORT 已在 ufw 放行，无需重复操作。\e[0m"
      fi
    else
      echo -e "\e[1;33mufw 未启用，无需放行端口。\e[0m"
    fi
  else
    echo -e "\e[1;33m未检测到 ufw，无防火墙放行操作。\e[0m"
  fi
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
  # 自动添加到 /usr/local/bin/dnd-jl
  ln -sf "$(realpath "$0")" /usr/local/bin/dnd-jl && chmod +x /usr/local/bin/dnd-jl
  # 自动放行端口
  open_ufw_port
  echo -e "\n\e[1;32mJupyterLab 安装完成，可通过 dnd-jl 菜单启动。\e[0m"
}

function service_status() {
  echo -e "\e[1;36m──── 服务状态 ────\e[0m"
  if pgrep -af jupyter-lab > /dev/null; then
    echo -e "\e[1;32m正在运行\e[0m"
    # 状态查询时补充 IP:端口、token（公网 IP 只 curl 一次）
    PUBLIC_IP=$(get_cached_ip)
    source "$VENV_DIR/bin/activate"
    SERVER_LIST=$(jupyter server list 2>/dev/null)
    JLAB_URL=$(echo "$SERVER_LIST" | grep -oP 'http://\S+')
    TOKEN=$(echo "$JLAB_URL" | grep -oP 'token=\K[0-9a-f]+')
    if [[ -n "$JLAB_URL" && -n "$TOKEN" ]]; then
      ACCESS_URL="http://$PUBLIC_IP:$PORT/?token=$TOKEN"
      echo -e "公网访问地址: \e[1;33m$ACCESS_URL\e[0m"
    else
      echo -e "\e[1;31m未检测到 token 或 URL，可能未启动或日志丢失。\e[0m"
    fi
    echo -e "JupyterLab 日志: $JUPYTER_LOG"
  else
    echo -e "\e[1;31m未运行\e[0m"
  fi
}

function start_lab() {
  echo -e "\e[1;34m[+] 启动 JupyterLab...\e[0m"
  stop_lab
  open_ufw_port
  source "$VENV_DIR/bin/activate"
  nohup jupyter lab --ip=0.0.0.0 --port=$PORT --no-browser --allow-root > "$JUPYTER_LOG" 2>&1 &
  echo -e "\e[1;32m后台启动成功，日志在 $JUPYTER_LOG\e[0m"
}

function start_lab_interactive() {
  echo -e "\e[1;34m[+] 使用交互模式启动 JupyterLab（打印日志）...\e[0m"
  stop_lab
  open_ufw_port
  source "$VENV_DIR/bin/activate"
  jupyter lab --ip=0.0.0.0 --port=$PORT --no-browser --allow-root 2>&1 | tee "$JUPYTER_LOG"
}

function stop_lab() {
  echo -e "\e[1;34m[+] 停止 JupyterLab...\e[0m"
  pkill -f jupyter-lab
}

function enter_venv() {
  echo -e "\e[1;34m[+] 进入 Jupyter venv 环境，输入 \e[1;33mexit\e[0m \e[1;34m可退出。\e[0m"
  bash --rcfile <(echo "source $VENV_DIR/bin/activate")
}

function show_menu() {
  while true; do
    echo -e "\e[1;35m┌──────────────────────────────┐\e[0m"
    echo -e "\e[1;35m│        DaNaoDai 菜单         │\e[0m"
    echo -e "\e[1;35m└──────────────────────────────┘\e[0m"
    echo -e "\e[1;36m[1]\e[0m 安装 JupyterLab"
    echo -e "\e[1;36m[2]\e[0m 启动 JupyterLab"
    echo -e "\e[1;36m[3]\e[0m 停止 JupyterLab"
    echo -e "\e[1;36m[4]\e[0m 状态查询"
    echo -e "\e[1;36m[5]\e[0m 交互启动"
    echo -e "\e[1;36m[6]\e[0m 进入 venv 环境"
    echo -e "\e[1;36m[7]\e[0m 退出"
    read -p "请选择操作: " choice
    case $choice in
      1) install_all;;
      2) start_lab;;
      3) stop_lab;;
      4) service_status;;
      5) start_lab_interactive;;
      6) enter_venv;;
      7) exit;;
      *) echo "无效选项，请重新选择。";;
    esac
  done
}

show_menu
