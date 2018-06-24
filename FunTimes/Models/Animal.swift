//
//  Animal.swift
//  FunTimes
//
//  Created by Tanner W. Stokes on 6/23/18.
//  Copyright © 2018 Tanner W. Stokes. All rights reserved.
//

import Foundation
import UIKit

enum AnimalType {
    case human, miniSchnauzer

    var description: String {
        switch self {
        case .human:
            return "Human"
        case .miniSchnauzer:
            return "Miniature Schnauzer"
        }
    }
}

struct Animal {
    let name: String
    let type: AnimalType
    let dob: String
    let description: String
    let uiBgColor: UIColor
}
