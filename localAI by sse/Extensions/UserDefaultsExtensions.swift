//
//  UserDefaultsExtensions.swift
//  localAI by sse
//
//  Created by sse-97 on 17.05.25.
//

import Foundation

// MARK: - UserDefaults Extension

/// Extends `UserDefaults` for type-safe access to stored application preferences.
extension UserDefaults {
    private enum Keys {
        static let selectedModelFilename = "selectedModelFilename"
        static let userModelConfigurationsData = "userModelConfigurationsData_v2"  // New key for StoredUserModel
    }
    
    var selectedModelFilename: String? {
        get { string(forKey: Keys.selectedModelFilename) }
        set { set(newValue, forKey: Keys.selectedModelFilename) }
    }
    
    var userModelConfigurations: [StoredUserModel] {
        get {
            guard let data = data(forKey: Keys.userModelConfigurationsData)
            else { return [] }
            do {
                return try JSONDecoder().decode(
                    [StoredUserModel].self,
                    from: data
                )
            } catch {
                // Log through centralized error handling system
                let error = AppError.system(.dataCorruption(dataType: "userModelConfigurations", details: error.localizedDescription))
                ErrorManager.shared.logError(error)
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                set(data, forKey: Keys.userModelConfigurationsData)
            } catch {
                // Log through centralized error handling system
                let error = AppError.system(.dataCorruption(dataType: "userModelConfigurations", details: error.localizedDescription))
                ErrorManager.shared.logError(error)
            }
        }
    }
}
