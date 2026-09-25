import DependenciesTestSupport
import Testing

/// Gives every nested test its own isolated dependencies, so tests running in
/// parallel never see each other's overrides. Nest each suite in an
/// `extension BaseSuite`.
@Suite(.dependencies)
struct BaseSuite {}
