//
//  SplashScreenFinishView.swift
//  AwattarApp
//
//  Created by Léon Becker on 17.10.20.
//

import SwiftUI

struct CheckmarkView: View {
    struct CheckmarkFirstLine: Shape {
        var startPoint: CGPoint
        var endPoint: CGPoint
        let lineWidth: CGFloat
        
        var animatableData: AnimatablePair<CGFloat, CGFloat> {
            get {
                AnimatablePair(endPoint.x, endPoint.y)
            }

            set {
                self.endPoint.x = newValue.first
                self.endPoint.y = newValue.second
            }
        }
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: startPoint.x, y: startPoint.y))
            path.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y))
            
            path = path.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            return path
        }
    }
    
    struct CheckmarkEndLine: Shape {
        var startPoint: CGPoint
        var endPoint: CGPoint
        let lineWidth: CGFloat
        
        var animatableData: AnimatablePair<CGFloat, CGFloat> {
            get {
                AnimatablePair(endPoint.x, endPoint.y)
            }

            set {
                self.endPoint.x = newValue.first
                self.endPoint.y = newValue.second
            }
        }
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            
            if endPoint.x != startPoint.x && endPoint.y != startPoint.y {
                path.move(to: CGPoint(x: startPoint.x, y: startPoint.y))
                path.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y))
                
                path = path.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            
            return path
        }
    }
    
    @State var trimAmount: CGFloat = 0.01
    @State var firstLineStartPoint = CGPoint(x: 0, y: 0)
    @State var firstLineEndPoint = CGPoint(x: 0, y: 0)
    @State var secondLineStartPoint = CGPoint(x: 0, y: 0)
    @State var secondLineEndPoint = CGPoint(x: 0, y: 0)
    
    func makeView(_ geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height
        
        let checkmarkWidth = width / 3
        let checkmarkStartWidth = (width - checkmarkWidth) / 2
        let checkmarkStartHeight: CGFloat = (height / 3) - (checkmarkWidth / 2)
        
        let lineWidth: CGFloat = checkmarkWidth / 17

        return ZStack {
            ZStack {
                CheckmarkFirstLine(startPoint: firstLineStartPoint, endPoint: firstLineEndPoint, lineWidth: lineWidth)
                
                CheckmarkEndLine(startPoint: secondLineStartPoint, endPoint: secondLineEndPoint, lineWidth: lineWidth)
                
                Circle()
                    .trim(from: 0.0, to: trimAmount)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: checkmarkWidth, height: checkmarkWidth)
                    .position(x: width / 2, y: checkmarkStartHeight + (checkmarkWidth / 2))
            }
            .foregroundColor(Color.green)
            
            VStack(spacing: 30) {
               Text("Setup finished")
                   .font(.system(size: 30, weight: .black))
                   .padding(.bottom, 5)

               Text("You still can change your\n settings later.")
                   .multilineTextAlignment(.center)
           }
           .position(x: width / 2, y: checkmarkStartHeight + 2 * checkmarkWidth)
        }
        .onAppear {
            firstLineStartPoint = CGPoint(x: 0.294 * checkmarkWidth + checkmarkStartWidth, y: 0.530 * checkmarkWidth + checkmarkStartHeight)
            firstLineEndPoint = firstLineStartPoint
            
            secondLineStartPoint = CGPoint(x: 0.437 * checkmarkWidth + checkmarkStartWidth, y: 0.710 * checkmarkWidth + checkmarkStartHeight)
            secondLineEndPoint = secondLineStartPoint
            
            withAnimation(Animation.easeOut(duration: 1.5)) {
                trimAmount = 1
            }
            
            withAnimation(Animation.easeIn(duration: 0.5)) {
                firstLineEndPoint = secondLineStartPoint
            }
            
            withAnimation(Animation.easeOut(duration: 1).delay(0.5)) {
                secondLineEndPoint = CGPoint(x: 0.695 * checkmarkWidth + checkmarkStartWidth, y: 0.308 * checkmarkWidth + checkmarkStartHeight)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            makeView(geometry)
        }
    }
}

struct SplashScreenFinishView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var currentSetting: CurrentSetting
    
    var body: some View {
        VStack {
            CheckmarkView()
            
            Spacer()

            Button(action: {
                changeSplashScreenFinished(newState: true, settingsObject: currentSetting.setting!, managedObjectContext: managedObjectContext)
            }) {
                Text("Finish")
            }
            .buttonStyle(ContinueButtonStyle())
        }
        .padding([.leading, .trailing], 20)
        .padding(.bottom, 16)
    }
}

struct SplashScreenFinishView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenFinishView()
    }
}
