//
//  Register.swift
//  Assembler
//
//  Created by evelyn on 2022-10-16.
//

import Foundation

enum Register {
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
        case .w(_), .wzr: return true
        default: return false
        }
    }
    
    static let x0 = Self.x(0)
    static let x1 = Self.x(1)
    static let x2 = Self.x(2)
    static let x3 = Self.x(3)
    static let x4 = Self.x(4)
    static let x5 = Self.x(5)
    static let x6 = Self.x(6)
    static let x7 = Self.x(7)
    static let x8 = Self.x(8)
    static let x9 = Self.x(9)
    static let x10 = Self.x(10)
    static let x11 = Self.x(11)
    static let x12 = Self.x(12)
    static let x13 = Self.x(13)
    static let x14 = Self.x(14)
    static let x15 = Self.x(15)
    static let x16 = Self.x(16)
    static let x17 = Self.x(17)
    static let x18 = Self.x(18)
    static let x19 = Self.x(19)
    static let x20 = Self.x(20)
    static let x21 = Self.x(21)
    static let x22 = Self.x(22)
    static let x23 = Self.x(23)
    static let x24 = Self.x(24)
    static let x25 = Self.x(25)
    static let x26 = Self.x(26)
    static let x27 = Self.x(27)
    static let x28 = Self.x(28)
    static let x29 = Self.x(29)
    static let x30 = Self.x(30)
    
    static let w0 = Self.w(0)
    static let w1 = Self.w(1)
    static let w2 = Self.w(2)
    static let w3 = Self.w(3)
    static let w4 = Self.w(4)
    static let w5 = Self.w(5)
    static let w6 = Self.w(6)
    static let w7 = Self.w(7)
    static let w8 = Self.w(8)
    static let w9 = Self.w(9)
    static let w10 = Self.w(10)
    static let w11 = Self.w(11)
    static let w12 = Self.w(12)
    static let w13 = Self.w(13)
    static let w14 = Self.w(14)
    static let w15 = Self.w(15)
    static let w16 = Self.w(16)
    static let w17 = Self.w(17)
    static let w18 = Self.w(18)
    static let w19 = Self.w(19)
    static let w20 = Self.w(20)
    static let w21 = Self.w(21)
    static let w22 = Self.w(22)
    static let w23 = Self.w(23)
    static let w24 = Self.w(24)
    static let w25 = Self.w(25)
    static let w26 = Self.w(26)
    static let w27 = Self.w(27)
    static let w28 = Self.w(28)
    static let w29 = Self.w(29)
    static let w30 = Self.w(30)
}

struct Cond {
    
    init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
    
    var rawValue: Int
    
    static let EQ = Self(0b0000)
    static let NE = Self(0b0001)
    static let CS = Self(0b0010)
    static let HS = Self(0b0010)
    static let CC = Self(0b0011)
    static let LO = Self(0b0011)
    static let MI = Self(0b0100)
    static let PL = Self(0b0101)
    static let VS = Self(0b0110)
    static let VC = Self(0b0111)
    static let HI = Self(0b1000)
    static let LS = Self(0b1001)
    static let GE = Self(0b1010)
    static let LT = Self(0b1011)
    static let GT = Self(0b1100)
    static let LE = Self(0b1101)
    static let AL = Self(0b1110)
    static let NVb = Self(0b1111)
}
