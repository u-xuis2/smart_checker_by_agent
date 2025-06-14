#!/bin/bash

umask 077
set -uo pipefail

RUN_PATH=`pwd`
EXE_PATH=`dirname "${0}"`
EXE_NAME=`basename "${0}"`
cd "${EXE_PATH}"
EXE_PATH=`pwd`
cd ..

# テスト結果カウンター
PASS_COUNT=0
FAIL_COUNT=0
TEST_COUNT=0

# テスト結果表示関数
function test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [ "$result" = "PASS" ]; then
        echo "✓ PASS: $test_name" >&2
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: $test_name - $details" >&2
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Pythonコマンド検出
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_VERSION=$(python --version 2>&1)
    if echo "$PYTHON_VERSION" | grep -q "Python 3"; then
        PYTHON_CMD="python"
    fi
fi

# テスト用一時設定ファイル作成
function create_test_config() {
    cat > test_settings.json << EOF
{
  "collection_interval_hours": 1,
  "analysis_interval_hours": 24,
  "data_retention_years": 2,
  "device_wait_seconds": 1,
  "llm_api_key": "TEST_KEY",
  "llm_model": "gemini-pro",
  "llm_max_calls": 32,
  "alert_command": "./test_alert.sh",
  "error_command": "./test_error.sh"
}
EOF
}

# テストクリーンアップ
function cleanup_test() {
    rm -f test_settings.json
    rm -rf test_data/
}

# テスト開始
echo "========================================" >&2
echo "SMART監視システム データ収集テスト開始" >&2
echo "========================================" >&2
echo "" >&2

# 前提条件確認
if [ -z "$PYTHON_CMD" ]; then
    echo "エラー: Python 3が見つかりません" >&2
    exit 1
fi

if [ ! -f "main.py" ]; then
    echo "エラー: main.pyが見つかりません" >&2
    exit 1
fi

# 1. 設定ファイル読み込みテスト
echo "1. 設定ファイル読み込みテスト..." >&2

create_test_config

# テスト用設定で読み込み確認
CONFIG_TEST_OUTPUT=$($PYTHON_CMD -c "
import json
import sys
import os
sys.path.insert(0, '.')

# テスト用設定読み込み
def load_test_config():
    with open('test_settings.json', 'r', encoding='utf-8') as f:
        config = json.load(f)
    return config

try:
    config = load_test_config()
    print('設定読み込み成功')
    print(f'収集間隔: {config[\"collection_interval_hours\"]}時間')
    print(f'分析間隔: {config[\"analysis_interval_hours\"]}時間')
except Exception as e:
    print(f'エラー: {e}')
    sys.exit(1)
" 2>&1)

if [ $? -eq 0 ]; then
    test_result "設定ファイル読み込み" "PASS" "$CONFIG_TEST_OUTPUT"
else
    test_result "設定ファイル読み込み" "FAIL" "$CONFIG_TEST_OUTPUT"
fi

# 2. デバイス検出テスト
echo "" >&2
echo "2. デバイス検出テスト..." >&2

DEVICE_TEST_OUTPUT=$($PYTHON_CMD -c "
import sys
sys.path.insert(0, '.')
from main import get_devices

try:
    devices = get_devices()
    print(f'検出デバイス数: {len(devices)}')
    for i, device in enumerate(devices[:3]):  # 最大3つまで表示
        print(f'  {i+1}: {device}')
    if len(devices) > 3:
        print(f'  ... 他{len(devices)-3}個')
except Exception as e:
    print(f'エラー: {e}')
    sys.exit(1)
" 2>&1)

if [ $? -eq 0 ]; then
    test_result "デバイス検出" "PASS" "$DEVICE_TEST_OUTPUT"
else
    test_result "デバイス検出" "FAIL" "$DEVICE_TEST_OUTPUT"
fi

# 3. /proc/partitions読み込みテスト
echo "" >&2
echo "3. /proc/partitions読み込みテスト..." >&2

if [ -r "/proc/partitions" ]; then
    PARTITION_COUNT=$(cat /proc/partitions | tail -n +3 | wc -l)
    test_result "/proc/partitions読み込み" "PASS" "エントリ数: $PARTITION_COUNT"
else
    test_result "/proc/partitions読み込み" "FAIL" "ファイルが読み込めません"
fi

# 3.5. smartctlオプション確認テスト
echo "" >&2
echo "3.5. smartctlオプション確認テスト..." >&2

if command -v smartctl >/dev/null 2>&1; then
    # -d オプションのサポート確認
    if smartctl --help 2>&1 | grep -q "\-d TYPE"; then
        test_result "smartctl -dオプション" "PASS" "デバイスタイプ指定サポート"
    else
        test_result "smartctl -dオプション" "FAIL" "デバイスタイプ指定未サポート"
    fi
    
    # satオプションの確認
    if smartctl --help 2>&1 | grep -q "sat"; then
        test_result "smartctl satオプション" "PASS" "SATA Pass Through サポート"
    else
        test_result "smartctl satオプション" "FAIL" "SATA Pass Through 未サポート"
    fi
else
    test_result "smartctlオプション確認" "FAIL" "smartctlコマンドが見つかりません"
fi

# 4. SMART情報取得テスト（実際のデバイス）
echo "" >&2
echo "4. SMART情報取得テスト..." >&2

if command -v smartctl >/dev/null 2>&1; then
    # 最初のデバイスでテスト
    FIRST_DEVICE=$($PYTHON_CMD -c "
import sys
sys.path.insert(0, '.')
from main import get_devices
devices = get_devices()
print(devices[0] if devices else '')
" 2>/dev/null)
    
    if [ -n "$FIRST_DEVICE" ]; then
        echo "テスト対象デバイス: $FIRST_DEVICE" >&2
        
        # sudo権限確認
        if sudo -n smartctl --version >/dev/null 2>&1; then
            SMART_TEST_OUTPUT=$($PYTHON_CMD -c "
import sys
sys.path.insert(0, '.')
from main import get_smart_data
import json

try:
    device = '$FIRST_DEVICE'
    smart_data = get_smart_data(device)
    if smart_data:
        print('SMART取得成功')
        print(f'モデル: {smart_data.get(\"model_name\", \"不明\")}')
        print(f'シリアル: {smart_data.get(\"serial_number\", \"不明\")}')
        print(f'デバイスタイプ: {smart_data.get(\"_device_type\", \"不明\")}')
        print(f'タイムスタンプ: {smart_data.get(\"_collection_timestamp\", \"不明\")}')
        
        # SMART属性の存在確認
        ata_smart = smart_data.get('ata_smart_attributes', {})
        table = ata_smart.get('table', [])
        print(f'SMART属性数: {len(table)}')
    else:
        print('SMART取得失敗')
        sys.exit(1)
except Exception as e:
    print(f'エラー: {e}')
    sys.exit(1)
" 2>&1)
            
            if [ $? -eq 0 ]; then
                test_result "SMART情報取得" "PASS" "$SMART_TEST_OUTPUT"
            else
                test_result "SMART情報取得" "FAIL" "$SMART_TEST_OUTPUT"
            fi
        else
            test_result "SMART情報取得" "FAIL" "sudo権限が必要"
        fi
    else
        test_result "SMART情報取得" "FAIL" "テスト対象デバイスなし"
    fi
else
    test_result "SMART情報取得" "FAIL" "smartctlコマンドが見つかりません"
fi

# 5. データ保存テスト
echo "" >&2
echo "5. データ保存・読み込みテスト..." >&2

mkdir -p test_data/smart

DATA_SAVE_TEST_OUTPUT=$($PYTHON_CMD -c "
import sys
import os
import json
import datetime
from pathlib import Path
sys.path.insert(0, '.')

# テスト用データ保存関数
def save_test_data(data):
    now = datetime.datetime.now()
    month_dir = Path('test_data/smart') / f'{now.year:04d}-{now.month:02d}'
    month_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = now.strftime('%Y%m%d_%H%M%S')
    filename = month_dir / f'smart_{timestamp}.json'
    
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    return str(filename)

# テスト用データ読み込み関数
def load_test_data():
    data_files = []
    data_dir = Path('test_data/smart')
    
    if not data_dir.exists():
        return []
    
    for month_dir in data_dir.iterdir():
        if month_dir.is_dir():
            for json_file in month_dir.glob('smart_*.json'):
                data_files.append(json_file)
    
    data_files.sort(key=lambda x: x.name, reverse=True)
    
    historical_data = []
    for file_path in data_files[:5]:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                historical_data.append(data)
        except Exception as e:
            print(f'読み込みエラー {file_path}: {e}')
    
    return historical_data

try:
    # テストデータ作成
    test_data = [{
        '_device_path': '/dev/test',
        '_collection_timestamp': datetime.datetime.now().isoformat(),
        'model_name': 'Test Drive',
        'serial_number': 'TEST123',
        'ata_smart_attributes': {
            'table': [
                {'name': 'Raw_Read_Error_Rate', 'value': 200, 'worst': 200, 'thresh': 51, 'raw': {'value': 0}},
                {'name': 'Reallocated_Sector_Ct', 'value': 200, 'worst': 200, 'thresh': 140, 'raw': {'value': 0}}
            ]
        }
    }]
    
    # 保存テスト
    filename = save_test_data(test_data)
    print(f'データ保存成功: {filename}')
    
    # 読み込みテスト
    loaded_data = load_test_data()
    print(f'データ読み込み成功: {len(loaded_data)}件')
    
    if loaded_data:
        first_data = loaded_data[0]
        if isinstance(first_data, list) and len(first_data) > 0:
            device_data = first_data[0]
            print(f'モデル: {device_data.get(\"model_name\", \"不明\")}')
        
except Exception as e:
    print(f'エラー: {e}')
    sys.exit(1)
" 2>&1)

if [ $? -eq 0 ]; then
    test_result "データ保存・読み込み" "PASS" "$DATA_SAVE_TEST_OUTPUT"
else
    test_result "データ保存・読み込み" "FAIL" "$DATA_SAVE_TEST_OUTPUT"
fi

# 6. TSV変換テスト
echo "" >&2
echo "6. TSV変換テスト..." >&2

TSV_TEST_OUTPUT=$($PYTHON_CMD -c "
import sys
import datetime
sys.path.insert(0, '.')
from main import convert_to_tsv

try:
    # テストデータ
    test_data = [{
        '_device_path': '/dev/test',
        '_collection_timestamp': datetime.datetime.now().isoformat(),
        'ata_smart_attributes': {
            'table': [
                {'name': 'Raw_Read_Error_Rate', 'value': 200, 'worst': 200, 'thresh': 51, 'raw': {'value': 0}},
                {'name': 'Reallocated_Sector_Ct', 'value': 200, 'worst': 200, 'thresh': 140, 'raw': {'value': 0}}
            ]
        }
    }]
    
    tsv_result = convert_to_tsv(test_data)
    
    if tsv_result:
        lines = tsv_result.split('\n')
        print(f'TSV変換成功: {len(lines)}行')
        header = lines[0] if lines else \"なし\"
        print(f'ヘッダー: {header}')
        print(f'データ行数: {len(lines)-1 if len(lines) > 1 else 0}')
        
        # 期待されるヘッダー形式をチェック
        expected_header = 'device\ttimestamp\tattribute_name\traw_value'
        if header == expected_header:
            print('ヘッダー形式: 正しい（簡素化版）')
        else:
            print(f'ヘッダー形式: 期待値と異なる - 期待: {expected_header}')
    else:
        print('TSV変換失敗: 空の結果')
        sys.exit(1)
        
except Exception as e:
    print(f'エラー: {e}')
    sys.exit(1)
" 2>&1)

if [ $? -eq 0 ]; then
    test_result "TSV変換" "PASS" "$TSV_TEST_OUTPUT"
else
    test_result "TSV変換" "FAIL" "$TSV_TEST_OUTPUT"
fi

# 7. CLIコマンド実行テスト
echo "" >&2
echo "7. CLIコマンド実行テスト..." >&2

if [ -f "settings.json" ]; then
    # statusコマンドテスト
    CLI_STATUS_OUTPUT=$(timeout 15 $PYTHON_CMD cli.py status 2>&1)
    if [ $? -eq 0 ]; then
        test_result "CLI statusコマンド" "PASS" "実行成功"
    else
        test_result "CLI statusコマンド" "FAIL" "$CLI_STATUS_OUTPUT"
    fi
    
    # collectコマンドテスト（sudoが使える場合のみ）
    if sudo -n smartctl --version >/dev/null 2>&1; then
        echo "データ収集テスト実行中（時間がかかる場合があります）..." >&2
        CLI_COLLECT_OUTPUT=$(timeout 60 $PYTHON_CMD cli.py collect 2>&1)
        if [ $? -eq 0 ]; then
            test_result "CLI collectコマンド" "PASS" "データ収集成功"
        else
            test_result "CLI collectコマンド" "FAIL" "$CLI_COLLECT_OUTPUT"
        fi
    else
        test_result "CLI collectコマンド" "FAIL" "sudo権限が必要"
    fi
else
    test_result "CLIコマンド実行テスト" "FAIL" "settings.jsonが必要"
fi

# 8. エラーハンドリングテスト
echo "" >&2
echo "8. エラーハンドリングテスト..." >&2

ERROR_HANDLING_OUTPUT=$($PYTHON_CMD -c "
import sys
sys.path.insert(0, '.')
from main import get_smart_data

try:
    # 存在しないデバイスでテスト
    result = get_smart_data('/dev/nonexistent')
    if result is None:
        print('エラーハンドリング成功: 存在しないデバイスでNoneを返却')
    else:
        print('エラーハンドリング失敗: 存在しないデバイスで値を返却')
        sys.exit(1)
except Exception as e:
    print(f'予期しないエラー: {e}')
    sys.exit(1)
" 2>&1)

if [ $? -eq 0 ]; then
    test_result "エラーハンドリング" "PASS" "$ERROR_HANDLING_OUTPUT"
else
    test_result "エラーハンドリング" "FAIL" "$ERROR_HANDLING_OUTPUT"
fi

# クリーンアップ
cleanup_test

# テスト結果サマリー
echo "" >&2
echo "========================================" >&2
echo "データ収集テスト結果サマリー" >&2
echo "========================================" >&2
echo "実行テスト数: $TEST_COUNT" >&2
echo "成功: $PASS_COUNT" >&2
echo "失敗: $FAIL_COUNT" >&2

if [ $FAIL_COUNT -eq 0 ]; then
    echo "" >&2
    echo "✓ 全ての収集テストが成功しました！" >&2
    echo "データ収集機能は正常に動作しています。" >&2
    echo "" >&2
    echo "次のステップ:" >&2
    echo "1. python cli.py collect でリアルデータ収集" >&2
    echo "2. bash start.sh で監視開始" >&2
    echo "3. Gemini APIキー設定で分析機能テスト" >&2
    exit 0
else
    echo "" >&2
    echo "✗ いくつかの収集テストが失敗しました。" >&2
    echo "上記の FAIL 項目を確認して修正してください。" >&2
    echo "" >&2
    echo "よくある問題と対処法:" >&2
    echo "- sudo権限: sudo設定を確認" >&2
    echo "- smartctl: smartmontoolsをインストール" >&2
    echo "- デバイス検出: /proc/partitionsを確認" >&2
    exit 1
fi