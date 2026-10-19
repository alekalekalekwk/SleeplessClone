import Foundation
import SwiftUI

final class PopoverState: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var hotkeyError: String? = nil
}
