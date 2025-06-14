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

# テスト開始
echo "========================================" >&2
echo "SMART監視システム 基本動作テスト開始" >&2
echo "========================================" >&2
echo "" >&2

# 1. Pythonバージョン確認
echo "1. Python環境確認..." >&2
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    PYTHON_CMD="python3"
    test_result "Python3実行可能" "PASS" "$PYTHON_VERSION"
elif command -v python >/dev/null 2>&1; then
    PYTHON_VERSION=$(python --version 2>&1)
    if echo "$PYTHON_VERSION" | grep -q "Python 3"; then
        PYTHON_CMD="python"
        test_result "Python実行可能" "PASS" "$PYTHON_VERSION"
    else
        test_result "Python実行可能" "FAIL" "Python 3が必要です: $PYTHON_VERSION"
    fi
else
    test_result "Python実行可能" "FAIL" "Pythonコマンドが見つかりません"
fi

# 2. 必要パッケージ確認
echo "" >&2
echo "2. Pythonパッケージ確認..." >&2

if [ -n "$PYTHON_CMD" ]; then
    # requests
    if $PYTHON_CMD -c "import requests" 2>/dev/null; then
        test_result "requestsパッケージ" "PASS" ""
    else
        test_result "requestsパッケージ" "FAIL" "pip install requests が必要"
    fi
    
    # json (標準ライブラリ)
    if $PYTHON_CMD -c "import json" 2>/dev/null; then
        test_result "jsonパッケージ" "PASS" ""
    else
        test_result "jsonパッケージ" "FAIL" "標準ライブラリが見つかりません"
    fi
    
    # datetime (標準ライブラリ)
    if $PYTHON_CMD -c "import datetime" 2>/dev/null; then
        test_result "datetimeパッケージ" "PASS" ""
    else
        test_result "datetimeパッケージ" "FAIL" "標準ライブラリが見つかりません"
    fi
    
    # subprocess (標準ライブラリ)
    if $PYTHON_CMD -c "import subprocess" 2>/dev/null; then
        test_result "subprocessパッケージ" "PASS" ""
    else
        test_result "subprocessパッケージ" "FAIL" "標準ライブラリが見つかりません"
    fi
else
    test_result "パッケージ確認" "FAIL" "Pythonが利用できないためスキップ"
fi

# 3. smartctlコマンド確認
echo "" >&2
echo "3. smartctlコマンド確認..." >&2

if command -v smartctl >/dev/null 2>&1; then
    SMARTCTL_VERSION=$(smartctl --version 2>&1 | head -1)
    test_result "smartctlコマンド" "PASS" "$SMARTCTL_VERSION"
    
    # sudo権限確認
    if sudo -n smartctl --version >/dev/null 2>&1; then
        test_result "sudo smartctl権限" "PASS" ""
    else
        test_result "sudo smartctl権限" "FAIL" "sudo設定が必要"
    fi
else
    test_result "smartctlコマンド" "FAIL" "smartmontoolsのインストールが必要"
fi

# 4. 設定ファイル確認
echo "" >&2
echo "4. 設定ファイル確認..." >&2

if [ -f "settings.json.template" ]; then
    test_result "settings.json.template存在" "PASS" ""
    
    # JSONフォーマット確認
    if [ -n "$PYTHON_CMD" ]; then
        if $PYTHON_CMD -c "import json; json.load(open('settings.json.template'))" 2>/dev/null; then
            test_result "settings.json.template形式" "PASS" ""
        else
            test_result "settings.json.template形式" "FAIL" "JSON形式が不正"
        fi
    fi
else
    test_result "settings.json.template存在" "FAIL" "ファイルが見つかりません"
fi

if [ -f "settings.json" ]; then
    test_result "settings.json存在" "PASS" ""
    
    # JSONフォーマット確認
    if [ -n "$PYTHON_CMD" ]; then
        if $PYTHON_CMD -c "import json; json.load(open('settings.json'))" 2>/dev/null; then
            test_result "settings.json形式" "PASS" ""
        else
            test_result "settings.json形式" "FAIL" "JSON形式が不正"
        fi
    fi
else
    test_result "settings.json存在" "FAIL" "settings.json.templateからコピーが必要"
fi

# 5. メインファイル確認
echo "" >&2
echo "5. メインファイル確認..." >&2

if [ -f "main.py" ]; then
    test_result "main.py存在" "PASS" ""
    
    # Pythonシンタックス確認
    if [ -n "$PYTHON_CMD" ]; then
        if $PYTHON_CMD -m py_compile main.py 2>/dev/null; then
            test_result "main.pyシンタックス" "PASS" ""
        else
            test_result "main.pyシンタックス" "FAIL" "Pythonシンタックスエラー"
        fi
    fi
else
    test_result "main.py存在" "FAIL" "ファイルが見つかりません"
fi

if [ -f "cli.py" ]; then
    test_result "cli.py存在" "PASS" ""
    
    # Pythonシンタックス確認
    if [ -n "$PYTHON_CMD" ]; then
        if $PYTHON_CMD -m py_compile cli.py 2>/dev/null; then
            test_result "cli.pyシンタックス" "PASS" ""
        else
            test_result "cli.pyシンタックス" "FAIL" "Pythonシンタックスエラー"
        fi
    fi
else
    test_result "cli.py存在" "FAIL" "ファイルが見つかりません"
fi

if [ -f "start.sh" ]; then
    test_result "start.sh存在" "PASS" ""
    
    # 実行権限確認
    if [ -x "start.sh" ]; then
        test_result "start.sh実行権限" "PASS" ""
    else
        test_result "start.sh実行権限" "FAIL" "chmod +x start.sh が必要"
    fi
else
    test_result "start.sh存在" "FAIL" "ファイルが見つかりません"
fi

# 6. ディレクトリ構造確認
echo "" >&2
echo "6. ディレクトリ構造確認..." >&2

if [ -d "data" ]; then
    test_result "dataディレクトリ" "PASS" ""
else
    test_result "dataディレクトリ" "FAIL" "mkdir -p data/smart が必要"
fi

if [ -d "data/smart" ]; then
    test_result "data/smartディレクトリ" "PASS" ""
else
    test_result "data/smartディレクトリ" "FAIL" "mkdir -p data/smart が必要"
fi

if [ -d "test" ]; then
    test_result "testディレクトリ" "PASS" ""
else
    test_result "testディレクトリ" "FAIL" "mkdir test が必要"
fi

# 7. 設定読み込みテスト
echo "" >&2
echo "7. 設定読み込みテスト..." >&2

if [ -f "settings.json" ] && [ -n "$PYTHON_CMD" ]; then
    if $PYTHON_CMD -c "from main import load_config; print('設定読み込み成功')" 2>/dev/null; then
        test_result "設定読み込み機能" "PASS" ""
    else
        ERROR_MSG=$($PYTHON_CMD -c "from main import load_config; load_config()" 2>&1)
        test_result "設定読み込み機能" "FAIL" "$ERROR_MSG"
    fi
else
    test_result "設定読み込み機能" "FAIL" "前提条件が満たされていません"
fi

# 8. デバイス検出テスト
echo "" >&2
echo "8. デバイス検出テスト..." >&2

if [ -n "$PYTHON_CMD" ] && [ -f "main.py" ]; then
    DEVICE_OUTPUT=$($PYTHON_CMD -c "from main import get_devices; devices = get_devices(); print(f'検出デバイス数: {len(devices)}')" 2>/dev/null)
    if [ $? -eq 0 ]; then
        test_result "デバイス検出機能" "PASS" "$DEVICE_OUTPUT"
    else
        ERROR_MSG=$($PYTHON_CMD -c "from main import get_devices; get_devices()" 2>&1)
        test_result "デバイス検出機能" "FAIL" "$ERROR_MSG"
    fi
else
    test_result "デバイス検出機能" "FAIL" "前提条件が満たされていません"
fi

# 9. CLIコマンドテスト
echo "" >&2
echo "9. CLIコマンド基本テスト..." >&2

if [ -f "cli.py" ] && [ -n "$PYTHON_CMD" ]; then
    # ヘルプ表示テスト
    if $PYTHON_CMD cli.py --help >/dev/null 2>&1; then
        test_result "CLI --helpオプション" "PASS" ""
    else
        test_result "CLI --helpオプション" "FAIL" "ヘルプ表示エラー"
    fi
    
    # statusコマンドテスト（設定があれば）
    if [ -f "settings.json" ]; then
        if timeout 10 $PYTHON_CMD cli.py status >/dev/null 2>&1; then
            test_result "CLI statusコマンド" "PASS" ""
        else
            test_result "CLI statusコマンド" "FAIL" "status実行エラー"
        fi
    else
        test_result "CLI statusコマンド" "FAIL" "settings.jsonが必要"
    fi
else
    test_result "CLIコマンド基本テスト" "FAIL" "前提条件が満たされていません"
fi

# テスト結果サマリー
echo "" >&2
echo "========================================" >&2
echo "テスト結果サマリー" >&2
echo "========================================" >&2
echo "実行テスト数: $TEST_COUNT" >&2
echo "成功: $PASS_COUNT" >&2
echo "失敗: $FAIL_COUNT" >&2

if [ $FAIL_COUNT -eq 0 ]; then
    echo "" >&2
    echo "✓ 全てのテストが成功しました！" >&2
    echo "次のステップ:" >&2
    echo "1. settings.json の設定確認" >&2
    echo "2. bash start.sh で動作開始" >&2
    echo "3. python cli.py collect でデータ収集テスト" >&2
    exit 0
else
    echo "" >&2
    echo "✗ いくつかのテストが失敗しました。" >&2
    echo "上記の FAIL 項目を確認して修正してください。" >&2
    exit 1
fi