public enum GameModelError: Error, Equatable, Sendable {
    case invalidConfig(String)
    case invalidMap(String)
}
