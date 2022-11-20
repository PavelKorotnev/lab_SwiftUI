//
//  ContentView.swift
//  Tune
//
//  Created by Korotnev Pavel on 13.11.2022.
//

import SwiftUI


struct ContentView: View {
    
    @ObservedObject var audio = Audio()
    
    let drops = [
        "Low D",
        "Drop D",
        "Standart"
    ]
    
    let notes = [
        ["D", "G", "C", "F", "A", "D"],
        ["D", "A", "D", "G", "B", "E"],
        ["E", "A", "D", "G", "B", "E"]
    ]
    
    @State private var actDrop : Int = 2
    
    
    var body: some View {
        NavigationView() {
            VStack {
                HStack {
                    Spacer()
                    
                    NavigationLink(
                        destination: InfoView(),
                        label: {
                            Image(systemName: "gear")
                                .font(.system(size: 25))
                        })
                    .padding()
                }
                
                
                Spacer()
                
                Text(audio.note)
                    .font(.system(size: 40))
                
                Spacer()
                
                HStack {
                    Text("6 ст.")
                        .padding(5)
                    
                    Spacer()
                    
                    ForEach(0 ..< 6) {i in
                        Text(self.notes[actDrop][i])
                            .foregroundColor(.blue)
                            .padding(10)
                    }
                    
                    Spacer()
                    
                    Text("1 ст.")
                        .padding(5)
                }
                
                Picker(selection: $actDrop, label: Text("Выбор строя")) {
                    ForEach(0 ..< drops.count) {
                        i in Text(self.drops[i])
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 300)
                .padding()
            }
            .padding()
        }
        .navigationBarHidden(true)
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

