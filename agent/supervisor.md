## supervisorの設定

supervisorの設定の手順は定型化したいため、以下の手順を参考にしてください。
シェルの中身自体は必要に応じた調整してもよいです。

### confファイルの雛形

以下を参考にしてください。
特に、次のグループでの停止が重要です。
killasgroup=true
stopasgroup=true

```
[program:__PORJECT_NAME__]
command=__PROJECT_PATH__/start.sh
directory=__PROJECT_PATH__
user=__USER__
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=__PROJECT_PATH__/logs/__PORJECT_NAME__.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=30
startretries=3
startsecs=0
stopsignal=TERM
stopwaitsecs=30
killasgroup=true
stopasgroup=true
environment=PATH="__PATH__"
```

また以下のような設定のsetupシェルを用意してください。
__PROJECT_PATH__や__PATH__はフルパスで記載してください。

### setup_supervisor.sh

```
#!/bin/bash

PROJECT_NAME=my_project_name
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
```
