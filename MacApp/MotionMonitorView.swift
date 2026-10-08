import SwiftUI

struct MotionMonitorView: View {
    @ObservedObject var receiver: MacMotionReceiver

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Apple Watchの動き", systemImage: "applewatch")
                Spacer()
                Text(receiver.latestSample == nil ? "未接続" : "受信中")
                    .foregroundStyle(receiver.latestSample == nil ? Color.secondary : Color.green)
            }
            ProgressView(value: receiver.intensity)
            Text("動きの強さ \(Int(receiver.intensity * 100))%")
                .font(.caption).foregroundStyle(.secondary)
            Picker("装着腕", selection: $receiver.wristSide) {
                ForEach(WristSide.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Button(receiver.isCalibrating ? "静止してください（\(receiver.calibrationProgress)/20）" : "装着腕をキャリブレーション") {
                receiver.startCalibration()
            }
            .disabled(receiver.isCalibrating)
            if let date = receiver.lastUpdate { Text("最終受信: \(date, style: .time)").font(.caption2).foregroundStyle(.secondary) }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
