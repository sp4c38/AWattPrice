//
//  DownloadPublisherLoadingViewObserver.swift
//  AWattPrice
//
//  Created by Léon Becker on 12.12.21.
//

import Combine
import Foundation

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
