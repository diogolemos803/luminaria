// Substituto do `FamilyActivitySelection` do Screen Time (FamilyControls só existe no
// iPhone). `SleepRoutine.swift` só importa FamilyControls quando `SOVEE_TESTS` não está
// definido; aqui, nos testes, ele usa este tipo vazio.
struct FamilyActivitySelection: Codable, Equatable {
    init() {}
}
