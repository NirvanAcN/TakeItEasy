//
//  ContentView.swift
//  TakeItEasy
//
//  Created by 马浩萌 on 2024/4/16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            CameraView() // SwiftUI与UIKit混用
                .background(Color.red)
            Text("Hello, world!")
        }
        .padding()
        .onTapGesture {
            print("@mahaomeng this is my action")
        }
    }
}


//#Preview {
//    ContentView()
//}
