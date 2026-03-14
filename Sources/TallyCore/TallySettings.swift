import Foundation

public enum InvoicePageSize: String, Hashable, Codable, Sendable, CaseIterable {
    case letter
}

public struct TallySettings: Equatable, Sendable {
    /// Hours per week the goal ring counts toward. 0 hides the ring.
    public var weeklyGoalHours: Double = 30
    /// Minutes without input before asking about the time. 0 turns detection off.
    public var idleThresholdMinutes: Int = 5
    /// 1 is Sunday, 2 is Monday, matching `Calendar.firstWeekday`.
    public var firstWeekday: Int = 2
    /// Sessions shorter than this are treated as misclicks and dropped.
    public var minimumEntrySeconds: Int = 10
    public var defaultCurrency: String = "USD"
    public var billingRounding = BillingRounding()
    public var hotKey: HotKeyCombo? = .standard
    public var business = BusinessProfile()
    public var defaultTaxPercent: Decimal = 0
    public var paymentTermsDays: Int = 30
    public var invoicePageSize: InvoicePageSize = .letter
    public var invoicePrefix: String = "INV-"

    public init() {}
}

/// Every key is optional when decoding so a file from an older version picks up the
/// defaults for settings it has never heard of.
extension TallySettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case weeklyGoalHours, idleThresholdMinutes, firstWeekday, minimumEntrySeconds
        case defaultCurrency, billingRounding, hotKey, business
        case defaultTaxPercent, paymentTermsDays, invoicePageSize, invoicePrefix
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = TallySettings()
        weeklyGoalHours = try values.decodeIfPresent(Double.self, forKey: .weeklyGoalHours)
            ?? fallback.weeklyGoalHours
        idleThresholdMinutes = try values.decodeIfPresent(Int.self, forKey: .idleThresholdMinutes)
            ?? fallback.idleThresholdMinutes
        firstWeekday = try values.decodeIfPresent(Int.self, forKey: .firstWeekday)
            ?? fallback.firstWeekday
        minimumEntrySeconds = try values.decodeIfPresent(Int.self, forKey: .minimumEntrySeconds)
            ?? fallback.minimumEntrySeconds
        defaultCurrency = try values.decodeIfPresent(String.self, forKey: .defaultCurrency)
            ?? fallback.defaultCurrency
        billingRounding = try values.decodeIfPresent(BillingRounding.self, forKey: .billingRounding)
            ?? fallback.billingRounding
        hotKey = values.contains(.hotKey)
            ? try values.decodeIfPresent(HotKeyCombo.self, forKey: .hotKey)
            : fallback.hotKey
        business = try values.decodeIfPresent(BusinessProfile.self, forKey: .business)
            ?? fallback.business
        defaultTaxPercent = try values.decodeIfPresent(Decimal.self, forKey: .defaultTaxPercent)
            ?? fallback.defaultTaxPercent
        paymentTermsDays = try values.decodeIfPresent(Int.self, forKey: .paymentTermsDays)
            ?? fallback.paymentTermsDays
        invoicePageSize = try values.decodeIfPresent(InvoicePageSize.self, forKey: .invoicePageSize)
            ?? fallback.invoicePageSize
        invoicePrefix = try values.decodeIfPresent(String.self, forKey: .invoicePrefix)
            ?? fallback.invoicePrefix
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(weeklyGoalHours, forKey: .weeklyGoalHours)
        try values.encode(idleThresholdMinutes, forKey: .idleThresholdMinutes)
        try values.encode(firstWeekday, forKey: .firstWeekday)
        try values.encode(minimumEntrySeconds, forKey: .minimumEntrySeconds)
        try values.encode(defaultCurrency, forKey: .defaultCurrency)
        try values.encode(billingRounding, forKey: .billingRounding)
        // Encoded even when nil: a missing key means "older file", nil means "turned off".
        try values.encode(hotKey, forKey: .hotKey)
        try values.encode(business, forKey: .business)
        try values.encode(defaultTaxPercent, forKey: .defaultTaxPercent)
        try values.encode(paymentTermsDays, forKey: .paymentTermsDays)
        try values.encode(invoicePageSize, forKey: .invoicePageSize)
        try values.encode(invoicePrefix, forKey: .invoicePrefix)
    }
}
