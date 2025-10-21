//
//  SafariExtensionView.swift
//  SelfControl
//
//  Created by Satendra Singh on 05/10/25.
//

import SwiftUI

struct SafariExtensionView: View {
    @StateObject private var vm = BlockListViewModel()

    var body: some View {
        VStack {
//            HStack {
//                Text("Blocked paths (domain/path)").font(.headline)
//                Spacer()
//                Button(action: vm.addSample) {
//                    Text("Add sample")
//                }
//            }.padding(.horizontal)
//
//            List {
//                ForEach(vm.blockedPaths.indices, id: \ .self) { idx in
//                    HStack {
//                        TextField("domain/path", text: $vm.blockedPaths[idx])
//                        Button(action: { vm.remove(at: idx) }) {
//                            Image(systemName: "minus.circle")
//                        }.buttonStyle(BorderlessButtonStyle())
//                    }
//                }
//            }.frame(minHeight: 200)

            HStack {
                Button(action: vm.updateBlocker) {
                    Text("Update Blocker")
                }
                Spacer()
                Button(action: vm.resetToDefaults) {
                    Text("Reset Defaults")
                }
            }.padding()
        }
        .onAppear {
            vm.updateBlocker()
        }
        .padding()
//        .frame(minWidth: 600, minHeight: 320)
    }
    //1550, 10300, soles, 250,
    //50, sanitry, 1, 4, 2 ,6, 5
    //solems, 45,
}

#Preview {
    SafariExtensionView()
}
