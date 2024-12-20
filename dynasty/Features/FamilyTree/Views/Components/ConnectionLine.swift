import SwiftUI

enum ConnectionType {
    case parent
    case spouse
    case child
}

struct ConnectionLine: Shape {
    let start: CGPoint
    let end: CGPoint
    let type: ConnectionType
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch type {
        case .parent, .child:
            // Draw a curved line for parent-child relationships
            path.move(to: start)
            let control1 = CGPoint(x: start.x, y: (start.y + end.y) / 2)
            let control2 = CGPoint(x: end.x, y: (start.y + end.y) / 2)
            path.addCurve(to: end, control1: control1, control2: control2)
        case .spouse:
            // Draw a straight horizontal line for spouse relationships
            path.move(to: start)
            path.addLine(to: end)
        }
        
        return path
    }
}