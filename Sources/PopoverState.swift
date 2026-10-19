import Foundation
import SwiftUI

@MainActor
final class PopoverState: ObservableObject {
    static let shared = PopoverState()
    @Published var isRecording: Bool = false
    @Published var hotkeyError: String? = nil
}
