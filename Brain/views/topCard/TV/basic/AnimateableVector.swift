//
//  AnimateableVector.swift
//  Brain
//
//  Created by Owen O'Malley on 4/30/24.
//

import SwiftUI
import enum Accelerate.vDSP

public struct AnimatableVector: VectorArithmetic {
    public static var zero = AnimatableVector(values: (0...31).map{ Double($0) })

    public static func + (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        let count = min(lhs.values.count, rhs.values.count)
        return AnimatableVector(values: vDSP.add(lhs.values[0..<count], rhs.values[0..<count]))
    }

    public static func += (lhs: inout AnimatableVector, rhs: AnimatableVector) {
        let count = min(lhs.values.count, rhs.values.count)
        vDSP.add(lhs.values[0..<count], rhs.values[0..<count], result: &lhs.values[0..<count])
    }

    public static func - (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        let count = min(lhs.values.count, rhs.values.count)
        return AnimatableVector(values: vDSP.subtract(lhs.values[0..<count], rhs.values[0..<count]))
    }

    public static func -= (lhs: inout AnimatableVector, rhs: AnimatableVector) {
        let count = min(lhs.values.count, rhs.values.count)
        vDSP.subtract(lhs.values[0..<count], rhs.values[0..<count], result: &lhs.values[0..<count])
    }

    var values: [Double]

    mutating public func scale(by rhs: Double) {
        self.values = vDSP.multiply(rhs, values)
    }

    public var magnitudeSquared: Double {
        vDSP.sum(vDSP.multiply(self.values, self.values))
    }
}
