//
//  DNSQuestion.swift
//  SelfControl
//
//  Created by Satendra Singh on 02/08/25.
//

import Foundation

struct DNSQuestion {
    let name: String
    let type: UInt16
    let qclass: UInt16
}

struct DNSMessage {
    let id: UInt16
    let isQuery: Bool
    let opcode: UInt8
    let questions: [DNSQuestion]
}

class DNSParser {
    static func parseMessage(_ data: Data) -> DNSMessage? {
        guard data.count >= 12 else { return nil } // DNS header size

        let id = data.uint16(at: 0)
        let flags = data.uint16(at: 2)

        let isQuery = (flags & 0x8000) == 0
        let opcode = UInt8((flags & 0x7800) >> 11)
        let qdcount = data.uint16(at: 4)

        var offset = 12
        
        var questions: [DNSQuestion] = []

        for _ in 0..<qdcount {
            guard let (name, nextOffset) = parseDomainName(data, offset: offset) else { return nil }
            offset = nextOffset
            guard data.count >= offset + 4 else { return nil }
            let type = data.uint16(at: offset)
            let qclass = data.uint16(at: offset + 2)
            offset += 4
            questions.append(DNSQuestion(name: name, type: type, qclass: qclass))
        }

        return DNSMessage(id: id, isQuery: isQuery, opcode: opcode, questions: questions)
    }

    private static func parseDomainName(_ data: Data, offset: Int) -> (String, Int)? {
        var labels: [String] = []
        var index = offset
        while index < data.count {
            let length = Int(data[index])
            if length == 0 {
                index += 1
                break
            }
            guard index + length < data.count else { return nil }
            let labelData = data.subdata(in: index+1..<(index+1+length))
            if let label = String(data: labelData, encoding: .utf8) {
                labels.append(label)
            } else {
                return nil
            }
            index += length + 1
        }
        return (labels.joined(separator: "."), index)
    }
}

