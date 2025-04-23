//
//  Helpers.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/23/25.
//

import Foundation

func makeNewVideoURL() throws -> URL {
    let docs = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)
        .first!
    let filename = UUID().uuidString + ".mp4"
    return docs.appendingPathComponent(filename)
}


