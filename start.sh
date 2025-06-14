#!/bin/bash

umask 077
set -uo pipefail

RUN_PATH=`pwd`
EXE_PATH=`dirname "${0}"`
EXE_NAME=`basename "${0}"`
cd "${EXE_PATH}"
EXE_PATH=`pwd`

# ログ設定
LOG_FILE="logs/smart_checker.log"
mkdir -p "$(dirname "$LOG_FILE")"

# 設定ファイル確認
if [ ! -f "settings.json" ]; then
    echo "エラー: settings.jsonが見つかりません" >&2
    echo "settings.json.templateからコピーして設定してください:" >&2
    echo "  cp settings.json.template settings.json" >&2
    echo "  vi settings.json" >&2
    exit 101
fi

# Pythonバージョン確認
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1)
    if [ "$PYTHON_VERSION" = "3" ]; then
        PYTHON_CMD="python"
    fi
fi

if [ -z "$PYTHON_CMD" ]; then
    echo "エラー: Python 3が見つかりません" >&2
    exit 102
fi

# 必要なPythonパッケージ確認
echo "必要なパッケージを確認中..." >&2
if ! $PYTHON_CMD -c "import requests" 2>/dev/null; then
    echo "警告: requestsパッケージがインストールされていません" >&2
    echo "インストールコマンド: pip install requests" >&2
    echo "続行しますが、LLM分析は動作しません" >&2
fi

# smartctlコマンド確認
if ! command -v smartctl >/dev/null 2>&1; then
    echo "エラー: smartctlコマンドが見つかりません" >&2
    echo "smartmontoolsをインストールしてください:" >&2
    echo "  Ubuntu/Debian: sudo apt install smartmontools" >&2
    echo "  CentOS/RHEL: sudo yum install smartmontools" >&2
    exit 103
fi

# sudo権限確認
if ! sudo -n smartctl --version >/dev/null 2>&1; then
    echo "警告: sudoでsmartctlを実行できません" >&2
    echo "以下の設定を/etc/sudoersに追加することを推奨します:" >&2
    echo "  $(whoami) ALL=(ALL) NOPASSWD: /usr/sbin/smartctl" >&2
    echo "または:" >&2
    echo "  %$(id -gn) ALL=(ALL) NOPASSWD: /usr/sbin/smartctl" >&2
fi

# データディレクトリ作成
mkdir -p data/smart

echo "SMART監視システムを開始します..." >&2
echo "ログファイル: $LOG_FILE" >&2
echo "設定ファイル: settings.json" >&2
echo "データディレクトリ: data/smart" >&2
echo "" >&2

# メイン処理実行
exec $PYTHON_CMD main.py 2>&1 | tee -a "$LOG_FILE"