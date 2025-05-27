import SwiftUI

struct BadgeNotificationView: View {
    let badge: Badge
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Badge Icon
            Image(systemName: badge.iconName)
                .font(.system(size: 64))
                .foregroundColor(.purple)
                .frame(width: 100, height: 100)
                .background(Circle().fill(Color.purple.opacity(0.2)))
                .padding(.top)
            
            // Badge Title
            Text("Achievement Unlocked!")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Badge Name
            Text(badge.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Badge Description
            Text(badge.descriptionText)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Dismiss Button
            Button(action: {
                withAnimation(.easeInOut) {
                    isPresented = false
                }
            }) {
                Text("Continue")
                    .font(.headline)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
            .padding(.bottom)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement unlocked! \(badge.title)")
        .accessibilityHint(badge.descriptionText)
        .accessibilityAddTraits(.isModal)
    }
}

struct PointsNotificationView: View {
    let points: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.title)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading) {
                Text("+\(points) Points")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if points > 10 {
                    Text("Bonus for quiet place!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(10)
            }
            .accessibilityLabel("Dismiss notification")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You earned \(points) points")
    }
}

#Preview {
    VStack {
        BadgeNotificationView(
            badge: Badge(
                title: "First Report", 
                description: "You submitted your first noise report", 
                iconName: "1.circle.fill"
            ),
            isPresented: .constant(true)
        )
        .padding()
        
        PointsNotificationView(
            points: 15,
            isPresented: .constant(true)
        )
    }
}