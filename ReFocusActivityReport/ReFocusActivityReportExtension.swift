import DeviceActivity
import SwiftUI

@main
struct ReFocusActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Total activity report - shows overall usage
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }

        // Top apps report - shows most used apps
        TopAppsReport { topApps in
            TopAppsView(activityReport: topApps)
        }
    }
}

// MARK: - Report Contexts

extension DeviceActivityReport.Context {
    static let totalActivity = Self("totalActivity")
    static let topApps = Self("topApps")
}

// MARK: - Total Activity Report

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivityReport) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        var totalDuration: TimeInterval = 0
        var categoryBreakdown: [String: TimeInterval] = [:]
        var appUsage: [(name: String, duration: TimeInterval, bundleID: String?)] = []

        for await activityData in data {
            for await segment in activityData.activitySegments {
                totalDuration += segment.totalActivityDuration

                // Get category breakdown
                for await categoryActivity in segment.categories {
                    let categoryName = categoryActivity.category.localizedDisplayName ?? "Other"
                    categoryBreakdown[categoryName, default: 0] += categoryActivity.totalActivityDuration

                    // Get individual apps
                    for await appActivity in categoryActivity.applications {
                        let appName = appActivity.application.localizedDisplayName ?? "Unknown"
                        let bundleID = appActivity.application.bundleIdentifier
                        appUsage.append((appName, appActivity.totalActivityDuration, bundleID))
                    }
                }
            }
        }

        // Sort apps by duration
        appUsage.sort { $0.duration > $1.duration }

        return ActivityReport(
            totalDuration: totalDuration,
            categoryBreakdown: categoryBreakdown,
            topApps: Array(appUsage.prefix(10))
        )
    }
}

// MARK: - Top Apps Report

struct TopAppsReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .topApps
    let content: (ActivityReport) -> TopAppsView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        var appUsage: [(name: String, duration: TimeInterval, bundleID: String?)] = []
        var totalDuration: TimeInterval = 0

        for await activityData in data {
            for await segment in activityData.activitySegments {
                totalDuration += segment.totalActivityDuration

                for await categoryActivity in segment.categories {
                    for await appActivity in categoryActivity.applications {
                        let appName = appActivity.application.localizedDisplayName ?? "Unknown"
                        let bundleID = appActivity.application.bundleIdentifier
                        appUsage.append((appName, appActivity.totalActivityDuration, bundleID))
                    }
                }
            }
        }

        appUsage.sort { $0.duration > $1.duration }

        return ActivityReport(
            totalDuration: totalDuration,
            categoryBreakdown: [:],
            topApps: Array(appUsage.prefix(15))
        )
    }
}

// MARK: - Activity Report Model

struct ActivityReport {
    let totalDuration: TimeInterval
    let categoryBreakdown: [String: TimeInterval]
    let topApps: [(name: String, duration: TimeInterval, bundleID: String?)]
}
