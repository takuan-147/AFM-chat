import Foundation

enum L10nKey {
    case appName, conversations, newConversation, deleteConversation, noConversation
    case startConversation, messagePlaceholder, send, stop, settings, model
    case local, pcc, thinking, processing, responseTime, error, retry
    case general, language, defaultModel, customInstructions, customInstructionsHint
    case customInstructionsFootnote, fmCLI, license, licenseTitle, licenseExplanation
    case terminalInstruction, copyCommand, openTerminal, checkAgain, close
    case fmNotFound, modelUnavailable, genericFailure, emptyResponse
    case privacyLocal, privacyPCC

    func value(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.appName, .japanese): "AFMチャット"
        case (.appName, .english): "AFM Chat"
        case (.conversations, .japanese): "会話"
        case (.conversations, .english): "Conversations"
        case (.newConversation, .japanese): "新しい会話"
        case (.newConversation, .english): "New Conversation"
        case (.deleteConversation, .japanese): "会話を削除"
        case (.deleteConversation, .english): "Delete Conversation"
        case (.noConversation, .japanese): "会話が選択されていません"
        case (.noConversation, .english): "No Conversation Selected"
        case (.startConversation, .japanese): "新しい会話を始めましょう"
        case (.startConversation, .english): "Start a new conversation"
        case (.messagePlaceholder, .japanese): "メッセージ"
        case (.messagePlaceholder, .english): "Message"
        case (.send, .japanese): "送信"
        case (.send, .english): "Send"
        case (.stop, .japanese): "停止"
        case (.stop, .english): "Stop"
        case (.settings, .japanese): "設定"
        case (.settings, .english): "Settings"
        case (.model, .japanese): "モデル"
        case (.model, .english): "Model"
        case (.local, .japanese): "ローカル"
        case (.local, .english): "Local"
        case (.pcc, _): "Private Cloud Computing"
        case (.thinking, .japanese): "Thinking / 処理の詳細"
        case (.thinking, .english): "Thinking / Process Details"
        case (.processing, .japanese): "考えています"
        case (.processing, .english): "Thinking"
        case (.responseTime, .japanese): "応答時間"
        case (.responseTime, .english): "Response time"
        case (.error, .japanese): "エラー"
        case (.error, .english): "Error"
        case (.retry, .japanese): "再試行"
        case (.retry, .english): "Retry"
        case (.general, .japanese): "一般"
        case (.general, .english): "General"
        case (.language, .japanese): "UIの言語"
        case (.language, .english): "UI Language"
        case (.defaultModel, .japanese): "新しい会話の既定モデル"
        case (.defaultModel, .english): "Default model for new conversations"
        case (.customInstructions, .japanese): "カスタム指示"
        case (.customInstructions, .english): "Custom Instructions"
        case (.customInstructionsHint, .japanese): "例：簡潔な日本語で答えてください。"
        case (.customInstructionsHint, .english): "Example: Answer concisely and include sources when possible."
        case (.customInstructionsFootnote, .japanese): "新しく開始する会話に適用されます。既存の会話は開始時の指示を保持します。"
        case (.customInstructionsFootnote, .english): "Applied to newly started conversations. Existing conversations keep their initial instructions."
        case (.fmCLI, _): "fm CLI"
        case (.license, .japanese): "ライセンスを確認"
        case (.license, .english): "Check License"
        case (.licenseTitle, .japanese): "fmライセンスへの同意が必要です"
        case (.licenseTitle, .english): "fm License Agreement Required"
        case (.licenseExplanation, .japanese): "下記のライセンスを確認し、ターミナルでコマンドを実行して同意してください。管理者権限が必要な場合があります。"
        case (.licenseExplanation, .english): "Review the license below, then agree by running the command in Terminal. Administrator privileges may be required."
        case (.terminalInstruction, .japanese): "ターミナルで次を実行："
        case (.terminalInstruction, .english): "Run this in Terminal:"
        case (.copyCommand, .japanese): "コマンドをコピー"
        case (.copyCommand, .english): "Copy Command"
        case (.openTerminal, .japanese): "ターミナルを開く"
        case (.openTerminal, .english): "Open Terminal"
        case (.checkAgain, .japanese): "同意状態を再確認"
        case (.checkAgain, .english): "Check Again"
        case (.close, .japanese): "閉じる"
        case (.close, .english): "Close"
        case (.fmNotFound, .japanese): "macOS 27の /usr/bin/fm が見つかりません。OSのバージョンを確認してください。"
        case (.fmNotFound, .english): "The macOS 27 /usr/bin/fm command was not found. Check your OS version."
        case (.modelUnavailable, .japanese): "選択したモデルは、このバージョンのfmまたは現在のMacでは利用できません。"
        case (.modelUnavailable, .english): "The selected model is unavailable in this fm version or on this Mac."
        case (.genericFailure, .japanese): "応答を生成できませんでした。"
        case (.genericFailure, .english): "The response could not be generated."
        case (.emptyResponse, .japanese): "モデルから空の応答が返されました。"
        case (.emptyResponse, .english): "The model returned an empty response."
        case (.privacyLocal, .japanese): "オンデバイスモデル。内容はこのMac上で処理されます。"
        case (.privacyLocal, .english): "On-device model. Content is processed on this Mac."
        case (.privacyPCC, .japanese): "AppleのPrivate Cloud Computeを使用します。ネットワーク接続と利用資格が必要です。"
        case (.privacyPCC, .english): "Uses Apple Private Cloud Compute. Network access and eligibility are required."
        }
    }
}

extension TimeInterval {
    func responseTimeText(language: AppLanguage) -> String {
        let totalTenths = max(0, Int((self * 10).rounded()))
        let minutes = totalTenths / 600
        let seconds = Double(totalTenths % 600) / 10
        if language == .japanese {
            return String(format: "%d分 %.1f秒", minutes, seconds)
        }
        return String(format: "%dm %.1fs", minutes, seconds)
    }
}
