# プランB: 軽量版SMART監視システム実装計画

## 概要
最低限の機能を持つシンプルなSMART監視システム。基本的な監視とLLM分析機能のみに絞った軽量実装です。

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
pip install requests
```

## ファイル構成

```
smart_checker_by_agent/
├── main.py                    # メイン実行ファイル（全機能統合）
├── cli.py                     # CLI補助コマンド
├── settings.json.template     # 設定ファイルテンプレート
├── start.sh                   # 起動用スクリプト
├── README.md                  # 簡易ドキュメント
├── .gitignore                 # Git除外設定
├── data/                      # データ保存ディレクトリ
│   └── smart/                 # SMART情報保存（月毎）
└── test/                      # テスト用ディレクトリ
    ├── test_basic.sh          # 基本動作テスト
    └── test_collection.sh     # データ収集テスト
```

## 主要機能仕様

### 1. 単一ファイル設計（main.py）
- 設定読み込み機能
- デバイス自動検出（基本的な方法）
- SMART情報取得
- データ保存（月毎のJSONファイル）
- LLM分析（4パターン）
- アラート処理
- 定期実行機能

### 2. CLI補助（cli.py）
- 即時SMART取得
- 即時分析実行

## 機能詳細

### デバイス検出
- `/proc/partitions`での簡易検出
- HDD/SSD判別は基本的な方法のみ
- 固定リストでの除外設定

### データ管理
- 単純なJSONファイル保存
- 月毎ディレクトリ作成
- 基本的なデータ削除機能

### LLM分析
- 4パターンの分析（単体、1日前、1週間前、1ヶ月前比較）
- シンプルなTSV変換
- 基本的なプロンプト

### ログ出力
- 標準エラーへの簡易ログ
- エラー時の基本情報出力

## 設定ファイル（settings.json.template）

```json
{
  "collection_interval_hours": 1,
  "analysis_interval_hours": 24,
  "data_retention_years": 2,
  "device_wait_seconds": 3,
  "llm_api_key": "YOUR_GEMINI_API_KEY",
  "llm_model": "gemini-pro",
  "llm_max_calls": 32,
  "alert_command": "./alert_notify.sh",
  "error_command": "./error_notify.sh"
}
```

## 実装手順

### Phase 1: 基盤実装
1. プロジェクト構造作成
2. .gitignore設定
3. settings.json.template作成
4. 基本ユーティリティ関数実装

### Phase 2: 主要機能実装
1. main.py実装
   - 設定読み込み
   - デバイス検出
   - SMART取得
   - データ保存
2. LLM分析機能実装
3. アラート機能実装

### Phase 3: CLI・起動スクリプト
1. cli.py実装
2. start.sh作成

### Phase 4: テスト・ドキュメント
1. 基本テスト作成
2. README.md作成

### Phase 5: 統合テスト
1. 全体動作確認
2. エラー修正

## main.pyの主要構造

```python
# 設定管理
def load_config():
    # settings.json読み込み

# デバイス管理
def get_devices():
    # 基本的なデバイス一覧取得

def get_smart_data(device):
    # smartctl実行・JSON取得

# データ管理
def save_data(data):
    # 月毎ディレクトリ・JSON保存

def load_historical_data():
    # 過去データ読み込み

# LLM分析
def analyze_with_llm(data, comparison_data=None):
    # Gemini API呼び出し

# メイン処理
def collect_smart_data():
    # SMART情報収集処理

def analyze_data():
    # 分析処理

def main_loop():
    # 定期実行ループ

if __name__ == "__main__":
    main_loop()
```

## テスト計画

### 基本テスト（test/配下）
- test_basic.sh: 基本動作テスト
- test_collection.sh: データ収集テスト

### テスト内容
1. 設定ファイル読み込み確認
2. デバイス検出確認
3. SMART取得確認（モックデバイス）
4. データ保存・読み込み確認
5. CLI動作確認

## ログ設計

### 標準エラー出力
- 基本的な動作ログ
- エラー情報
- デバッグ情報

### 標準出力
- CLI実行結果
- 状態情報（JSON形式）

## 簡略化された機能

### 省略機能
- 複雑なエラーハンドリング
- 詳細なログ管理
- パフォーマンス最適化
- 高度なセキュリティ機能
- データ圧縮
- 複雑な統計計算

### 最小限機能
- 基本的なデバイス検出
- シンプルなSMART取得
- 基本的なデータ保存
- LLM分析（4パターン）
- 基本的なアラート

## README.md概要

```markdown
# SMART監視システム（軽量版）

## 概要
HDD/SSDのSMART値を監視し、LLMで異常検知するシステム

## セットアップ
1. `cp settings.json.template settings.json`
2. APIキー設定
3. `python main.py`

## CLI使用法
- `python cli.py --collect`: 即時データ取得
- `python cli.py --analyze`: 即時分析実行
```

## 完了基準

1. 基本テストが通過する
2. 1日間の動作確認
3. LLM分析動作確認
4. アラート通知動作確認
5. データ保存・削除動作確認

## プランAとの違い

- 単一ファイル構成で実装コストを削減
- 複雑な機能を省略してシンプル化
- テスト項目を最小限に削減
- エラーハンドリングを簡素化
- ログ機能を最低限に制限