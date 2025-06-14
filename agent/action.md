# 手順

## iagent/in/main.mdの編集

## claudeの起動

## review.mdの指示の実施

次の指示をclaude-codeで実施

```
agent/review.mdの指示にしたがって作業を実施してください。
```
## agent/out/out_review.mdの確認とagent/in/main.mdの修正

内容の確認とmain.mdの調整

## ready.mdの指示の実施

次の指示をclaude-codeで実施

```
agent/ready.mdの指示にしたがって作業を実施してください。
```

# action-a.mdの確認

プランAでの具体的な仕様の確認
必要に応じて修正

# action-b.mdの確認

プランBでの具体的な仕様の確認
必要に応じて修正

## claudeの再起動

一回停止して次のコマンドで再起動

```
claude --dangerously-skip-permissions
```

# 上記いずれかのactionによる実装の開始

```
agent/out/action-a.mdを読み込んで実装までを実施してください。テストシェルは作りますが、テストの実施は設定の入力と作成結果の確認後に別途実施を依頼します。
```

```
agent/out/action-b.mdを読み込んで実装までを実施してください。テストシェルは作りますが、テストの実施は設定の入力と作成結果の確認後に別途実施を依頼します。
```

# テストの実施

```
各種テスト、動作の確認、問題がある場合の処理の調整を行ってください。
```

# supervisor.mdによるsupervisorの準備

```
agent/supervisor.mdの内容に従って作業を実施してください。
```