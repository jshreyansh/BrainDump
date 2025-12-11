import SwiftUI

/// A single row displaying a captured item
struct EntryRowView: View {
    
    let item: CapturedItem
    let isSelected: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            VStack(alignment: .trailing) {
                Text(item.displayTime)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(width: 50)
            
            // Content preview
            VStack(alignment: .leading, spacing: 4) {
                // Type indicator and preview
                HStack(spacing: 6) {
                    Image(systemName: item.type == .image ? "photo" : "doc.text")
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    Text(item.type == .image ? "Image" : "Text")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                // Content preview
                if item.type == .text {
                    Text(item.contentPreview)
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else if item.type == .image {
                    // Small image thumbnail
                    if let image = item.loadImage() {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isHovering && !isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovering {
            return Color.gray.opacity(0.1)
        }
        return Color.clear
    }
}

// MARK: - Preview

struct EntryRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EntryRowView(
                item: CapturedItem(
                    id: UUID(),
                    timestamp: Date(),
                    type: .text,
                    filePath: URL(fileURLWithPath: "/tmp/test.md")
                ),
                isSelected: false
            )
            
            EntryRowView(
                item: CapturedItem(
                    id: UUID(),
                    timestamp: Date(),
                    type: .text,
                    filePath: URL(fileURLWithPath: "/tmp/test.md")
                ),
                isSelected: true
            )
        }
        .padding()
        .frame(width: 400)
    }
}



