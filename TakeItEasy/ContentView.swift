//
//  ContentView.swift
//  TakeItEasy
//
//  Created by 马浩萌 on 2024/4/16.
//

import SwiftUI

struct ContentView: View {
    @State var txt: String = "Hello, world!"
    @State private var cameraViewInstance: CameraView?
    
    var body: some View {
        VStack {
            cameraViewInstance? // SwiftUI与UIKit混用
                .background(Color.red)
            Text(txt)
        }
        .padding()
        .onTapGesture {
            cameraViewInstance?.testAction() // 事件传递到UIKit
        }
        .onAppear {
            cameraViewInstance = CameraView(callback: { // UIKit事件回调到SwiftUI
                print(#function)
                txt = "this value from UIKit callback"
            }, txt: $txt)
        }
    }
}


//#Preview {
//    ContentView()
//}
