import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: TrainingModel
    @EnvironmentObject private var language: LanguageStore
    @State private var showingReference = false
    private let referenceURL = URL(string: "https://lovepose48.com/poses/")!
    var body: some View {
        Form {
            Section("トレーニング".localized) {
                Picker("言語".localized, selection: $language.language) {
                    ForEach(AppLanguage.allCases) { item in Text(item.displayName).tag(item) }
                }
                Stepper("刺激フェーズ: %d秒".localizedFormat(model.stimulusSeconds), value: $model.stimulusSeconds, in: 10...3600, step: 10)
                Stepper("休憩フェーズ: %d秒".localizedFormat(model.restSeconds), value: $model.restSeconds, in: 5...1800, step: 5)
                Stepper("セット数: %d".localizedFormat(model.totalSets), value: $model.totalSets, in: 1...20)
                Toggle("自動コントロール".localized, isOn: $model.automaticControl)
                HStack {
                    Text("自動休憩しきい値".localized)
                    Slider(value: $model.automaticThreshold, in: 0.4...0.95)
                    Text("\(Int(model.automaticThreshold * 100))%")
                }
            }
            Section("参考".localized) {
                Button("参考サイトをアプリ内で開く".localized, systemImage: "safari") {
                    showingReference = true
                }
                Text("ページは保存せず、アプリ内の一時WebViewで表示します。".localized)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("動画はアプリに保存・送信されず、選択したローカルファイルを再生します。".localized)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(width: 440)
        .sheet(isPresented: $showingReference) {
            VStack(spacing: 0) {
                HStack {
                    Text("参考サイト".localized).font(.headline)
                    Spacer()
                    Button("閉じる".localized) { showingReference = false }
                }.padding()
                InAppReferenceView(url: referenceURL)
            }
            .frame(minWidth: 900, minHeight: 700)
        }
    }
}
