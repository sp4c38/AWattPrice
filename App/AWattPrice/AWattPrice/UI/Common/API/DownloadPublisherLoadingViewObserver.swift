//
//  DownloadPublisherLoadingViewObserver.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.12.21.
//

import Combine
import Foundation

class DownloadPublisherLoadingViewObserver: ObservableObject {
    enum LoadingState {
        case uploadingAndTimeNotExceeded, uploadingAndTimeExceeded, notUploading
    }
    
    let intervalBeforeExceeded: TimeInterval
    
    @Published var loadingPublisher: LoadingState
    var downloadPublisherCancellable: AnyCancellable? = nil
    var downloadPublisherCompleted = false
    
    init(intervalBeforeExceeded: TimeInterval) {
        self.intervalBeforeExceeded = intervalBeforeExceeded
        self.loadingPublisher = .notUploading
    }
    
    func register(on queue: DispatchQueue = DispatchQueue.global(qos: .userInteractive), for downloadPublisher: AnyPublisher<Never, Error>) {
        downloadPublisherCancellable = downloadPublisher.receive(on: queue).sink(receiveCompletion: {_ in self.loadingPublisher = .notUploading }, receiveValue: { _ in})
        
        guard intervalBeforeExceeded > 0 else {
            loadingPublisher = .uploadingAndTimeExceeded
            return
        }
        loadingPublisher = .uploadingAndTimeNotExceeded // set back to default
        
        queue.asyncAfter(deadline: DispatchTime.now() + intervalBeforeExceeded) {
            if self.loadingPublisher != .notUploading {
                self.loadingPublisher = .uploadingAndTimeExceeded
            }
        }
    }
}

class UploadErrorPublisherViewObserver: ObservableObject {
    enum ViewState {
        case okay
        case lastUploadFailed
    }
    
    @Published var viewState: ViewState = .okay
    var cancellables = [AnyCancellable]()
    
    func register<T>(for uploadPublisher: AnyPublisher<T, Error>) {
        uploadPublisher.sink { completion in
            switch completion {
            case .finished:
                if self.viewState != .okay {
                    DispatchQueue.main.async { self.viewState = .okay }
                }
            case .failure(_):
                if self.viewState != .lastUploadFailed {
                    DispatchQueue.main.async { self.viewState = .lastUploadFailed }
                }
            }
        } receiveValue: { _ in }
        .store(in: &cancellables)
    }
}
