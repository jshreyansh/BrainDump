import SwiftUI

/// A toast notification that shows "Saved ✓"
struct ToastView: View {
    
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 14, weight: .semibold))
            
            Text("Saved")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .opacity(isShowing ? 1 : 0)
        .scaleEffect(isShowing ? 1 : 0.8)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShowing)
    }
}

/// Observable object to manage toast state across the app
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var isShowing = false
    
    private init() {}
    
    func show() {
        isShowing = true
        
        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.isShowing = false
        }
    }
}

/// Container view that displays bubble with toast - centered layout for expanded state
struct BubbleWithToast: View {
    
    @ObservedObject var toastManager = ToastManager.shared
    
    var body: some View {
        ZStack {
            // The FloatingBubbleView now handles its own layout with expanded actions
            FloatingBubbleView(
                onDrop: { _ in },
                onShowToast: { ToastManager.shared.show() }
            )
            
            // Toast positioned above the center
            VStack {
                ToastView(isShowing: $toastManager.isShowing)
                    .offset(y: 20)
                Spacer()
            }
        }
        // Use expanded size for content, but panel will resize dynamically
        .frame(width: 280, height: 330)
    }
}

// MARK: - Preview

struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ToastView(isShowing: .constant(true))
            ToastView(isShowing: .constant(false))
        }
        .padding(50)
        .background(Color.gray.opacity(0.3))
    }
}
