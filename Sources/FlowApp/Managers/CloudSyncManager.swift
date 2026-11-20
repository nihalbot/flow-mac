import Foundation
import Combine

public enum CloudSyncStatus: Equatable {
    case idle
    case syncing
    case synced(date: Date)
    case failed(error: String)
    case disabled
    
    public var displayText: String {
        switch self {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing to cloud..."
        case .synced(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Synced (\(formatter.localizedString(for: date, relativeTo: Date())))"
        case .failed(let err):
            return "Sync failed: \(err)"
        case .disabled:
            return "Cloud sync disabled"
        }
    }
}

public class CloudSyncManager: ObservableObject {
    public static let shared = CloudSyncManager()
    
    @Published public var syncStatus: CloudSyncStatus = .idle
    @Published public var isICloudAvailable: Bool = false
    @Published public var cloudEndpointURL: String = ""
    @Published public var cloudAPIKey: String = ""
    
    private let fileManager = FileManager.default
    private var iCloudDirectoryURL: URL?
    private var filePresenter: NSFilePresenter?
    
    public init() {
        checkICloudAvailability()
        loadSettings()
    }
    
    // MARK: - iCloud Sync (100% Free Apple Cloud)
    
    public func checkICloudAvailability() {
        // macOS standard iCloud Drive path: ~/Library/Mobile Documents/com~apple~CloudDocs/
        let home = fileManager.homeDirectoryForCurrentUser
        let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        
        if fileManager.fileExists(atPath: cloudDocs.path) {
            self.isICloudAvailable = true
            let flowCloudDir = cloudDocs.appendingPathComponent("FlowApp", isDirectory: true)
            try? fileManager.createDirectory(at: flowCloudDir, withIntermediateDirectories: true)
            self.iCloudDirectoryURL = flowCloudDir
        } else {
            self.isICloudAvailable = false
        }
    }
    
    public var iCloudHistoryFileURL: URL? {
        iCloudDirectoryURL?.appendingPathComponent("sessions_history.json")
    }
    
    /// Syncs local session data to Apple iCloud Drive for free
    public func syncToICloud(data: Data) -> Bool {
        guard isICloudAvailable, let targetURL = iCloudHistoryFileURL else {
            return false
        }
        
        do {
            try data.write(to: targetURL, options: .atomic)
            DispatchQueue.main.async {
                self.syncStatus = .synced(date: Date())
            }
            return true
        } catch {
            DispatchQueue.main.async {
                self.syncStatus = .failed(error: error.localizedDescription)
            }
            return false
        }
    }
    
    /// Pulls session data from Apple iCloud Drive
    public func fetchFromICloud() -> Data? {
        guard isICloudAvailable, let targetURL = iCloudHistoryFileURL else { return nil }
        guard fileManager.fileExists(atPath: targetURL.path) else { return nil }
        
        return try? Data(contentsOf: targetURL)
    }
    
    // MARK: - Free Custom Cloud API / Webhook (JSONBin, Supabase, Firebase, Cloudflare Worker)
    
    public func syncToFreeCloudEndpoint(data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !cloudEndpointURL.isEmpty, let url = URL(string: cloudEndpointURL) else {
            completion(.failure(NSError(domain: "CloudSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Cloud Endpoint URL"])))
            return
        }
        
        DispatchQueue.main.async {
            self.syncStatus = .syncing
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !cloudAPIKey.isEmpty {
            request.setValue(cloudAPIKey, forHTTPHeaderField: "X-Access-Key")
            request.setValue("Bearer \(cloudAPIKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = data
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.syncStatus = .failed(error: error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    self?.syncStatus = .synced(date: Date())
                    completion(.success(()))
                } else {
                    let err = NSError(domain: "CloudSync", code: (response as? HTTPURLResponse)?.statusCode ?? -2, userInfo: [NSLocalizedDescriptionKey: "Cloud server returned error"])
                    self?.syncStatus = .failed(error: err.localizedDescription)
                    completion(.failure(err))
                }
            }
        }.resume()
    }
    
    public func fetchFromFreeCloudEndpoint(completion: @escaping (Result<Data, Error>) -> Void) {
        guard !cloudEndpointURL.isEmpty, let url = URL(string: cloudEndpointURL) else {
            completion(.failure(NSError(domain: "CloudSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Cloud Endpoint URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !cloudAPIKey.isEmpty {
            request.setValue(cloudAPIKey, forHTTPHeaderField: "X-Access-Key")
            request.setValue("Bearer \(cloudAPIKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    completion(.failure(NSError(domain: "CloudSync", code: -3, userInfo: [NSLocalizedDescriptionKey: "Empty data from cloud"])))
                    return
                }
                completion(.success(data))
            }
        }.resume()
    }
    
    // MARK: - Persistence of settings
    
    public func saveSettings() {
        UserDefaults.standard.set(cloudEndpointURL, forKey: "cloudEndpointURL")
        UserDefaults.standard.set(cloudAPIKey, forKey: "cloudAPIKey")
    }
    
    private func loadSettings() {
        self.cloudEndpointURL = UserDefaults.standard.string(forKey: "cloudEndpointURL") ?? ""
        self.cloudAPIKey = UserDefaults.standard.string(forKey: "cloudAPIKey") ?? ""
    }
}
