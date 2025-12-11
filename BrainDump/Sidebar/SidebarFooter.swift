import SwiftUI

struct SidebarFooter: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("BrainDump")
                .fontWeight(.medium)
                .foregroundColor(.primary.opacity(0.8))
            
            Text("Capture anything")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding()
    }
}

struct SidebarFooter_Previews: PreviewProvider {
    static var previews: some View {
        SidebarFooter()
    }
}
