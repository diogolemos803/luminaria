// swift-tools-version:5.9
// Testes das funções puras do app (sem iPhone, sem Screen Time): o módulo `SoveeCore`
// compila os MESMOS arquivos do app por links simbólicos em `Sources/SoveeCore` — nada é
// copiado. O app não depende deste pacote. Rodar: `cd Packages/SoveeCore && swift test`.
import PackageDescription

let package = Package(
    name: "SoveeCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SoveeCore",
            path: "Sources",
            swiftSettings: [.define("SOVEE_TESTS")]
        ),
        .testTarget(
            name: "SoveeCoreTests",
            dependencies: ["SoveeCore"],
            path: "Tests/SoveeCoreTests"
        ),
    ]
)
