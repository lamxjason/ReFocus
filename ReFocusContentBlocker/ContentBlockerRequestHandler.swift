import Foundation

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        // Load the blockerList.json from the App Group
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.refocus.shared"
        ) else {
            // Fallback to empty blocking rules
            completeWithEmptyRules(context: context)
            return
        }

        let blockerListURL = containerURL.appendingPathComponent("blockerList.json")

        // Check if the file exists and create attachment safely
        if FileManager.default.fileExists(atPath: blockerListURL.path),
           let attachment = NSItemProvider(contentsOf: blockerListURL) {
            let item = NSExtensionItem()
            item.attachments = [attachment]
            context.completeRequest(returningItems: [item], completionHandler: nil)
        } else {
            // Create empty blocker list
            completeWithEmptyRules(context: context)
        }
    }

    private func completeWithEmptyRules(context: NSExtensionContext) {
        let emptyListURL = createEmptyBlockerList()
        guard let attachment = NSItemProvider(contentsOf: emptyListURL) else {
            // If we can't even create an empty list, complete with no items
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        let item = NSExtensionItem()
        item.attachments = [attachment]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    private func createEmptyBlockerList() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("blockerList.json")

        let emptyRules = """
        [
            {
                "trigger": { "url-filter": "^$" },
                "action": { "type": "block" }
            }
        ]
        """

        try? emptyRules.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile
    }
}
