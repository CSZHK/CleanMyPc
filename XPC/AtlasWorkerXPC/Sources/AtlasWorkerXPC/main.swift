import AtlasCoreAdapters
import AtlasInfrastructure
import Foundation

let worker = AtlasScaffoldWorkerService(
    healthSnapshotProvider: MoleHealthAdapter(),
    smartCleanScanProvider: MoleSmartCleanAdapter(),
    appsInventoryProvider: MacAppsInventoryAdapter(),
    helperExecutor: AtlasPrivilegedHelperClient()
)
let listener = NSXPCListener.service()
let delegate = AtlasXPCListenerDelegate(host: AtlasXPCWorkerServiceHost(worker: worker))
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
