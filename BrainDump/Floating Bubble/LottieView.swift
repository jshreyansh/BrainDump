import SwiftUI
import Lottie

/// SwiftUI wrapper for Lottie animation
struct LottieView: NSViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .loop
    var speed: CGFloat = 1.0
    var isPlaying: Bool = false
    var frame: AnimationFrameTime = 0
    
    func makeNSView(context: Context) -> LottieAnimationView {
        guard let path = Bundle.main.path(forResource: animationName, ofType: "json") else {
            print("Lottie: Could not find \(animationName).json in bundle")
            return LottieAnimationView()
        }
        
        let animationView = LottieAnimationView(filePath: path)
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed
        animationView.contentMode = .scaleAspectFit
        
        // Start with idle state - show first frame only (don't play)
        animationView.currentFrame = 0
        animationView.stop() // Stop at first frame - don't play continuously
        
        return animationView
    }
    
    func updateNSView(_ nsView: LottieAnimationView, context: Context) {
        // Update frame if needed
        if frame != nsView.currentFrame {
            nsView.currentFrame = frame
        }
        
        // Update loop mode and speed if changed
        if nsView.loopMode != loopMode {
            nsView.loopMode = loopMode
        }
        if nsView.animationSpeed != speed {
            nsView.animationSpeed = speed
        }
        
        // Only play animation when explicitly triggered (isPlaying is true)
        // Don't auto-play when view is just being shown/updated
        if isPlaying {
            // Only play if not already playing the same animation
            if !nsView.isAnimationPlaying || nsView.loopMode != .playOnce {
                // Play animation from start when triggered
                nsView.currentFrame = 0
                nsView.loopMode = .playOnce
                nsView.play { finished in
                    // After animation completes, return to idle state (first frame)
                    if finished {
                        nsView.currentFrame = 0
                        nsView.stop() // Stop at first frame - back to idle
                    }
                }
            }
        } else {
            // When not playing, ensure it's in idle state (first frame, stopped)
            if nsView.isAnimationPlaying {
                nsView.stop()
            }
            // Ensure it's showing the first frame
            if nsView.currentFrame != 0 {
                nsView.currentFrame = 0
            }
            // Make sure loop mode is set correctly for idle state
            if nsView.loopMode != .loop {
                nsView.loopMode = .loop
            }
        }
    }
}

