/// Copyright (c) 2023 Kodeco Inc.
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import SwiftUI
import UIKit
import Combine

/// The file download view.
struct DownloadView: View {
  /// The selected file.
  let file: DownloadFile
  @EnvironmentObject var model: SuperStorageModel
  /// The downloaded data.
  @State var fileData: Data?
  /// Should display a download activity indicator.
  @State var isDownloadActive = false {
    didSet {
      if !isDownloadActive {
        timerTask?.cancel()
      }
    }
  }

  @State var duration = ""
  
  @State var downloadTask: Task<Void, Error>? {
    didSet {
      timerTask?.cancel()
      guard isDownloadActive else { return }
      let startTime = Date().timeIntervalSince1970
      
      let timerSequence = Timer
        .publish(every: 1, tolerance: 1, on: .main, in: .common)
        .autoconnect()
        .map { date -> String in
          let duration = Int(date.timeIntervalSince1970 - startTime)
          print("Timer sequence firing")
          return "\(duration)s"
        }
        .values
      
      timerTask = Task {
        for await duration in timerSequence {
          self.duration = duration
        }
      }
    }
  }
  
  @State var timerTask: Task<Void, Error>?

  var body: some View {
    List {
      // Show the details of the selected file and download buttons.
      FileDetails(
        file: file,
        isDownloading: !model.downloads.isEmpty,
        isDownloadActive: $isDownloadActive,
        downloadSingleAction: {
          downloadTask = Task {
            defer {
              isDownloadActive = false
            }
            isDownloadActive = true
            fileData = try await model.download(file: file)
          }
        },
        downloadWithUpdatesAction: {
          isDownloadActive = true
          downloadTask = Task {
            do {
              type(of: model).supportsPartialDownloads = file.id.hasSuffix(".jpeg")
              fileData = try await model.downloadWithProgress(file: file)
            } catch {
              isDownloadActive = false
            }
            isDownloadActive = false
          }
        },
        downloadMultipleAction: {
          // Download a file in multiple concurrent parts.
          
          isDownloadActive = true
          
          downloadTask = Task {
            do {
              type(of: model).supportsPartialDownloads = file.id.hasSuffix(".jpeg")
              fileData = try await model.multiDownloadWithProgress(file: file)
            } catch {
              isDownloadActive = false
            }
            isDownloadActive = false
          }
        }
      )
      if !model.downloads.isEmpty {
        // Show progress for any ongoing downloads.
        Downloads(downloads: model.downloads)
      }

      if !duration.isEmpty {
        Text("Duration: \(duration)")
          .font(.caption)
      }

      if let fileData {
        // Show a preview of the file if it's a valid image.
        FilePreview(fileData: fileData)
      }
    }
    .animation(.easeOut(duration: 0.33), value: model.downloads)
    .listStyle(.insetGrouped)
    .toolbar {
      Button(action: {
        model.stopDownloads = true
        timerTask?.cancel()
      }, label: { Text("Cancel All") })
        .disabled(model.downloads.isEmpty)
    }
    .onDisappear {
      fileData = nil
      model.reset()
      downloadTask?.cancel()
      timerTask?.cancel()
    }
  }
}
