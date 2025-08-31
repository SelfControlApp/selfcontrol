//
//  Status.swift
//  SelfControl
//
//  Created by Egzon Arifi on 02/04/2025.
//

import Foundation
import SwiftUI

enum Status {
  case stopped
  case indeterminate
  case running
}

extension Status {
  var text: String {
    switch self {
    case .stopped:
      return "Stopped"
    case .indeterminate:
      return "Indeterminate"
    case .running:
      return "Running"
    }
  }
  
  var color: Color {
    switch self {
    case .stopped:
      return .red
    case .indeterminate:
      return .yellow
    case .running:
      return .green
    }
  }
}
