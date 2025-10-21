//
//  PreferencesView.swift
//  SelfControl
//
//  Created by Satendra Singh on 12/07/25.
//

import SwiftUI

struct PreferencesView: View {
    @State private var domains = ProxyPreferences.getBlockedDomains()
    @State private var newDomain = ""
    @EnvironmentObject var viewModel: FilterViewModel

    var body: some View {
        VStack {
            List {
                ForEach(domains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                        Spacer()
                        Button(action: {
                            deleteItem(domain: domain)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle()) // ensures button works inside List
                    }
                }
                .onDelete(perform: delete) // still supports swipe-to-delete
            }

            HStack {
                TextField("Add Domain", text: $newDomain)
                Button("Add") {
                    addDomain()
                }
            }

            Button("Save Preferences") {
                ProxyPreferences.setBlockedDomains(domains)
                viewModel.setBlockedUrls(urls: domains)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }

    func addDomain() {
        guard !newDomain.isEmpty else { return }
//        guard let domainValue = newDomain.domainString else { return }
        domains.append(newDomain)
        newDomain = ""
        ProxyPreferences.setBlockedDomains(domains)
    }

    func delete(at offsets: IndexSet) {
        domains.remove(atOffsets: offsets)
        ProxyPreferences.setBlockedDomains(domains)
    }
    
    func deleteItem(domain: String) {
        if let index = domains.firstIndex(of: domain) {
            domains.remove(at: index)
        }
    }
}
