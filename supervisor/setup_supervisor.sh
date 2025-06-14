#!/bin/bash

PROJECT_NAME=smart_checker
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$(dirname "$SCRIPT_DIR")"
USER=$(whoami)
PATH_ENV="$PATH"

echo "プロジェクトパス: $PROJECT_PATH"
echo "実行ユーザー: $USER"

mkdir -p "$PROJECT_PATH/logs"

sed "s|__PROJECT_PATH__|$PROJECT_PATH|g; s|__USER__|$USER|g; s|__PATH__|$PATH_ENV|g" \
    "$SCRIPT_DIR/$PROJECT_NAME.conf.template" > "$SCRIPT_DIR/$PROJECT_NAME.conf"

echo "supervisor設定ファイルを生成しました: $SCRIPT_DIR/$PROJECT_NAME.conf"
echo ""
echo "次の手順でsupervisorに登録してください:"
echo "1. sudo cp $SCRIPT_DIR/$PROJECT_NAME.conf /etc/supervisor/conf.d/"
echo "2. sudo supervisorctl reread"
echo "3. sudo supervisorctl update"
echo "4. sudo supervisorctl start $PROJECT_NAME"