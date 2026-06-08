import Foundation

/// Localisable metadata for each HRV metric. All text is referenced by key so the
/// metric glossary works in every language. `bestMode` hints which scan depth
/// gives the metric meaningful reliability.
struct HRVMetricDefinition: Identifiable, Sendable, Equatable {
    var key: String          // stable identifier, e.g. "rmssd"
    var titleKey: String
    var shortDescriptionKey: String
    var whatItMeansKey: String
    var whenLowKey: String
    var whenHighKey: String
    var reliabilityKey: String
    var bestMode: HRVScanMode

    var id: String { key }

    /// Convenience builder using the conventional key layout
    /// `hrv.metrics.<key>.<field>`.
    static func make(_ key: String, bestMode: HRVScanMode) -> HRVMetricDefinition {
        HRVMetricDefinition(
            key: key,
            titleKey: "hrv.metrics.\(key).title",
            shortDescriptionKey: "hrv.metrics.\(key).short",
            whatItMeansKey: "hrv.metrics.\(key).meaning",
            whenLowKey: "hrv.metrics.\(key).low",
            whenHighKey: "hrv.metrics.\(key).high",
            reliabilityKey: "hrv.metrics.\(key).reliability",
            bestMode: bestMode)
    }
}

enum HRVMetricDefinitions {
    /// All supported metrics, ordered roughly from most to least everyday-useful.
    static let all: [HRVMetricDefinition] = [
        .make("hr", bestMode: .quick),
        .make("meannn", bestMode: .quick),
        .make("rmssd", bestMode: .quick),
        .make("lnrmssd", bestMode: .quick),
        .make("sdnn", bestMode: .standard),
        .make("nn50", bestMode: .quick),
        .make("pnn50", bestMode: .quick),
        .make("sdsd", bestMode: .quick),
        .make("cvnn", bestMode: .standard),
        .make("cvsd", bestMode: .quick),
        .make("amo50", bestMode: .standard),
        .make("modenn", bestMode: .standard),
        .make("mxdmn", bestMode: .standard),
        .make("triangularindex", bestMode: .standard),
        .make("tinn", bestMode: .standard),
        .make("hfpower", bestMode: .deep),
        .make("lfpower", bestMode: .deep),
        .make("vlfpower", bestMode: .deep),
        .make("totalpower", bestMode: .deep),
        .make("lfhf", bestMode: .deep),
        .make("sd1", bestMode: .quick),
        .make("sd2", bestMode: .standard),
        .make("sd1sd2", bestMode: .standard),
        .make("sampleentropy", bestMode: .deep),
        .make("approximateentropy", bestMode: .deep),
        .make("dfaalpha1", bestMode: .deep),
        .make("dfaalpha2", bestMode: .deep)
    ]

    static func definition(for key: String) -> HRVMetricDefinition? {
        all.first { $0.key == key }
    }
}
