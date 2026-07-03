//
//  TimeInterval+Formatting.swift
//  passage
//
//  독서 시간 표시 헬퍼.
//

import Foundation

extension TimeInterval {
    /// 사람이 읽기 좋은 독서 시간. 예: "1시간 23분", "45분", "30초".
    var readableDuration: String {
        let totalSeconds = max(0, Int(self))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)시간 \(minutes)분" : "\(hours)시간"
        } else if minutes > 0 {
            return "\(minutes)분"
        } else {
            return "\(seconds)초"
        }
    }

    /// 진행 중 타이머용 시계 표기. 예: "1:05:09", "23:41".
    var clockString: String {
        let total = max(0, Int(self))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}
