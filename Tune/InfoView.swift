//
//  InfoView.swift
//  Tune
//
//  Created by Korotnev Pavel on 20.11.2022.
//

import SwiftUI


struct InfoView: View {

    var body: some View {
        VStack {
            Spacer()
            
            Text("Версия: 0.0.1")
            
            Spacer()
            
            Text("Для связи")
            Text("pavelkorotnev.ai@gmail.com")
                .padding(EdgeInsets(top: CGFloat(5.0), leading: CGFloat(0.0), bottom: CGFloat(60.0), trailing: CGFloat(0.0)))
        }
        .navigationTitle(Text("Информация"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
