#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
import sys
import time
import subprocess
import datetime
import traceback
import requests
from pathlib import Path

# 設定読み込み
def load_config():
    """設定ファイルを読み込む"""
    try:
        with open('settings.json', 'r', encoding='utf-8') as f:
            config = json.load(f)
        return config
    except FileNotFoundError:
        print("settings.jsonが見つかりません。settings.json.templateからコピーしてください。", file=sys.stderr, flush=True)
        sys.exit(101)
    except json.JSONDecodeError as e:
        print(f"settings.jsonの形式が不正です: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        sys.exit(102)
    except Exception as e:
        print(f"設定ファイル読み込みエラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        sys.exit(103)

# デバイス管理
def get_devices():
    """基本的なデバイス一覧取得"""
    devices = []
    try:
        # /proc/partitionsから基本的な検出
        with open('/proc/partitions', 'r') as f:
            lines = f.readlines()
        
        for line in lines[2:]:  # ヘッダーをスキップ
            parts = line.strip().split()
            if len(parts) >= 4:
                device_name = parts[3]
                # 基本的なフィルタリング（数字で終わるパーティションは除外）
                if not device_name[-1].isdigit() and device_name.startswith(('sd', 'nvme', 'hd')):
                    devices.append(f"/dev/{device_name}")
        
        print(f"検出デバイス: {devices}", file=sys.stderr, flush=True)
        return devices
    except Exception as e:
        print(f"デバイス検出エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        return []

def get_smart_data(device):
    """smartctl実行・JSON取得"""
    try:
        # デバイスタイプに応じて適切なオプションを選択
        device_options = []
        
        # SATAデバイスの場合は-d satを試す
        if device.startswith('/dev/sd'):
            device_options = ['sat', 'auto']  # satを優先、失敗時はauto
        elif device.startswith('/dev/nvme'):
            device_options = ['nvme', 'auto']  # NVMeデバイス
        else:
            device_options = ['auto']  # その他はautoのみ
        
        # 各オプションを順に試行
        for device_type in device_options:
            cmd = ['sudo', 'smartctl', '-d', device_type, '-j', '-a', device]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode in [0, 4]:  # 0:正常, 4:SMART有効だが警告あり
                try:
                    smart_data = json.loads(result.stdout)
                    smart_data['_collection_timestamp'] = datetime.datetime.now().isoformat()
                    smart_data['_device_path'] = device
                    smart_data['_device_type'] = device_type
                    return smart_data
                except json.JSONDecodeError as e:
                    print(f"smartctl JSON解析エラー {device} (-d {device_type}): {repr(e)}", file=sys.stderr, flush=True)
                    continue
            else:
                print(f"smartctl実行エラー {device} (-d {device_type}): {result.returncode}", file=sys.stderr, flush=True)
                continue
        
        # 全てのオプションで失敗
        print(f"smartctl 全オプション失敗 {device}", file=sys.stderr, flush=True)
        return None
    except subprocess.TimeoutExpired:
        print(f"smartctl タイムアウト {device}", file=sys.stderr, flush=True)
        return None
    except Exception as e:
        print(f"SMART取得エラー {device}: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        return None

# データ管理
def save_data(data):
    """月毎ディレクトリ・JSON保存"""
    try:
        now = datetime.datetime.now()
        month_dir = Path('data/smart') / f"{now.year:04d}-{now.month:02d}"
        month_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = now.strftime("%Y%m%d_%H%M%S")
        filename = month_dir / f"smart_{timestamp}.json"
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        
        return str(filename)
    except Exception as e:
        print(f"データ保存エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        return None

def load_historical_data(days_back=None):
    """過去データ読み込み"""
    try:
        data_files = []
        data_dir = Path('data/smart')
        
        if not data_dir.exists():
            return []
        
        # 全JSONファイルを取得
        for month_dir in data_dir.iterdir():
            if month_dir.is_dir():
                for json_file in month_dir.glob('smart_*.json'):
                    data_files.append(json_file)
        
        # 日付でソート
        data_files.sort(key=lambda x: x.name, reverse=True)
        
        # 指定日数分のデータを読み込み
        if days_back:
            cutoff_date = datetime.datetime.now() - datetime.timedelta(days=days_back)
            cutoff_str = cutoff_date.strftime("%Y%m%d")
            data_files = [f for f in data_files if f.name.split('_')[1][:8] >= cutoff_str]
        
        historical_data = []
        for file_path in data_files[:10]:  # 最大10ファイル
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    historical_data.append(data)
            except Exception as e:
                print(f"履歴データ読み込みエラー {file_path}: {repr(e)}", file=sys.stderr, flush=True)
        
        return historical_data
    except Exception as e:
        print(f"履歴データ取得エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        return []

def convert_to_tsv(smart_data):
    """SMART データをTSV形式に変換（ATTRIBUTE_NAMEとRAW_VALUEのみ）"""
    try:
        if not smart_data or not isinstance(smart_data, list):
            return ""
        
        tsv_lines = []
        headers = ["device", "timestamp", "attribute_name", "raw_value"]
        tsv_lines.append("\t".join(headers))
        
        for device_data in smart_data:
            if not isinstance(device_data, dict):
                continue
                
            device_path = device_data.get('_device_path', 'unknown')
            timestamp = device_data.get('_collection_timestamp', 'unknown')
            
            # SMART属性データの抽出
            ata_smart = device_data.get('ata_smart_attributes', {})
            table = ata_smart.get('table', [])
            
            for attr in table:
                if isinstance(attr, dict):
                    line = [
                        device_path,
                        timestamp,
                        str(attr.get('name', '')),
                        str(attr.get('raw', {}).get('string', ''))
                    ]
                    tsv_lines.append("\t".join(line))
        
        return "\n".join(tsv_lines)
    except Exception as e:
        print(f"TSV変換エラー: {repr(e)}", file=sys.stderr, flush=True)
        return ""

# LLM分析
def analyze_with_llm(current_data, comparison_data=None, analysis_type="current"):
    """Gemini API呼び出しによる分析"""
    try:
        config = load_config()
        api_key = config.get('llm_api_key')
        model = config.get('llm_model', 'gemini-pro')
        
        if not api_key or api_key == "YOUR_GEMINI_API_KEY":
            print("LLM APIキーが設定されていません", file=sys.stderr, flush=True)
            return None
        
        # プロンプト作成
        if analysis_type == "current":
            prompt = create_analysis_prompt(current_data, None, "現在のSMART値を分析してください。")
        elif analysis_type == "daily":
            prompt = create_analysis_prompt(current_data, comparison_data, "1日前との比較でSMART値を分析してください。")
        elif analysis_type == "weekly":
            prompt = create_analysis_prompt(current_data, comparison_data, "1週間前との比較でSMART値を分析してください。")
        elif analysis_type == "monthly":
            prompt = create_analysis_prompt(current_data, comparison_data, "1ヶ月前との比較でSMART値を分析してください。")
        else:
            prompt = create_analysis_prompt(current_data, comparison_data, "SMART値を分析してください。")
        
        # Gemini API呼び出し
        headers = {
            'Content-Type': 'application/json',
        }
        
        url = f'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}'
        
        payload = {
            "contents": [{
                "parts": [{
                    "text": prompt
                }]
            }]
        }
        
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        
        if response.status_code == 200:
            result = response.json()
            if 'candidates' in result and len(result['candidates']) > 0:
                text = result['candidates'][0]['content']['parts'][0]['text']
                print(f"LLM分析完了 ({analysis_type})", file=sys.stderr, flush=True)
                return {
                    'analysis_type': analysis_type,
                    'timestamp': datetime.datetime.now().isoformat(),
                    'prompt': prompt,
                    'result': text,
                    'status': 'success'
                }
            else:
                print(f"LLM応答が空です: {result}", file=sys.stderr, flush=True)
                return None
        else:
            print(f"LLM API エラー: {response.status_code}, {response.text}", file=sys.stderr, flush=True)
            return None
            
    except requests.RequestException as e:
        print(f"LLM API リクエストエラー: {repr(e)}", file=sys.stderr, flush=True)
        return None
    except Exception as e:
        print(f"LLM分析エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        return None

def create_analysis_prompt(current_data, comparison_data, instruction):
    """分析用プロンプト作成"""
    try:
        prompt = f"""
{instruction}

以下の情報を基に、ハードディスク/SSDの状態を分析してください：

現在のSMART情報（TSV形式）:
{convert_to_tsv(current_data)}
"""
        
        if comparison_data:
            prompt += f"""
比較用SMART情報（TSV形式）:
{convert_to_tsv(comparison_data)}
"""
        
        prompt += """
データ形式：
- device: デバイスパス
- timestamp: 収集時刻
- attribute_name: SMART属性名
- raw_value: 生の値

分析観点：
1. 重要なSMART属性のRAW_VALUE値を分析
   - Reallocated_Sector_Ct: 再配置セクタ数
   - Current_Pending_Sector: 代替処理待ちセクタ数
   - Offline_Uncorrectable: オフライン修復不可セクタ数
   - Temperature_Celsius: 温度
   - Power_On_Hours: 電源投入時間
   - Load_Cycle_Count: ロードサイクル回数
2. 異常な値や急激な変化の検出
3. 比較データがある場合は変化傾向の分析

回答形式：
- 状態: [正常/注意/警告/危険]
- 主な問題: [問題の概要]
- 推奨アクション: [具体的な対応]
- 詳細分析: [技術的詳細]
"""
        
        return prompt
    except Exception as e:
        print(f"プロンプト作成エラー: {repr(e)}", file=sys.stderr, flush=True)
        return ""

def analyze_data():
    """分析処理（4パターン）"""
    try:
        # 最新データを取得
        latest_data = load_historical_data()
        if not latest_data:
            print("分析対象データがありません", file=sys.stderr, flush=True)
            return
        
        current_data = latest_data[0]  # 最新データ
        
        # 4種類の分析を実行
        analyses = []
        
        # 1. 現在の状態分析
        result1 = analyze_with_llm(current_data, None, "current")
        if result1:
            analyses.append(result1)
        
        # 2. 1日前との比較
        daily_data = load_historical_data(days_back=2)
        if len(daily_data) >= 2:
            result2 = analyze_with_llm(current_data, daily_data[1], "daily")
            if result2:
                analyses.append(result2)
        
        # 3. 1週間前との比較
        weekly_data = load_historical_data(days_back=8)
        if len(weekly_data) >= 2:
            # 約1週間前のデータを探す
            week_old = None
            for data in weekly_data:
                # データがリストの場合は最初の要素を使用
                if isinstance(data, list) and len(data) > 0:
                    data_item = data[0]
                else:
                    data_item = data
                
                if isinstance(data_item, dict):
                    timestamp = data_item.get('_collection_timestamp', '')
                    if timestamp:
                        try:
                            data_time = datetime.datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                            if data_time < datetime.datetime.now() - datetime.timedelta(days=6):
                                week_old = data
                                break
                        except:
                            continue
            
            if week_old:
                result3 = analyze_with_llm(current_data, week_old, "weekly")
                if result3:
                    analyses.append(result3)
        
        # 4. 1ヶ月前との比較
        monthly_data = load_historical_data(days_back=35)
        if len(monthly_data) >= 2:
            # 約1ヶ月前のデータを探す
            month_old = None
            for data in monthly_data:
                # データがリストの場合は最初の要素を使用
                if isinstance(data, list) and len(data) > 0:
                    data_item = data[0]
                else:
                    data_item = data
                
                if isinstance(data_item, dict):
                    timestamp = data_item.get('_collection_timestamp', '')
                    if timestamp:
                        try:
                            data_time = datetime.datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                            if data_time < datetime.datetime.now() - datetime.timedelta(days=28):
                                month_old = data
                                break
                        except:
                            continue
            
            if month_old:
                result4 = analyze_with_llm(current_data, month_old, "monthly")
                if result4:
                    analyses.append(result4)
        
        # 分析結果を保存
        if analyses:
            save_analysis_results(analyses)
            # アラート判定
            check_for_alerts(analyses)
        
        print(f"分析完了: {len(analyses)}件", file=sys.stderr, flush=True)
        
    except Exception as e:
        print(f"分析処理エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)

def save_analysis_results(analyses):
    """分析結果の保存"""
    try:
        now = datetime.datetime.now()
        month_dir = Path('data/smart') / f"{now.year:04d}-{now.month:02d}"
        month_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = now.strftime("%Y%m%d_%H%M%S")
        filename = month_dir / f"analysis_{timestamp}.json"
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(analyses, f, ensure_ascii=False, indent=2)
        
        print(f"分析結果保存: {filename}", file=sys.stderr, flush=True)
    except Exception as e:
        print(f"分析結果保存エラー: {repr(e)}", file=sys.stderr, flush=True)

def check_for_alerts(analyses):
    """アラート判定"""
    try:
        config = load_config()
        alert_command = config.get('alert_command')
        
        # 危険または警告レベルをチェック
        alert_triggered = False
        for analysis in analyses:
            result_text = analysis.get('result', '').lower()
            if '危険' in result_text or '警告' in result_text or 'critical' in result_text or 'warning' in result_text:
                alert_triggered = True
                break
        
        if alert_triggered and alert_command:
            try:
                # アラートコマンド実行
                subprocess.run(['bash', alert_command], timeout=30)
                print("アラート通知実行", file=sys.stderr, flush=True)
            except Exception as e:
                print(f"アラート実行エラー: {repr(e)}", file=sys.stderr, flush=True)
    
    except Exception as e:
        print(f"アラート判定エラー: {repr(e)}", file=sys.stderr, flush=True)

# メイン処理
def collect_smart_data():
    """SMART情報収集処理"""
    try:
        config = load_config()
        devices = get_devices()
        
        if not devices:
            print("監視対象デバイスが見つかりません", file=sys.stderr, flush=True)
            return None
        
        all_data = []
        for device in devices:
            print(f"SMART収集中: {device}", file=sys.stderr, flush=True)
            smart_data = get_smart_data(device)
            if smart_data:
                all_data.append(smart_data)
            time.sleep(config.get('device_wait_seconds', 3))
        
        if all_data:
            filename = save_data(all_data)
            print(f"データ保存完了: {filename}", file=sys.stderr, flush=True)
            return all_data
        else:
            print("SMART データが取得できませんでした", file=sys.stderr, flush=True)
            return None
    except Exception as e:
        print(f"SMART収集エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        return None

def cleanup_old_data():
    """古いデータの削除"""
    try:
        config = load_config()
        retention_years = config.get('data_retention_years', 2)
        cutoff_date = datetime.datetime.now() - datetime.timedelta(days=retention_years * 365)
        
        data_dir = Path('data/smart')
        if not data_dir.exists():
            return
        
        deleted_count = 0
        for month_dir in data_dir.iterdir():
            if month_dir.is_dir():
                try:
                    # ディレクトリ名から年月を取得
                    year_month = month_dir.name
                    if len(year_month) == 7 and year_month[4] == '-':
                        year = int(year_month[:4])
                        month = int(year_month[5:7])
                        dir_date = datetime.datetime(year, month, 1)
                        
                        if dir_date < cutoff_date:
                            # ディレクトリ内のファイルを削除
                            for file_path in month_dir.glob('*.json'):
                                file_path.unlink()
                                deleted_count += 1
                            # 空のディレクトリを削除
                            if not any(month_dir.iterdir()):
                                month_dir.rmdir()
                except (ValueError, OSError) as e:
                    print(f"ディレクトリ削除エラー {month_dir}: {repr(e)}", file=sys.stderr, flush=True)
        
        if deleted_count > 0:
            print(f"古いデータ削除: {deleted_count}ファイル", file=sys.stderr, flush=True)
    except Exception as e:
        print(f"データクリーンアップエラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)

def main_loop():
    """定期実行メインループ"""
    try:
        config = load_config()
        collection_interval = config.get('collection_interval_hours', 1) * 3600
        analysis_interval = config.get('analysis_interval_hours', 24) * 3600
        
        last_collection = 0
        last_analysis = 0
        
        print("SMART監視システム開始", file=sys.stderr, flush=True)
        
        while True:
            try:
                current_time = time.time()
                
                # データ収集
                if current_time - last_collection >= collection_interval:
                    collect_smart_data()
                    cleanup_old_data()
                    last_collection = current_time
                
                # 分析実行
                if current_time - last_analysis >= analysis_interval:
                    analyze_data()
                    last_analysis = current_time
                
                # 1秒スリープして継続チェック
                time.sleep(1)
                
            except KeyboardInterrupt:
                print("監視システム停止", file=sys.stderr, flush=True)
                break
            except Exception as e:
                print(f"メインループエラー: {repr(e)}", file=sys.stderr, flush=True)
                traceback.print_exc(file=sys.stderr)
                time.sleep(60)  # エラー時は1分待機
                
    except Exception as e:
        print(f"システム初期化エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        sys.exit(104)

if __name__ == "__main__":
    main_loop()