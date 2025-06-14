#!/bin/bash

umask 077
set -uo pipefail

RUN_PATH=`pwd`
EXE_PATH=`dirname "${0}"`
EXE_NAME=`basename "${0}"`
cd "${EXE_PATH}"
EXE_PATH=`pwd`

# エラー通知スクリプト
# SMART監視システムでエラー発生時に呼び出される

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

echo "===============================================" >&2
echo "🚨 SMART監視システムエラー - $TIMESTAMP" >&2
echo "ホスト: $HOSTNAME" >&2
echo "===============================================" >&2
echo "SMART監視システムでエラーが発生しました。" >&2
echo "" >&2
echo "ログファイル確認:" >&2
echo "tail -50 logs/smart_checker.log" >&2
echo "" >&2
echo "システム状態確認:" >&2
echo "python3 cli.py status" >&2
echo "" >&2
echo "推奨アクション:" >&2
echo "1. ログファイルでエラー詳細を確認" >&2
echo "2. 必要に応じてシステム再起動" >&2
echo "3. 設定ファイル（settings.json）を確認" >&2
echo "===============================================" >&2

# システムログにも記録
logger "SMART System Error: Monitoring system encountered an error on $HOSTNAME"