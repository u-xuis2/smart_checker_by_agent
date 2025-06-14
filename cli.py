#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import json
import traceback
from pathlib import Path

# main.pyから必要な関数をインポート
try:
    from main import (
        collect_smart_data, 
        analyze_data, 
        load_config,
        load_historical_data,
        get_devices,
        get_smart_data
    )
except ImportError as e:
    print(f"main.pyからのインポートエラー: {repr(e)}", file=sys.stderr, flush=True)
    sys.exit(101)

def cli_collect():
    """即時SMART取得"""
    try:
        print("SMART情報を収集中...", file=sys.stderr, flush=True)
        result = collect_smart_data()
        if result:
            print(json.dumps({"status": "success", "message": "SMART収集完了", "devices": len(result)}, ensure_ascii=False))
        else:
            print(json.dumps({"status": "error", "message": "SMART収集失敗"}, ensure_ascii=False))
            sys.exit(102)
    except Exception as e:
        print(f"収集エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        print(json.dumps({"status": "error", "message": str(e)}, ensure_ascii=False))
        sys.exit(103)

def cli_analyze():
    """即時分析実行"""
    try:
        print("分析を実行中...", file=sys.stderr, flush=True)
        analyze_data()
        print(json.dumps({"status": "success", "message": "分析完了"}, ensure_ascii=False))
    except Exception as e:
        print(f"分析エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        print(json.dumps({"status": "error", "message": str(e)}, ensure_ascii=False))
        sys.exit(104)

def cli_status():
    """システム状態表示"""
    try:
        # 設定確認
        config = load_config()
        
        # デバイス確認
        devices = get_devices()
        
        # 最新データ確認
        latest_data = load_historical_data()
        
        # 最新のタイムスタンプを取得
        last_collection = None
        if latest_data:
            first_data = latest_data[0]
            if isinstance(first_data, list) and len(first_data) > 0:
                # リストの場合は最初のデバイスのタイムスタンプを取得
                last_collection = first_data[0].get('_collection_timestamp') if isinstance(first_data[0], dict) else None
            elif isinstance(first_data, dict):
                # 辞書の場合は直接タイムスタンプを取得
                last_collection = first_data.get('_collection_timestamp')
        
        status_info = {
            "status": "success",
            "config_loaded": True,
            "devices_count": len(devices),
            "devices": devices,
            "latest_data_count": len(latest_data) if latest_data else 0,
            "last_collection": last_collection
        }
        
        print(json.dumps(status_info, ensure_ascii=False, indent=2))
    except Exception as e:
        print(f"状態確認エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        print(json.dumps({"status": "error", "message": str(e)}, ensure_ascii=False))
        sys.exit(105)

def cli_test_device(device_path):
    """指定デバイスのテスト"""
    try:
        print(f"デバイステスト中: {device_path}", file=sys.stderr, flush=True)
        smart_data = get_smart_data(device_path)
        
        if smart_data:
            result = {
                "status": "success",
                "device": device_path,
                "smart_available": True,
                "device_type": smart_data.get('_device_type', 'unknown'),
                "model": smart_data.get('model_name', 'unknown'),
                "serial": smart_data.get('serial_number', 'unknown'),
                "capacity": smart_data.get('user_capacity', {}).get('bytes', 0)
            }
        else:
            result = {
                "status": "warning",
                "device": device_path,
                "smart_available": False,
                "message": "SMART情報が取得できませんでした"
            }
        
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except Exception as e:
        print(f"デバイステストエラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        print(json.dumps({"status": "error", "device": device_path, "message": str(e)}, ensure_ascii=False))
        sys.exit(106)

def cli_history(days):
    """履歴データ表示"""
    try:
        print(f"過去{days}日間の履歴を取得中...", file=sys.stderr, flush=True)
        historical_data = load_historical_data(days_back=days)
        
        result = {
            "status": "success",
            "days_back": days,
            "data_count": len(historical_data),
            "data": []
        }
        
        for data in historical_data:
            if isinstance(data, list):
                for device_data in data:
                    if isinstance(device_data, dict):
                        result["data"].append({
                            "timestamp": device_data.get('_collection_timestamp'),
                            "device": device_data.get('_device_path'),
                            "model": device_data.get('model_name', 'unknown')
                        })
            elif isinstance(data, dict):
                result["data"].append({
                    "timestamp": data.get('_collection_timestamp'),
                    "device": data.get('_device_path'),
                    "model": data.get('model_name', 'unknown')
                })
        
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except Exception as e:
        print(f"履歴取得エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        print(json.dumps({"status": "error", "message": str(e)}, ensure_ascii=False))
        sys.exit(107)

def cli_prompt(analysis_type):
    """最新分析のプロンプト表示"""
    try:
        print(f"最新の{analysis_type}分析プロンプトを取得中...", file=sys.stderr, flush=True)
        
        # 最新の分析結果ファイルを検索
        data_dir = Path('data/smart')
        analysis_files = []
        
        if data_dir.exists():
            for month_dir in data_dir.iterdir():
                if month_dir.is_dir():
                    for analysis_file in month_dir.glob('analysis_*.json'):
                        analysis_files.append(analysis_file)
        
        if not analysis_files:
            print(json.dumps({"status": "error", "message": "分析結果ファイルが見つかりません"}, ensure_ascii=False))
            return
        
        # 最新のファイルを取得
        analysis_files.sort(key=lambda x: x.name, reverse=True)
        latest_file = analysis_files[0]
        
        # 分析結果を読み込み
        with open(latest_file, 'r', encoding='utf-8') as f:
            analyses = json.load(f)
        
        # 指定されたタイプの分析を検索
        target_analysis = None
        for analysis in analyses:
            if analysis.get('analysis_type') == analysis_type:
                target_analysis = analysis
                break
        
        if not target_analysis:
            available_types = [a.get('analysis_type', 'unknown') for a in analyses]
            print(json.dumps({
                "status": "error", 
                "message": f"分析タイプ '{analysis_type}' が見つかりません",
                "available_types": available_types
            }, ensure_ascii=False))
            return
        
        # プロンプトを表示
        result = {
            "status": "success",
            "analysis_type": analysis_type,
            "timestamp": target_analysis.get('timestamp'),
            "file_path": str(latest_file),
            "prompt": target_analysis.get('prompt', 'プロンプト情報がありません')
        }
        
        print(json.dumps(result, ensure_ascii=False, indent=2))
        
    except Exception as e:
        print(f"プロンプト取得エラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        print(json.dumps({"status": "error", "message": str(e)}, ensure_ascii=False))
        sys.exit(108)

def main():
    """メイン処理"""
    parser = argparse.ArgumentParser(description='SMART監視システム CLI補助ツール')
    
    # サブコマンド
    subparsers = parser.add_subparsers(dest='command', help='実行コマンド')
    
    # collect サブコマンド
    collect_parser = subparsers.add_parser('collect', help='即時SMART収集')
    
    # analyze サブコマンド
    analyze_parser = subparsers.add_parser('analyze', help='即時分析実行')
    
    # status サブコマンド
    status_parser = subparsers.add_parser('status', help='システム状態表示')
    
    # test サブコマンド
    test_parser = subparsers.add_parser('test', help='デバイステスト')
    test_parser.add_argument('device', help='テスト対象デバイス (例: /dev/sda)')
    
    # history サブコマンド
    history_parser = subparsers.add_parser('history', help='履歴データ表示')
    history_parser.add_argument('--days', type=int, default=7, help='過去何日分のデータを表示するか (デフォルト: 7)')
    
    # prompt サブコマンド
    prompt_parser = subparsers.add_parser('prompt', help='最新分析のプロンプト表示')
    prompt_parser.add_argument('--analysis-type', type=str, default='current', help='表示する分析タイプ (current/daily/weekly/monthly)')
    
    # 旧形式のオプション（後方互換性）
    parser.add_argument('--collect', action='store_true', help='即時SMART収集')
    parser.add_argument('--analyze', action='store_true', help='即時分析実行')
    
    args = parser.parse_args()
    
    try:
        # 新形式のサブコマンド処理
        if args.command == 'collect':
            cli_collect()
        elif args.command == 'analyze':
            cli_analyze()
        elif args.command == 'status':
            cli_status()
        elif args.command == 'test':
            cli_test_device(args.device)
        elif args.command == 'history':
            cli_history(args.days)
        elif args.command == 'prompt':
            cli_prompt(args.analysis_type)
        
        # 旧形式のオプション処理（後方互換性）
        elif args.collect:
            cli_collect()
        elif args.analyze:
            cli_analyze()
        
        else:
            parser.print_help()
            sys.exit(108)
            
    except KeyboardInterrupt:
        print("\\n処理が中断されました", file=sys.stderr, flush=True)
        sys.exit(109)
    except Exception as e:
        print(f"予期しないエラー: {repr(e)}", file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        sys.exit(110)

if __name__ == "__main__":
    main()