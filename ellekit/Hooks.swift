//
//  Hooks.swift
//  ellekit
//
//  Created by charlotte on 2022-11-03.
//

import Foundation

// target:replacement
public var hooks: [UnsafeMutableRawPointer: UnsafeMutableRawPointer] = [:]

public var slide: Int = _dyld_get_image_vmaddr_slide(0)

var didRegisterEXCPort = false
