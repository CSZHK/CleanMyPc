import AtlasPrivilegedHelperCore
import AtlasProtocol
import Foundation

@main
struct AtlasPrivilegedHelperMain {
    static func main() {
        if CommandLine.arguments.contains("--action-json") {
            runJSONActionMode()
            return
        }

        let actions = AtlasPrivilegedActionKind.allCases.map(\.rawValue).joined(separator: ", ")
        print("AtlasPrivilegedHelper ready")
        print("Allowlisted actions: \(actions)")
    }

    private static func runJSONActionMode() {
        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        do {
            let action = try decoder.decode(AtlasHelperAction.self, from: inputData)
            let result = try AtlasPrivilegedHelperActionExecutor().perform(action)
            FileHandle.standardOutput.write(try encoder.encode(result))
        } catch {
            let fallbackAction = AtlasHelperAction(kind: .trashItems, targetPath: "")
            let result = AtlasHelperActionResult(action: fallbackAction, success: false, message: error.localizedDescription)
            if let data = try? encoder.encode(result) {
                FileHandle.standardOutput.write(data)
            }
        }
    }
}
