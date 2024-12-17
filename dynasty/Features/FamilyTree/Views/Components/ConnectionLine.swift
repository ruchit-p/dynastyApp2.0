import SwiftUI

struct ConnectionLine: Shape {
    let start: CGPoint
    let end: CGPoint
    let type: ConnectionType
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        
        switch type {
        case .parent:
            // Curved line for parent-child relationships
            let control1 = CGPoint(x: start.x, y: start.y + (end.y - start.y) * 0.5)
            let control2 = CGPoint(x: end.x, y: start.y + (end.y - start.y) * 0.5)
            path.addCurve(to: end, control1: control1, control2: control2)
        case .spouse:
            // Straight line for spouse relationships
            path.addLine(to: end)
        }
        
        return path
    }
    
    enum ConnectionType {
        case parent
        case spouse
    }
}