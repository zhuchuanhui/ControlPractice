import SwiftUI

struct MotionMonitorView: View {
    @ObservedObject var receiver: MacMotionReceiver

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Apple Watchの動き".localized, systemImage: "applewatch")
                Spacer()
                Text((receiver.latestSample == nil ? "未接続" : "受信中").localized)
                    .foregroundStyle(receiver.latestSample == nil ? Color.secondary : Color.green)
            }
            Button("Watchを接続".localized) {
                receiver.requestConnection()
            }
            .buttonStyle(.borderedProminent)
            .help("iPhoneのControl Practiceを起動し、Watchアプリを接続してください".localized)
            ProgressView(value: receiver.intensity)
            Text("動きの強さ %d%%".localizedFormat(Int(receiver.intensity * 100)))
                .font(.caption).foregroundStyle(.secondary)
            Picker("装着腕".localized, selection: $receiver.wristSide) {
                ForEach(WristSide.allCases, id: \.self) { Text(AppText.value($0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented)
            Button(receiver.isCalibrating ? "静止してください（%d/20）".localizedFormat(receiver.calibrationProgress) : "装着腕をキャリブレーション".localized) {
                receiver.startCalibration()
            }
            .disabled(receiver.isCalibrating)
            Button("Watch受信テスト".localized) {
                receiver.sendTestMotion()
            }
            .buttonStyle(.bordered)
            .help("強い動きの警告を出さず、Watch信号の受信だけを確認".localized)
            if let date = receiver.lastUpdate { Text("最終受信: ".localized + date.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary) }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
