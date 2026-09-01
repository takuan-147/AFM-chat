# AFM Chat

macOS 27に搭載されている`fm`コマンドを利用して、Apple Foundation Modelsと会話するためのmacOSアプリです。

## 必要環境

- macOS 27以降
- Xcode 27以降
- Apple Silicon搭載Mac
- Apple Intelligenceが利用可能で、有効になっていること
- `/usr/bin/fm`が利用可能であること

利用できるモデルは、macOSと`fm`のバージョン、デバイス、地域、Apple Intelligenceの設定によって異なる場合があります。

## ビルド

1. このリポジトリをクローンします。

   ```shell
   git clone https://github.com/takuan-147/AFM-chat.git
   ```

2. Xcodeプロジェクトを開きます。

   ```shell
   open "AFM Chat.xcodeproj"
   ```

3. XcodeでmacOSの`AFM Chat`スキームを選択します。
4. Runボタンを押してアプリを起動します。

## fmライセンス

`fm`の利用前にライセンスへの同意を求められる場合があります。

アプリにライセンス画面が表示された場合は、内容を確認したうえでターミナルから次のコマンドを実行してください。

```shell
sudo fm license
```

同意後、アプリの「同意状態を再確認」を押してください。

## モデル

入力欄の下にあるドロップダウンからモデルを選択できます。

| 表示 | `fm`モデル | 処理場所 |
| --- | --- | --- |
| ローカル | `system` | このMac上 |
| Private Cloud Computing | `pcc` | AppleのPrivate Cloud Compute |

macOS 27のBeta3以降など、`pcc`に対応していない`fm`では利用不可エラーが表示されます。

## 保存されるデータ

会話データは次の場所に保存されます。

```text
~/Library/Application Support/AFM Chat/
```

| ファイル／フォルダ | 内容 |
| --- | --- |
| `sessions.json` | アプリに表示するセッションとメッセージ |
| `Transcripts/` | `fm --resume`と`--save-transcript`で使用する会話履歴 |

セッションを削除すると、対応する会話データとトランスクリプトも削除されます。

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

### Permissions
- **Commercial use**: You can use this project for commercial purposes.
- **Modification**: You can modify the code as you wish.
- **Distribution**: You can share this project freely.
- **Private use**: You can use this project in private.

### Limitations
- **Liability**: The author is not responsible for any damages caused by using this project.
- **Warranty**: This project is provided "as-is," without any warranty of any kind.
