import Foundation
import FirebaseFirestore
import Combine

@MainActor
class FirestoreService: ObservableObject {
    @Published var tasks: [CommanderTask] = []
    @Published var workers: [CommanderWorker] = []
    @Published var isLoading = true

    private let db = Firestore.firestore()
    private var taskListener: ListenerRegistration?
    private var workerListener: ListenerRegistration?

    init() {
        listenToTasks()
        listenToWorkers()
    }

    func listenToTasks() {
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
        workerListener = db.collection("commander_workers")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.workers = docs.compactMap { Self.parseWorker($0) }
                }
            }
    }

    func createTask(
        project: String,
        path: String,
        task: String,
        description: String,
        priority: Int,
        dependsOn: [Int] = [],
        assignedWorker: String? = nil,
        allowParallel: Bool = false
    ) async throws {
        let maxNumId = tasks.map(\.numId).max() ?? 0
        var data: [String: Any] = [
            "num_id": maxNumId + 1,
            "project": project,
            "path": path,
            "task": task,
            "description": description,
            "status": "pending",
            "priority": priority,
            "depends_on": dependsOn,
            "allow_parallel": allowParallel,
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]
        if let worker = assignedWorker {
            data["assigned_worker"] = worker
        }
        try await db.collection("commander_tasks").addDocument(data: data)
    }

    func updateTaskStatus(taskId: String, status: TaskStatus) async throws {
        try await db.collection("commander_tasks").document(taskId).updateData([
            "status": status.rawValue,
            "updated_at": FieldValue.serverTimestamp()
        ])
    }

    func retryTask(taskId: String) async throws {
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
        let data: [String: Any] = [
            "role": "user",
            "content": content,
            "status": "pending",
            "created_at": FieldValue.serverTimestamp()
        ]
        try await db.collection("commander_tasks").document(taskId)
            .collection("chat").addDocument(data: data)
    }

    func listenToOutput(taskId: String, handler: @escaping ([OutputChunk]) -> Void) -> ListenerRegistration {
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

    func listenToChat(taskId: String, handler: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
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

    deinit {
        taskListener?.remove()
        workerListener?.remove()
    }
}
