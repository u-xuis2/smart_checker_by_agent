#!/bin/bash

umask 077
set -uo pipefail

RUN_PATH=`pwd`
EXE_PATH=`dirname "${0}"`
EXE_NAME=`basename "${0}"`
cd "${EXE_PATH}"
EXE_PATH=`pwd`

# アラート通知スクリプト
# SMART監視システムで異常検出時に呼び出される

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

echo "===============================================" >&2
echo "⚠️  SMART監視アラート - $TIMESTAMP" >&2
echo "ホスト: $HOSTNAME" >&2
echo "===============================================" >&2
echo "ハードディスク/SSDで異常が検出されました。" >&2
echo "詳細は分析結果ファイルを確認してください。" >&2
echo "" >&2
echo "最新の分析結果:" >&2
ls -la data/smart/*/analysis_*.json | tail -1 >&2
echo "" >&2
echo "推奨アクション:" >&2
echo "1. 重要データのバックアップを直ちに実行" >&2
echo "2. python3 cli.py history で履歴確認" >&2
echo "3. 必要に応じてディスク交換を検討" >&2
echo "===============================================" >&2

# システムログにも記録
logger "SMART Alert: Hard disk anomaly detected on $HOSTNAME"

# TODO: メール通知、Slack通知などを追加可能
# mailx -s "SMART Alert: $HOSTNAME" admin@example.com < /dev/null
# curl -X POST https://hooks.slack.com/... -d "text=SMART Alert: $HOSTNAME"