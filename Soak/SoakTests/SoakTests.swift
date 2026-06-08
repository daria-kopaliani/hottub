import Testing
@testable import Soak

@Suite("Pool/spa chemistry dose formulas")
struct FormulasTests {

    @Test func chlorineLiquidScalesToHotTubVolume() {
        let dose = Formulas.chlorineDose(currentFC: 1,
                                         targetFC: 3,
                                         gallons: 400,
                                         product: .liquid125)
        #expect(abs(dose.amount - 23.66) < 0.05)
        #expect(dose.unit == .milliliters)
    }

    @Test func calHypoScalesToHotTubVolume() {
        let dose = Formulas.chlorineDose(currentFC: 0,
                                         targetFC: 1,
                                         gallons: 400,
                                         product: .calHypo68)
        #expect(abs(dose.amount - 2.27) < 0.02)
        #expect(dose.unit == .grams)
    }

    @Test func dichlorScalesToHotTubVolume() {
        let dose = Formulas.chlorineDose(currentFC: 0,
                                         targetFC: 1,
                                         gallons: 400,
                                         product: .dichlor56)
        #expect(abs(dose.amount - 2.72) < 0.02)
    }

    @Test func zeroDeltaReturnsNone() {
        let dose = Formulas.chlorineDose(currentFC: 3,
                                         targetFC: 3,
                                         gallons: 400,
                                         product: .liquid125)
        #expect(dose == .none)
    }

    @Test func negativeDeltaReturnsNone() {
        let dose = Formulas.chlorineDose(currentFC: 5,
                                         targetFC: 3,
                                         gallons: 400,
                                         product: .liquid125)
        #expect(dose == .none)
    }

    @Test func zeroGallonsReturnsNone() {
        let dose = Formulas.chlorineDose(currentFC: 0,
                                         targetFC: 3,
                                         gallons: 0,
                                         product: .liquid125)
        #expect(dose == .none)
    }

    @Test func alkalinityRaiseScalesCorrectly() {
        let dose = Formulas.alkalinityRaiseDose(currentTA: 60,
                                                targetTA: 80,
                                                gallons: 400)
        #expect(abs(dose.amount - 54.43) < 0.1)
        #expect(dose.unit == .grams)
    }

    @Test func alkalinityLowerScalesCorrectly() {
        let dose = Formulas.alkalinityLowerDose(currentTA: 140,
                                                targetTA: 110,
                                                gallons: 400)
        #expect(abs(dose.amount - 113.56) < 0.2)
        #expect(dose.unit == .milliliters)
    }

    @Test func pHRaise() {
        let dose = Formulas.pHRaiseDose(currentPH: 7.2,
                                       targetPH: 7.5,
                                       gallons: 400)
        #expect(abs(dose.amount - 10.21) < 0.1)
    }

    @Test func pHLowerDryAcid() {
        let dose = Formulas.pHLowerDose(currentPH: 8.0,
                                       targetPH: 7.5,
                                       gallons: 400,
                                       product: .dryAcid)
        #expect(abs(dose.amount - 2.83) < 0.05)
    }

    @Test func pHLowerMuriatic() {
        let dose = Formulas.pHLowerDose(currentPH: 8.0,
                                       targetPH: 7.5,
                                       gallons: 400,
                                       product: .muriatic)
        #expect(abs(dose.amount - 37.85) < 0.2)
        #expect(dose.unit == .milliliters)
    }

    @Test func bromineDose() {
        let dose = Formulas.bromineDose(currentBr: 0, targetBr: 3, gallons: 400)
        #expect(abs(dose.amount - 44.22) < 0.1)
    }

    @Test func shockDoseChlorine() {
        let dose = Formulas.shockDose(sanitizer: .chlorine, gallons: 400)
        #expect(abs(dose.amount - 22.68) < 0.1)
    }

    @Test func shockDoseBromine() {
        let dose = Formulas.shockDose(sanitizer: .bromine, gallons: 400)
        #expect(abs(dose.amount - 113.4) < 0.1)
    }

    @Test func afterUseScalesWithBatherLoad() {
        let twoPeople = Formulas.afterUseDose(people: 2, hours: 1,
                                              sanitizer: .bromine, gallons: 400)
        let fourPeople = Formulas.afterUseDose(people: 4, hours: 1,
                                               sanitizer: .bromine, gallons: 400)
        #expect(fourPeople.amount > twoPeople.amount)
    }

    @Test(arguments: [
        (2.0, Formulas.TargetRange.chlorineFC),
        (3.0, Formulas.TargetRange.bromine),
        (7.5, Formulas.TargetRange.pH),
        (100.0, Formulas.TargetRange.totalAlkalinity),
        (200.0, Formulas.TargetRange.calciumHardness)
    ])
    func targetRangesContainMidpoints(value: Double, range: ClosedRange<Double>) {
        #expect(range.contains(value))
    }

    @Test func doseFormattingMetricLarge() {
        let dose = Dose(amount: 27.4, unit: .grams)
        #expect(dose.formatted(metric: true) == "27 g")
    }

    @Test func doseFormattingMetricSmall() {
        let dose = Dose(amount: 2.3, unit: .grams)
        #expect(dose.formatted(metric: true) == "2.3 g")
    }

    @Test func doseFormattingImperial() {
        let dose = Dose(amount: 28.35, unit: .grams)
        #expect(dose.formatted(metric: false) == "1.00 oz")
    }

    @Test func negligibleDoseFormatsAsDash() {
        let dose = Dose(amount: 0.3, unit: .grams)
        #expect(dose.formatted(metric: true) == "—")
    }
}

// MARK: - Numeric input parser

@Suite("Numeric input parser")
struct NumericInputParseTests {
    @Test func parsesDotDecimal() {
        #expect(NumericInput.parse("7.9") == 7.9)
    }

    @Test func parsesCommaDecimal() {
        // Comma-decimal locales (en_UA, fr_FR, etc.) used to silently return
        // nil under NumberFormatter+.current. Both separators must parse.
        #expect(NumericInput.parse("7,9") == 7.9)
    }

    @Test func parsesIntegerString() {
        #expect(NumericInput.parse("50") == 50.0)
    }

    @Test func emptyReturnsNil() {
        #expect(NumericInput.parse("") == nil)
    }

    @Test func filterAcceptsBothSeparators() {
        #expect(NumericInput.filter("7.9") == "7.9")
        #expect(NumericInput.filter("7,9") == "7,9")
    }
}
