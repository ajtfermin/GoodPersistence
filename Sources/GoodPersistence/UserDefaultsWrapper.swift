//  UserDefaultsWrapper.swift
//
//  Created by Dominik Pethö on 1/15/21.
//
//  https://github.com/jrendel/SwiftKeychainWrapper


import Foundation
import Combine
import CombineExt
import SwiftUI

/// The UserDefaultValue wraps a value of any type that conforms to the Codable protocol, in order to store it in UserDefaults
@available(iOS 13.0, *)
@propertyWrapper
public class UserDefaultValue<T: Codable> {
    
    /// A struct that wraps the value that we want to store in UserDefaults, in order to store values of types conforming to Codable.
    struct Wrapper: Codable {
        
        let value: T
        
    }
    
    // A PassthroughSubject is a subject that can pass values directly to its subscribers.
    private let subject: PassthroughSubject<T, Never> = PassthroughSubject()
    private let key: String
    private let defaultValue: T
    
    /// Initializes a UserDefaultValue instance with a given key and default value.
    /// - Parameters:
    ///   - key: The key for the UserDefaultValue item
    ///   - defaultValue: The default value for the UserDefaultValue item
    public init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    // This property is marked as a property wrapper, which means that it provides additional functionality around a stored value.
    public var wrappedValue: T {
        get {
            // If the data is of the correct type, return it.
            if let data = UserDefaults.standard.value(forKey: key) as? T {                
                return data
            }
            
            // If the data isn't of the correct type, try to decode it from the Data stored in UserDefaults.
            guard let data = UserDefaults.standard.object(forKey: key) as? Data else {
                PersistenceLogger.log(message: "Default UserDefaults value [\(defaultValue)] for key [\(key)] used. Reason: Data not retrieved.")
                return defaultValue
            }

            do {
                let value = try PropertyListDecoder().decode(Wrapper.self, from: data).value
                return value
            } catch {
                PersistenceLogger.log(error: error)
                PersistenceLogger.log(message: "Default UserDefaults value [\(defaultValue)] for key [\(key)] used. Reason: Decoding error.")
                return defaultValue
            }
        }
        set(newValue) {
            // Wrap the new value in a Wrapper, and store the encoded Data in UserDefaults.
            let wrapper = Wrapper(value: newValue)

            do {
                let value = try PropertyListEncoder().encode(wrapper)
                UserDefaults.standard.set(value, forKey: key)
                subject.send(newValue)
                PersistenceLogger.log(message: "UserDefaults data for key [\(key)] has changed to \(newValue).")
            } catch {
                PersistenceLogger.log(error: error)
                PersistenceLogger.log(message: "Setting UserDefaults value [\(defaultValue)] for key [\(key)] not performed. Reason: Encoding error.")
            }
        }
    }
    
    // This property is marked as a property wrapper, which means that it provides additional functionality around a stored value.
    public var projectedValue: Binding<T> {
        Binding(get: {
            return self.wrappedValue
        }, set: { newValue in
            self.wrappedValue = newValue
        })
    }
    
    /// The publisher property provides an AnyPublisher that sends the current value of wrappedValue, followed by any future changes.
    public lazy var publisher: AnyPublisher<T, Never> = {
        Deferred {
            self.subject
                .prepend(self.wrappedValue)
                .share(replay: 1)
        }.eraseToAnyPublisher()
    }()
    
}
