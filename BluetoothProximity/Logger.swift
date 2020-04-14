//
//  Logger.swift
//  BluetoothProximity
//
//  Created by Michael Wentz on 4/13/20.
//  Copyright © 2020 Michael Wentz. All rights reserved.
//

import UIKit

// Logs timestamped data to file
class Logger {
    
    // File name and path
    var fileName: String!
    var fileURL: URL!
    
    // File manager and updater
    var fileManager = FileManager.default
    var fileUpdater : FileHandle!
    
    // Gets directory to save data
    func getDir() -> URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // Delete all old log files
    func deleteLogs() {
        let fileURLs = FileManager.default.urls(for: .documentDirectory)
        for u in fileURLs! {
            do {
                try fileManager.removeItem(atPath: u.path)
            } catch {
                #if DEBUG
                print("fileManager.removeItem error")
                #endif
            }
        }
    }
    
    // Creates a new log file
    func createNewLog() {
        
        // Create the log file with its name as a timestamp
        var timeStamp = getTimestamp()
        timeStamp = timeStamp.replacingOccurrences(of: " ", with: "_")
        timeStamp = timeStamp.replacingOccurrences(of: ":", with: ".")
        fileName = "log_" + timeStamp + ".txt"
        fileURL = getDir().appendingPathComponent(fileName)
        fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        do {
            try fileUpdater = FileHandle(forUpdating: fileURL)
        }
        catch {
            #if DEBUG
            print("fileUpdater = FileHandle error")
            #endif
            return
        }
        
        // Log the device type and name
        let deviceStr = "Device," + UIDevice.modelName + "," + UIDevice.current.name
        write(deviceStr)
    }
    
    // Gets timestamp
    func getTimestamp() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    // Logs a string
    func write(_ data: String) {
        
        // Add timestamp
        let dataWithTimestamp = getTimestamp() + "," + data
        
        // Print to console for debugging
        #if DEBUG
        print(dataWithTimestamp)
        #endif
        
        // Write to the end of the file as a new line
        let dataLine = dataWithTimestamp + "\n"
        fileUpdater.seekToEndOfFile()
        fileUpdater.write(dataLine.data(using: .utf8)!)
    }
}

// Lists all files in the directory
// usage: print(FileManager.default.urls(for: .documentDirectory) ?? "none")
extension FileManager {
    func urls(for directory: FileManager.SearchPathDirectory, skipsHiddenFiles: Bool = true ) -> [URL]? {
        let documentsURL = urls(for: directory, in: .userDomainMask)[0]
        let fileURLs = try? contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: skipsHiddenFiles ? .skipsHiddenFiles : [] )
        return fileURLs
    }
}
