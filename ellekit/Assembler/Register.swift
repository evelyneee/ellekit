
// This file is licensed under the BSD-3 Clause License
// Copyright 2022 © ElleKit Team

import Foundation

public enum Register {
    case w(Int)
    case x(Int)
    case sp
    case xzr
    case wzr

    var value: Int {
        switch self {
        case .x(let num), .w(let num): return num
        case .sp, .xzr, .wzr: return 31
        }
    }

    var w: Bool {
        switch self {
        case .w, .wzr: return true
        default: return false
        }
    }
    
    static public let x0 = Self.x(0)
    static public let x1 = Self.x(1)
    static public let x2 = Self.x(2)
    static public let x3 = Self.x(3)
    static public let x4 = Self.x(4)
    static public let x5 = Self.x(5)
    static public let x6 = Self.x(6)
    static public let x7 = Self.x(7)
    static public let x8 = Self.x(8)
    static public let x9 = Self.x(9)
    static public let x10 = Self.x(10)
    static public let x11 = Self.x(11)
    static public let x12 = Self.x(12)
    static public let x13 = Self.x(13)
    static public let x14 = Self.x(14)
    static public let x15 = Self.x(15)
    static public let x16 = Self.x(16)
    static public let x17 = Self.x(17)
    static public let x18 = Self.x(18)
    static public let x19 = Self.x(19)
    static public let x20 = Self.x(20)
    static public let x21 = Self.x(21)
    static public let x22 = Self.x(22)
    static public let x23 = Self.x(23)
    static public let x24 = Self.x(24)
    static public let x25 = Self.x(25)
    static public let x26 = Self.x(26)
    static public let x27 = Self.x(27)
    static public let x28 = Self.x(28)
    static public let x29 = Self.x(29)
    static public let x30 = Self.x(30)

    static public let w0 = Self.w(0)
    static public let w1 = Self.w(1)
    static public let w2 = Self.w(2)
    static public let w3 = Self.w(3)
    static public let w4 = Self.w(4)
    static public let w5 = Self.w(5)
    static public let w6 = Self.w(6)
    static public let w7 = Self.w(7)
    static public let w8 = Self.w(8)
    static public let w9 = Self.w(9)
    static public let w10 = Self.w(10)
    static public let w11 = Self.w(11)
    static public let w12 = Self.w(12)
    static public let w13 = Self.w(13)
    static public let w14 = Self.w(14)
    static public let w15 = Self.w(15)
    static public let w16 = Self.w(16)
    static public let w17 = Self.w(17)
    static public let w18 = Self.w(18)
    static public let w19 = Self.w(19)
    static public let w20 = Self.w(20)
    static public let w21 = Self.w(21)
    static public let w22 = Self.w(22)
    static public let w23 = Self.w(23)
    static public let w24 = Self.w(24)
    static public let w25 = Self.w(25)
    static public let w26 = Self.w(26)
    static public let w27 = Self.w(27)
    static public let w28 = Self.w(28)
    static public let w29 = Self.w(29)
    static public let w30 = Self.w(30)
}

public struct Cond {

    init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    var rawValue: Int

    static public let EQ = Self(0b0000)
    static public let NE = Self(0b0001)
    static public let CS = Self(0b0010)
    static public let HS = Self(0b0010)
    static public let CC = Self(0b0011)
    static public let LO = Self(0b0011)
    static public let MI = Self(0b0100)
    static public let PL = Self(0b0101)
    static public let VS = Self(0b0110)
    static public let VC = Self(0b0111)
    static public let HI = Self(0b1000)
    static public let LS = Self(0b1001)
    static public let GE = Self(0b1010)
    static public let LT = Self(0b1011)
    static public let GT = Self(0b1100)
    static public let LE = Self(0b1101)
    static public let AL = Self(0b1110)
    static public let NVb = Self(0b1111)
}
