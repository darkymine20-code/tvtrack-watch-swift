import SwiftUI

public struct CollapsibleCommentTextView: View {
    public let text: String
    public var lineLimit: Int = 3
    public var characterThreshold: Int = 180
    
    @State private var isExpanded = false
    
    public init(text: String, lineLimit: Int = 3, characterThreshold: Int = 180) {
        self.text = text
        self.lineLimit = lineLimit
        self.characterThreshold = characterThreshold
    }
    
    private var isLong: Bool {
        text.count > characterThreshold
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : lineLimit)
            
            if isLong {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Read More...")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}
