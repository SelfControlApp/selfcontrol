//
//  ServerResponse.swift
//  SelfControl
//
//  Created by Satendra Singh on 07/12/25.
//


import SafariServices
import os.log

final class ServerPing {
    var timer: Timer?
    var blockedURL: Set<String> = []
    
    init() { }
    
    func start() {
        ping()
        timer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(ping), userInfo: nil, repeats: true)
    }
    
    @objc private func ping() {
        fetchDataForExtension()
    }
    
    
    private func fetchDataForExtension() {
        let url = URL(string: Const.serviceURL)!

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                os_log("[SC] Fetch failed: %{public}@", error.localizedDescription)
                return
            }

            guard let data = data else {
                os_log(("[SC] Fetch data Nil"))
    //            completion([])
                return
            }
            os_log("[SC] Fetch data successful: %{public}@", String(decoding: data, as: UTF8.self))
            do {
                let decoded = try JSONDecoder().decode(ServerResponse.self, from: data)
                self.blockedURL = .init(decoded.blocked)
//                completion(decoded.blocked)
            } catch {
                os_log(("[SC] Fetch failed: \(error.localizedDescription)"))
//                completion([])
            }

        }.resume()
    }
}

struct ServerResponse: Codable {
    let blocked: [String]
}
