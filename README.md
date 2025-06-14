# SMART監視システム（軽量版）

## 概要

HDD/SSDのSMART値を監視し、LLM（Gemini）で異常検知を行うシステムです。
軽量設計で最低限の機能を提供し、簡単にセットアップできます。

## 特徴

- 自動的なデバイス検出とSMART情報収集
- デバイスタイプ自動判別（SATA/NVMe対応、-d satオプション使用）
- LLMによる4パターンの分析（現在/1日前/1週間前/1ヶ月前比較）
- 月毎のデータ保存とクリーンアップ
- CLI補助ツールによる即時実行
- アラート機能

## 必要要件

### システム要件
- Python 3.8以上
- smartmontools（smartctlコマンド）
- sudo権限（smartctl実行用）
- インターネット接続（LLM API利用）

### 事前準備
```bash
# smartmontoolsのインストール
# Ubuntu/Debian
sudo apt install smartmontools

# CentOS/RHEL
sudo yum install smartmontools

# Pythonライブラリのインストール
pip install requests
```

### sudo設定（推奨）
以下を`/etc/sudoers`に追加してパスワードなしでsmartctlを実行：
```
your_username ALL=(ALL) NOPASSWD: /usr/sbin/smartctl
```

## セットアップ

### 1. 設定ファイル作成
```bash
cp settings.json.template settings.json
vi settings.json
```

### 2. APIキー設定
`settings.json`でGemini APIキーを設定：
```json
{
  "llm_api_key": "YOUR_ACTUAL_GEMINI_API_KEY"
}
```

### 3. 実行権限設定
```bash
chmod +x start.sh
```

## 使用方法

### 常駐監視

**手動起動:**
```bash
# バックグラウンド実行
bash start.sh &

# フォアグラウンド実行
bash start.sh
```

**Supervisor使用（推奨）:**
```bash
# Supervisor設定の生成
cd supervisor
bash setup_supervisor.sh

# Supervisorに登録（表示された手順に従って実行）
sudo cp smart_checker.conf /etc/supervisor/conf.d/
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start smart_checker

# 状態確認・操作
sudo supervisorctl status smart_checker    # 状態確認
sudo supervisorctl stop smart_checker      # 停止
sudo supervisorctl restart smart_checker   # 再起動
sudo supervisorctl tail smart_checker      # ログ確認
```

### CLI補助ツール
```bash
# システム状態確認
python cli.py status

# 即時SMART収集
python cli.py collect

# 即時分析実行
python cli.py analyze

# デバイステスト
python cli.py test /dev/sda

# 履歴データ表示（過去7日間）
python cli.py history --days 7

# 最新分析のプロンプト表示
python cli.py prompt                           # 現在の分析
python cli.py prompt --analysis-type daily     # 日次比較分析
python cli.py prompt --analysis-type weekly    # 週次比較分析
python cli.py prompt --analysis-type monthly   # 月次比較分析

# 旧形式（後方互換性）
python cli.py --collect
python cli.py --analyze
```

## 設定項目

`settings.json`の主要項目：

| 項目 | 説明 | デフォルト |
|------|------|------------|
| collection_interval_hours | SMART収集間隔（時間） | 1 |
| analysis_interval_hours | 分析実行間隔（時間） | 24 |
| data_retention_years | データ保持期間（年） | 2 |
| device_wait_seconds | デバイス間の待機時間（秒） | 3 |
| llm_api_key | Gemini APIキー | - |
| llm_model | 使用LLMモデル | gemini-pro |
| llm_max_calls | API呼び出し上限 | 32 |
| alert_command | アラート通知コマンド | ./alert_notify.sh |
| error_command | エラー通知コマンド | ./error_notify.sh |

## ファイル構成

```
smart_checker_by_agent/
├── main.py                    # メイン実行ファイル
├── cli.py                     # CLI補助コマンド
├── start.sh                   # 起動スクリプト
├── settings.json.template     # 設定テンプレート
├── settings.json              # 実際の設定（要作成）
├── alert_notify.sh            # アラート通知スクリプト
├── error_notify.sh            # エラー通知スクリプト
├── README.md                  # このファイル
├── .gitignore                 # Git除外設定
├── data/                      # データ保存ディレクトリ
│   └── smart/                 # SMART情報（月毎）
├── logs/                      # ログファイル
├── supervisor/                # Supervisor設定
│   ├── smart_checker.conf.template  # 設定テンプレート
│   ├── smart_checker.conf     # 生成済み設定ファイル
│   └── setup_supervisor.sh    # 設定生成スクリプト
└── test/                      # テスト用
    ├── test_basic.sh          # 基本動作テスト
    └── test_collection.sh     # データ収集テスト
```

## データ保存形式

### SMART情報
- 場所: `data/smart/YYYY-MM/smart_YYYYMMDD_HHMMSS.json`
- 形式: smartctl の JSON出力そのまま
- 保持期間: 設定ファイルで指定（デフォルト2年）

### 分析結果
- 場所: `data/smart/YYYY-MM/analysis_YYYYMMDD_HHMMSS.json`
- 内容: LLM分析結果（4パターン）

## トラブルシューティング

### よくある問題

1. **smartctlが実行できない**
   - sudo権限を確認
   - smartmontoolsのインストールを確認

2. **LLM分析が動作しない**
   - APIキーの設定を確認
   - インターネット接続を確認
   - requestsライブラリのインストールを確認

3. **デバイスが検出されない**
   - `/proc/partitions`を確認
   - 対象デバイスがHDD/SSDかを確認

4. **SMART情報が取得できない**
   - デバイスタイプ（SATA/NVMe）の自動判別機能を使用
   - `-d sat`オプションでSATA Pass Throughを試行
   - USBデバイスの場合は追加設定が必要な場合があります

### ログ確認
```bash
# 最新ログ表示
tail -f logs/smart_checker.log

# エラーログ検索
grep -i error logs/smart_checker.log
```

### 設定テスト
```bash
# 設定ファイル確認
python -c "from main import load_config; print(load_config())"

# デバイス検出確認
python -c "from main import get_devices; print(get_devices())"
```

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 更新履歴

- v1.0.0: 初回リリース（軽量版）