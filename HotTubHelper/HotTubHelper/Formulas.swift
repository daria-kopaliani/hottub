import Foundation

// Reference doses are stated in industry literature as "X amount per 10,000 gal raises Y by Z."
// We scale linearly to the user's volume in gallons.
// Sources: TroubleFreePool reference tables, industry pool chemistry guides.

enum Formulas {

    enum Constants {
        // Chlorine: amount per 10,000 gal to raise FC by 1 ppm
        static let liquidChlorine125_flOzPer10kPerPPM: Double = 10.0
        static let calHypo68_ozPer10kPerPPM: Double = 2.0
        static let dichlor56_ozPer10kPerPPM: Double = 2.4

        // pH: amount per 10,000 gal to change pH by 0.1
        static let dryAcid_ozPer10kPerPointOne: Double = 0.5
        static let muriatic3145_flOzPer10kPerPointOne: Double = 6.4
        static let sodaAsh_ozPer10kPerPointOne: Double = 3.0

        // Total Alkalinity: amount per 10,000 gal to change TA by 10 ppm
        static let bakingSoda_lbPer10kPer10ppm: Double = 1.5
        static let muriatic3145_qtPer10kPer10ppm: Double = 1.0

        // Calcium Hardness: amount per 10,000 gal to raise CH by 10 ppm
        static let calciumChloride_lbPer10kPer10ppm: Double = 1.0

        static let gPerOz: Double = 28.3495
        static let gPerLb: Double = 453.592
        static let mlPerFlOz: Double = 29.5735
        static let mlPerQt: Double = 946.353

        static let referenceGallons: Double = 10_000
    }

    enum TargetRange {
        static let chlorineFC: ClosedRange<Double> = 1.0...3.0
        static let bromine: ClosedRange<Double> = 2.0...4.0
        static let pH: ClosedRange<Double> = 7.2...7.8
        static let pHIdeal: ClosedRange<Double> = 7.4...7.6
        static let totalAlkalinity: ClosedRange<Double> = 80.0...120.0
        static let calciumHardness: ClosedRange<Double> = 150.0...250.0
        static let cyanuricAcid: ClosedRange<Double> = 30.0...50.0
    }

    // MARK: - Sanitizer

    static func chlorineDose(
        currentFC: Double,
        targetFC: Double,
        gallons: Double,
        product: ChlorineProduct
    ) -> Dose {
        let delta = targetFC - currentFC
        guard delta > 0, gallons > 0 else { return .none }
        let scale = gallons / Constants.referenceGallons * delta

        switch product {
        case .liquid125:
            let flOz = Constants.liquidChlorine125_flOzPer10kPerPPM * scale
            return Dose(amount: flOz * Constants.mlPerFlOz, unit: .milliliters)
        case .calHypo68:
            let oz = Constants.calHypo68_ozPer10kPerPPM * scale
            return Dose(amount: oz * Constants.gPerOz, unit: .grams)
        case .dichlor56:
            let oz = Constants.dichlor56_ozPer10kPerPPM * scale
            return Dose(amount: oz * Constants.gPerOz, unit: .grams)
        }
    }

    // 0.13 oz of sodium bromide per 100 gal raises bromine by ~1 ppm (industry rule of thumb).
    static func bromineDose(currentBr: Double, targetBr: Double, gallons: Double) -> Dose {
        let delta = targetBr - currentBr
        guard delta > 0, gallons > 0 else { return .none }
        let ozPerGalPerPPM = 0.13 / 100.0
        let oz = ozPerGalPerPPM * gallons * delta
        return Dose(amount: oz * Constants.gPerOz, unit: .grams)
    }

    // MARK: - pH

    static func pHRaiseDose(currentPH: Double, targetPH: Double, gallons: Double) -> Dose {
        let delta = targetPH - currentPH
        guard delta > 0, gallons > 0 else { return .none }
        let scale = gallons / Constants.referenceGallons * (delta / 0.1)
        let oz = Constants.sodaAsh_ozPer10kPerPointOne * scale
        return Dose(amount: oz * Constants.gPerOz, unit: .grams)
    }

    static func pHLowerDose(
        currentPH: Double,
        targetPH: Double,
        gallons: Double,
        product: PHLowerer
    ) -> Dose {
        let delta = currentPH - targetPH
        guard delta > 0, gallons > 0 else { return .none }
        let scale = gallons / Constants.referenceGallons * (delta / 0.1)

        switch product {
        case .dryAcid:
            let oz = Constants.dryAcid_ozPer10kPerPointOne * scale
            return Dose(amount: oz * Constants.gPerOz, unit: .grams)
        case .muriatic:
            let flOz = Constants.muriatic3145_flOzPer10kPerPointOne * scale
            return Dose(amount: flOz * Constants.mlPerFlOz, unit: .milliliters)
        }
    }

    // MARK: - Total Alkalinity

    static func alkalinityRaiseDose(currentTA: Double, targetTA: Double, gallons: Double) -> Dose {
        let delta = targetTA - currentTA
        guard delta > 0, gallons > 0 else { return .none }
        let scale = gallons / Constants.referenceGallons * (delta / 10.0)
        let lb = Constants.bakingSoda_lbPer10kPer10ppm * scale
        return Dose(amount: lb * Constants.gPerLb, unit: .grams)
    }

    static func alkalinityLowerDose(currentTA: Double, targetTA: Double, gallons: Double) -> Dose {
        let delta = currentTA - targetTA
        guard delta > 0, gallons > 0 else { return .none }
        let scale = gallons / Constants.referenceGallons * (delta / 10.0)
        let qt = Constants.muriatic3145_qtPer10kPer10ppm * scale
        return Dose(amount: qt * Constants.mlPerQt, unit: .milliliters)
    }

    // MARK: - Calcium Hardness

    static func calciumRaiseDose(currentCH: Double, targetCH: Double, gallons: Double) -> Dose {
        let delta = targetCH - currentCH
        guard delta > 0, gallons > 0 else { return .none }
        let scale = gallons / Constants.referenceGallons * (delta / 10.0)
        let lb = Constants.calciumChloride_lbPer10kPer10ppm * scale
        return Dose(amount: lb * Constants.gPerLb, unit: .grams)
    }

    // MARK: - After-use & shock

    // Each person-hour adds roughly 1 ppm of sanitizer demand (industry rule of thumb).
    static func afterUseDose(
        people: Int,
        hours: Double,
        sanitizer: Sanitizer,
        gallons: Double,
        chlorineProduct: ChlorineProduct = .dichlor56
    ) -> Dose {
        guard people > 0, hours > 0, gallons > 0 else { return .none }
        let demandPPM = Double(people) * hours
        let target = sanitizer == .chlorine ? 3.0 : 4.0
        switch sanitizer {
        case .chlorine:
            return chlorineDose(currentFC: 0, targetFC: min(demandPPM, target + 2.0),
                                gallons: gallons, product: chlorineProduct)
        case .bromine:
            return bromineDose(currentBr: 0, targetBr: min(demandPPM, target + 2.0),
                               gallons: gallons)
        }
    }

    // Chlorine shock target: 10 ppm equivalent. Bromine: 1 oz MPS per 100 gal.
    static func shockDose(sanitizer: Sanitizer, gallons: Double) -> Dose {
        guard gallons > 0 else { return .none }
        switch sanitizer {
        case .chlorine:
            return chlorineDose(currentFC: 0, targetFC: 10.0,
                                gallons: gallons, product: .calHypo68)
        case .bromine:
            let ozPerGal = 1.0 / 100.0
            let oz = ozPerGal * gallons
            return Dose(amount: oz * Constants.gPerOz, unit: .grams)
        }
    }
}
