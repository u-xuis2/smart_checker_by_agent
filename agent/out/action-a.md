# プランA: 完全機能版SMART監視システム実装計画

## 概要
HDDやSSDのSMART値を定期的に監視し、LLMを使用した高精度な異常検知機能を持つ完全版システムの実装計画です。

## 事前準備要件

### 必要パッケージ
- Python 3.8以上
- smartmontools（smartctlコマンド）
- sudo設定（smartctl実行用）

### 事前インストール確認
```bash
# smartmontoolsのインストール確認
which smartctl
# Pythonライブラリ
pip install requests schedule psutil
```

## ファイル構成

```
smart_checker_by_agent/
├── main.py                    # メインの常駐プロセス
├── cli.py                     # CLI補助コマンド
├── smart_collector.py         # SMART情報収集モジュール
├── analyzer.py                # LLM分析モジュール
├── device_manager.py          # デバイス管理モジュール
├── data_manager.py            # データ管理モジュール
├── alert_manager.py           # アラート管理モジュール
├── config_manager.py          # 設定管理モジュール
├── utils.py                   # ユーティリティ関数
├── settings.json.template     # 設定ファイルテンプレート
├── ready.sh                   # 環境準備スクリプト
├── start.sh                   # 起動用スクリプト
├── README.md                  # ドキュメント
├── .gitignore                 # Git除外設定
├── data/                      # データ保存ディレクトリ
│   ├── smart/                 # SMART情報保存
│   │   ├── 2024-01/          # 月毎のディレクトリ
│   │   └── 2024-02/
│   └── logs/                  # ログファイル
│       ├── main.log          # メインログ
│       ├── llm.log           # LLM通信ログ
│       └── error.log         # エラーログ
├── test/                      # テスト用ディレクトリ
│   ├── test_smart_collector.sh
│   ├── test_device_manager.sh
│   ├── test_data_manager.sh
│   ├── test_analyzer.sh
│   ├── test_alert_manager.sh
│   └── test_integration.sh
└── supervisor/                # Supervisor設定
    ├── smart_checker.conf.template
    └── setup_supervisor.sh
```

## 主要機能仕様

### 1. 設定管理（config_manager.py）
- JSON設定ファイルの読み込み
- 設定値の検証
- デフォルト値の提供

### 2. デバイス管理（device_manager.py）
- `/proc/partitions`と`lsblk`でデバイス自動検出
- HDD/SSD判別（回転速度、デバイス種別）
- `-d sat`オプション必要性の自動判定
- デバイス情報キャッシュ機能

### 3. SMART情報収集（smart_collector.py）
- smartctlコマンド実行（JSON出力）
- デバイス間待機時間制御
- エラーハンドリング
- データ構造の正規化

### 4. データ管理（data_manager.py）
- 月毎ディレクトリでのファイル保存
- JSON形式でのデータ保存
- 2年以上前のデータ自動削除
- データ圧縮機能
- データ統計計算（日、週、月平均）

### 5. LLM分析（analyzer.py）
- Gemini API呼び出し
- プロンプト管理（4種類の分析）
  - 単体データ分析
  - 1日前比較分析
  - 1週間前平均比較分析
  - 1ヶ月前平均比較分析
- TSV形式データ生成
- レスポンス解析
- 呼び出し制限機能

### 6. アラート管理（alert_manager.py）
- LLM分析結果の評価
- 外部コマンド実行
- アラート履歴管理
- 重複アラート抑制機能

### 7. メイン処理（main.py）
- 常駐プロセス管理
- スケジュール実行（収集・分析）
- シグナルハンドリング
- ログ出力管理

### 8. CLI補助（cli.py）
- 即時SMART取得
- 即時分析実行
- 設定確認
- データ確認コマンド

## 設定ファイル（settings.json.template）

```json
{
  "collection": {
    "interval_hours": 1,
    "device_wait_seconds": 3
  },
  "analysis": {
    "interval_hours": 24,
    "llm_max_calls": 32
  },
  "data": {
    "retention_years": 2,
    "data_directory": "./data"
  },
  "llm": {
    "api_key": "YOUR_GEMINI_API_KEY",
    "model": "gemini-pro",
    "endpoint": "https://generativelanguage.googleapis.com/v1beta/models"
  },
  "alerts": {
    "command": "./alert_notify.sh",
    "error_command": "./error_notify.sh"
  },
  "logging": {
    "level": "INFO",
    "max_file_size_mb": 10,
    "backup_count": 5
  }
}
```

## 実装手順

### Phase 1: 基盤モジュール作成
1. プロジェクト構造作成
2. .gitignore設定
3. config_manager.py実装
4. utils.py実装
5. settings.json.template作成

### Phase 2: デバイス・SMART収集機能
1. device_manager.py実装
2. smart_collector.py実装
3. data_manager.py実装

### Phase 3: 分析・アラート機能
1. analyzer.py実装
2. alert_manager.py実装

### Phase 4: メイン処理・CLI
1. main.py実装
2. cli.py実装
3. start.sh作成

### Phase 5: テスト・ドキュメント
1. テストスクリプト作成
2. README.md作成
3. ready.sh作成
4. supervisor設定作成

### Phase 6: 統合テスト・調整
1. 統合テスト実行
2. エラー修正
3. パフォーマンス調整

## テスト計画

### 単体テスト（test/配下）
- test_device_manager.sh: デバイス検出テスト
- test_smart_collector.sh: SMART取得テスト
- test_data_manager.sh: データ保存・読み込みテスト
- test_analyzer.sh: LLM呼び出しテスト（モック使用）
- test_alert_manager.sh: アラート機能テスト

### 統合テスト
- test_integration.sh: 全体フロー確認テスト

## ログ設計

### 標準出力（stdout）
- CLI実行結果の機能的データ出力
- JSON形式での状態レポート

### 標準エラー（stderr）
- 動作ログ
- エラーログ
- デバッグ情報

### ファイルログ
- main.log: 一般動作ログ
- llm.log: LLM通信ログ
- error.log: エラー専用ログ

## セキュリティ考慮事項

### APIキー管理
- 設定ファイルのパーミッション制限（600）
- 環境変数での上書き対応
- ログ出力時のAPIキーマスク

### sudo権限
- 最小権限の原則
- smartctl専用権限設定推奨

## パフォーマンス最適化

### データ管理
- 古いデータの自動圧縮
- インデックスファイルによる高速検索
- メモリ使用量制限

### LLM呼び出し
- 呼び出し頻度制限
- リトライ機構
- タイムアウト設定

## 完了基準

1. 全テストが通過する
2. 24時間の連続動作確認
3. LLM分析による異常検知動作確認
4. アラート通知動作確認
5. ログローテーション動作確認
6. データ削除機能動作確認