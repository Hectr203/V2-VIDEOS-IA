import Foundation

extension VPhoneGuestControl {
    // MARK: - Keychain Operations

    struct KeychainResult {
        let items: [[String: Any]]
        let diagnostics: [String]
    }

    func listKeychainItems() async throws -> KeychainResult {
        let req: [String: Any] = ["t": "keychain_list"]
        let (resp, _) = try await sendRequest(req)
        guard let items = resp["items"] as? [[String: Any]] else {
            throw ControlError.protocolError("missing items in keychain response")
        }
        let diag = resp["diag"] as? [String] ?? []
        return KeychainResult(items: items, diagnostics: diag)
    }

    func addKeychainItem(
        account: String = "vphone-test",
        service: String = "vphone",
        password: String = "testpass123",
    ) async throws {
        let req: [String: Any] = [
            "t": "keychain_add", "account": account, "service": service, "password": password,
        ]
        let (resp, _) = try await sendRequest(req)
        let ok = resp["ok"] as? Bool ?? false
        if !ok {
            let msg = resp["msg"] as? String ?? "unknown error"
            throw ControlError.protocolError("keychain_add: \(msg)")
        }
    }

    /// The attributes that name one item for the guest. Empty attributes are
    /// left out so they do not widen the query the guest builds from them.
    struct KeychainIdentity {
        var itemClass = "genp"
        var account = ""
        var service = ""
        var server = ""
        var accessGroup = ""

        func request(_ type: String) -> [String: Any] {
            var params = parameters
            params["t"] = type
            return params
        }

        var parameters: [String: Any] {
            var params: [String: Any] = ["class": itemClass]
            for (key, value) in [
                ("account", account), ("service", service),
                ("server", server), ("group", accessGroup),
            ] where !value.isEmpty {
                params[key] = value
            }
            return params
        }
    }

    func keychainValue(of identity: KeychainIdentity) async throws -> String {
        let (resp, _) = try await sendRequest(identity.request("keychain_get"))
        guard resp["ok"] as? Bool == true, let value = resp["value"] as? String else {
            throw ControlError.guestError(resp["msg"] as? String ?? "Unable to read the keychain item")
        }
        return value
    }

    func updateKeychainItem(_ identity: KeychainIdentity, value: String) async throws {
        var params = identity.request("keychain_update")
        params["value"] = value
        let (resp, _) = try await sendRequest(params)
        guard resp["ok"] as? Bool == true else {
            throw ControlError.guestError(resp["msg"] as? String ?? "Unable to update the keychain item")
        }
    }

    @discardableResult
    func deleteKeychainItem(_ identity: KeychainIdentity) async throws -> Bool {
        let (resp, _) = try await sendRequest(identity.request("keychain_delete"))
        guard resp["ok"] as? Bool == true else {
            throw ControlError.guestError(resp["msg"] as? String ?? "Unable to delete the keychain item")
        }
        return resp["removed"] as? Bool ?? false
    }

    func deleteKeychainItem(account: String, service: String) async throws -> Bool {
        try await deleteKeychainItem(KeychainIdentity(account: account, service: service))
    }
}
