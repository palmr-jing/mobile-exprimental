import Foundation
import FirebaseFirestore
import Combine

@MainActor
class FirestoreService: ObservableObject {
    @Published var tasks: [CommanderTask] = []
    @Published var workers: [CommanderWorker] = []
    @Published var isLoading = true

    private var db: Firestore?
    private var taskListener: ListenerRegistration?
    private var workerListener: ListenerRegistration?

    init() {
        if AppConfiguration.isTesting {
            self.db = nil
            self.isLoading = false
            self.tasks = Self.mockTasks
            self.workers = Self.mockWorkers
            return
        }
        self.db = Firestore.firestore()
        listenToTasks()
        listenToWorkers()
    }

    func listenToTasks() {
        guard let db = db else { return }
        taskListener = db.collection("commander_tasks")
            .order(by: "created_at", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.tasks = docs.compactMap { Self.parseTask($0) }
                    self?.isLoading = false
                }
            }
    }

    func listenToWorkers() {
        guard let db = db else { return }
        workerListener = db.collection("commander_workers")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.workers = docs.compactMap { Self.parseWorker($0) }
                }
            }
    }

    func createTask(project: String, path: String, task: String, description: String, priority: Int) async throws {
        guard let db = db else { return }
        let maxNumId = tasks.map(\.numId).max() ?? 0
        let data: [String: Any] = [
            "num_id": maxNumId + 1,
            "project": project,
            "path": path,
            "task": task,
            "description": description,
            "status": "pending",
            "priority": priority,
            "depends_on": [] as [Int],
            "allow_parallel": false,
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]
        try await db.collection("commander_tasks").addDocument(data: data)
    }

    func updateTaskStatus(taskId: String, status: TaskStatus) async throws {
        guard let db = db else { return }
        try await db.collection("commander_tasks").document(taskId).updateData([
            "status": status.rawValue,
            "updated_at": FieldValue.serverTimestamp()
        ])
    }

    func retryTask(taskId: String) async throws {
        guard let db = db else { return }
        try await db.collection("commander_tasks").document(taskId).updateData([
            "status": "pending",
            "claimed_by": FieldValue.delete(),
            "claimed_at": FieldValue.delete(),
            "started_at": FieldValue.delete(),
            "completed_at": FieldValue.delete(),
            "exit_code": FieldValue.delete(),
            "error": FieldValue.delete(),
            "review_status": FieldValue.delete(),
            "updated_at": FieldValue.serverTimestamp()
        ])
    }

    func sendChatMessage(taskId: String, content: String) async throws {
        guard let db = db else { return }
        let data: [String: Any] = [
            "role": "user",
            "content": content,
            "status": "pending",
            "created_at": FieldValue.serverTimestamp()
        ]
        try await db.collection("commander_tasks").document(taskId)
            .collection("chat").addDocument(data: data)
    }

    func listenToOutput(taskId: String, handler: @escaping ([OutputChunk]) -> Void) -> ListenerRegistration? {
        guard let db = db else { return nil }
        return db.collection("commander_tasks").document(taskId)
            .collection("output")
            .order(by: "seq")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let chunks = docs.compactMap { doc -> OutputChunk? in
                    let data = doc.data()
                    return OutputChunk(
                        id: doc.documentID,
                        seq: data["seq"] as? Int ?? 0,
                        text: data["text"] as? String ?? "",
                        createdAt: (data["created_at"] as? Timestamp)?.dateValue()
                    )
                }
                handler(chunks)
            }
    }

    func listenToChat(taskId: String, handler: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration? {
        guard let db = db else { return nil }
        return db.collection("commander_tasks").document(taskId)
            .collection("chat")
            .order(by: "created_at")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let messages = docs.compactMap { doc -> ChatMessage? in
                    let data = doc.data()
                    return ChatMessage(
                        id: doc.documentID,
                        role: data["role"] as? String ?? "user",
                        content: data["content"] as? String ?? "",
                        status: data["status"] as? String,
                        createdAt: (data["created_at"] as? Timestamp)?.dateValue()
                    )
                }
                handler(messages)
            }
    }

    private static func parseTask(_ doc: QueryDocumentSnapshot) -> CommanderTask? {
        let data = doc.data()
        let statusStr = data["status"] as? String ?? "pending"
        guard let status = TaskStatus(rawValue: statusStr) else { return nil }

        var creator: TaskCreator?
        if let creatorData = data["created_by"] as? [String: Any] {
            creator = TaskCreator(
                uid: creatorData["uid"] as? String ?? "",
                email: creatorData["email"] as? String ?? "",
                name: creatorData["name"] as? String ?? "",
                photo: creatorData["photo"] as? String
            )
        }

        return CommanderTask(
            id: doc.documentID,
            numId: data["num_id"] as? Int ?? 0,
            project: data["project"] as? String ?? "",
            path: data["path"] as? String ?? "",
            task: data["task"] as? String ?? "",
            description: data["description"] as? String ?? "",
            status: status,
            priority: data["priority"] as? Int ?? 5,
            dependsOn: data["depends_on"] as? [Int] ?? [],
            allowParallel: data["allow_parallel"] as? Bool ?? false,
            assignedWorker: data["assigned_worker"] as? String,
            claimedBy: data["claimed_by"] as? String,
            createdBy: creator,
            costUsd: data["cost_usd"] as? Double,
            durationMs: data["duration_ms"] as? Int,
            exitCode: data["exit_code"] as? Int,
            error: data["error"] as? String,
            reviewStatus: data["review_status"] as? String,
            resultText: data["result_text"] as? String,
            followUp: data["follow_up"] as? String,
            createdAt: (data["created_at"] as? Timestamp)?.dateValue(),
            completedAt: (data["completed_at"] as? Timestamp)?.dateValue()
        )
    }

    private static func parseWorker(_ doc: QueryDocumentSnapshot) -> CommanderWorker? {
        let data = doc.data()
        return CommanderWorker(
            id: doc.documentID,
            hostname: data["hostname"] as? String ?? doc.documentID,
            status: WorkerStatus(rawValue: data["status"] as? String ?? "offline") ?? .offline,
            tasksCompleted: data["tasks_completed"] as? Int ?? 0,
            totalCost: data["total_cost"] as? Double ?? 0,
            lastHeartbeat: (data["last_heartbeat"] as? Timestamp)?.dateValue(),
            activeTaskCount: data["active_task_count"] as? Int ?? 0
        )
    }

    static let mockTasks: [CommanderTask] = [
        CommanderTask(
            id: "mock-1", numId: 101, project: "palmr-ios", path: "~/repos/palmr-ios-2",
            task: "Fix login button color", description: "The login button is hard to see on dark backgrounds",
            status: .done, priority: 3, dependsOn: [], allowParallel: false,
            costUsd: 0.042, durationMs: 45000, reviewStatus: "needs_review",
            createdAt: Date().addingTimeInterval(-3600)
        ),
        CommanderTask(
            id: "mock-2", numId: 102, project: "palmr-ios", path: "~/repos/palmr-ios-2",
            task: "Add push notifications", description: "Implement push notification support for task completion",
            status: .running, priority: 5, dependsOn: [], allowParallel: false,
            claimedBy: "worker-1", createdAt: Date().addingTimeInterval(-1800)
        ),
        CommanderTask(
            id: "mock-3", numId: 103, project: "commander", path: "~/repos/commander",
            task: "Update dashboard layout", description: "Redesign the dashboard grid to show more stats",
            status: .pending, priority: 5, dependsOn: [], allowParallel: false,
            createdAt: Date().addingTimeInterval(-900)
        ),
        CommanderTask(
            id: "mock-4", numId: 104, project: "palmr-ios", path: "~/repos/palmr-ios-2",
            task: "Fix crash on profile screen", description: "App crashes when tapping profile with no photo",
            status: .failed, priority: 2, dependsOn: [], allowParallel: false,
            error: "Index out of range", createdAt: Date().addingTimeInterval(-7200)
        ),
    ]

    static let mockWorkers: [CommanderWorker] = [
        CommanderWorker(
            id: "worker-1", hostname: "mac-studio-1", status: .online,
            tasksCompleted: 47, totalCost: 12.34,
            lastHeartbeat: Date(), activeTaskCount: 1
        ),
        CommanderWorker(
            id: "worker-2", hostname: "mac-mini-2", status: .offline,
            tasksCompleted: 23, totalCost: 5.67,
            lastHeartbeat: Date().addingTimeInterval(-300), activeTaskCount: 0
        ),
    ]

    deinit {
        taskListener?.remove()
        workerListener?.remove()
    }
}
