//
//  NetworkOperator.swift
//  CriticalMaps
//
//  Created by Leonard Thomas on 1/17/19.
//

import Foundation

public struct NetworkOperator: NetworkLayer {
    private let dataProvider: NetworkDataProvider
    private var networkIndicatorHelper: NetworkActivityIndicatorHelper?
    private static let validHttpResponseCodes = 200 ..< 299

    init(networkIndicatorHelper: NetworkActivityIndicatorHelper, dataProvider: NetworkDataProvider) {
        self.dataProvider = dataProvider
        self.networkIndicatorHelper = networkIndicatorHelper
    }
    
    public init(dataProvider: NetworkDataProvider) {
        self.dataProvider = dataProvider
    }

    public func get<T: APIRequestDefining>(request: T, completion: @escaping ResultCallback<T.ResponseDataType>) {
        dataTaskHandler(request: request, urlRequest: request.makeRequest(), completion: completion)
    }

    public func post<T: APIRequestDefining>(request: T, bodyData: Data, completion: @escaping ResultCallback<T.ResponseDataType>) {
        var urlRequest = request.makeRequest()
        urlRequest.httpBody = bodyData
        dataTaskHandler(request: request, urlRequest: urlRequest, completion: completion)
    }
    
    private func dataTaskHandler<T: APIRequestDefining>(request: T,urlRequest: URLRequest,  completion: @escaping ResultCallback<T.ResponseDataType>) {
        dataTask(with: urlRequest) { result in
            switch result {
            case let .failure(error):
                completion(.failure(error))
            case let .success(data):
                do {
                    let responseData = try request.parseResponse(data: data)
                    completion(.success(responseData))
                } catch let decodingError {
                    completion(.failure(NetworkError.decodingError(decodingError)))
                }
            }
        }
    }

    private func dataTask(with request: URLRequest,
                          completion: @escaping ResultCallback<Data>) {
        networkIndicatorHelper?.didStartRequest()
        dataProvider.dataTask(with: request) { data, response, error in
            self.networkIndicatorHelper?.didEndRequest()
            guard (error as? URLError)?.code != URLError.notConnectedToInternet else {
                completion(.failure(NetworkError.offline))
                return
            }
            guard let data = data else {
                completion(.failure(NetworkError.noData(error)))
                return
            }
            guard
                let statusCode = (response as? HTTPURLResponse)?.statusCode,
                NetworkOperator.validHttpResponseCodes ~= statusCode
            else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            completion(.success(data))
        }
    }

    public func cancelActiveRequestsIfNeeded() {
        dataProvider.invalidateAndCancel()
    }
}
