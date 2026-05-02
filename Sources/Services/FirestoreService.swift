import Foundation
import FirebaseFirestore
import Combine

@MainActor
class FirestoreService: ObservableObject {
    @Published var tasks: [CommanderTask] = []
    @Published var workers: [CommanderWorker] = []
    @Published var notifications: [CommanderNotification] = []
    @Published var isLoading = true
    @Published var unreadCount = 0

    private let db = Firestore.firestore()
    private var taskListener: ListenerRegistration?
    private var workerListener: ListenerRegistration?
    private var notificationListener: ListenerRegistration?

    init() {
        listenToTasks()
        listenToWorkers()
        listenToNotifications()
    }

    // MARK: - Listeners

    func listenToTasks() {
        taskListener = db.collection("commander_tasks")
            .order(by: "created_at", descending: true)
            .limit(to: 200)
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

    func listenToNotifications() {
        notificationListener = db.collection("commander_notifications")
            .order(by: "created_at", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.notifications = docs.compactMap { Self.parseNotification($0) }
                    self?.unreadCount = self?.notifications.filter { !$0.read }.count ?? 0
                }
            }
    }

    // MARK: - Task CRUD

    func createTask(project: String, path: String, task: String, description: String, priority: Int, assignedWorker: String? = nil, dependsOn: [Int] = []) async throws {
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
            "allow_parallel": false,
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]
        if let worker = assignedWorker {
            data["assigned_worker"] = worker
        }
        try await db.collection("commander_tasks").addDocument(data: data)
    }

    func updateTaskStatus(taskId: String, status: TaskStatus) async throws {
        var data: [String: Any] = [
            "status": status.rawValue,
            "updated_at": FieldValue.serverTimestamp()
        ]
        if status == .done {
            data["completed_at"] = FieldValue.serverTimestamp()
        }
        try await db.collection("commander_tasks").document(taskId).updateData(data)
    }

    func updateTaskPriority(taskId: String, priority: Int) async throws {
        try await db.collection("commander_tasks").document(taskId).updateData([
            "priority": priority,
            "updated_at": FieldValue.serverTimestamp()
        ])
    }

    func updateTaskFields(taskId: String, fields: [String: Any]) async throws {
        var data = fields
        data["updated_at"] = FieldValue.serverTimestamp()
        try await db.collection("commander_tasks").document(taskId).updateData(data)
    }

    func deleteTask(taskId: String) async throws {
        try await db.collection("commander_tasks").document(taskId).delete()
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

    func approveTask(taskId: String) async throws {
        try await db.collection("commander_tasks").document(taskId).updateData([
            "review_status": "approved",
            "updated_at": FieldValue.serverTimestamp()
        ])
    }

    func rejectTask(taskId: String) async throws {
        try await db.collection("commander_tasks").document(taskId).updateData([
            "review_status": "rejected",
            "status": "pending",
            "updated_at": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Bulk Operations

    func bulkUpdateStatus(taskIds: [String], status: TaskStatus) async throws {
        let batch = db.batch()
        for taskId in taskIds {
            let ref = db.collection("commander_tasks").document(taskId)
            batch.updateData([
                "status": status.rawValue,
                "updated_at": FieldValue.serverTimestamp()
            ], forDocument: ref)
        }
        try await batch.commit()
    }

    func bulkRetry(taskIds: [String]) async throws {
        let batch = db.batch()
        for taskId in taskIds {
            let ref = db.collection("commander_tasks").document(taskId)
            batch.updateData([
                "status": "pending",
                "claimed_by": FieldValue.delete(),
                "claimed_at": FieldValue.delete(),
                "started_at": FieldValue.delete(),
                "completed_at": FieldValue.delete(),
                "exit_code": FieldValue.delete(),
                "error": FieldValue.delete(),
                "review_status": FieldValue.delete(),
                "updated_at": FieldValue.serverTimestamp()
            ], forDocument: ref)
        }
        try await batch.commit()
    }

    // MARK: - Workers

    func restartWorker(workerId: String) async throws {
        try await db.collection("commander_workers").document(workerId).updateData([
            "restart_requested": true,
            "restart_requested_at": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Chat & Output

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

    // MARK: - Notifications

    func markNotificationRead(notificationId: String) async throws {
        try await db.collection("commander_notifications").document(notificationId).updateData([
            "read": true
        ])
    }

    func markAllNotificationsRead() async throws {
        let unread = notifications.filter { !$0.read }
        let batch = db.batch()
        for notification in unread {
            let ref = db.collection("commander_notifications").document(notification.id)
            batch.updateData(["read": true], forDocument: ref)
        }
        try await batch.commit()
    }

    // MARK: - Computed Properties

    var projects: [String] {
        Array(Set(tasks.map(\.project))).sorted()
    }

    var tasksByProject: [String: [CommanderTask]] {
        Dictionary(grouping: tasks, by: \.project)
    }

    func tasksForStatus(_ status: TaskStatus) -> [CommanderTask] {
        tasks.filter { $0.effectiveStatus == status }
    }

    var totalCost: Double {
        tasks.compactMap(\.costUsd).reduce(0, +)
    }

    // MARK: - Parsing

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
            activeTaskCount: data["active_task_count"] as? Int ?? 0,
            restartRequested: data["restart_requested"] as? Bool ?? false
        )
    }

    private static func parseNotification(_ doc: QueryDocumentSnapshot) -> CommanderNotification? {
        let data = doc.data()
        return CommanderNotification(
            id: doc.documentID,
            message: data["message"] as? String ?? "",
            type: NotificationType(rawValue: data["type"] as? String ?? "info") ?? .info,
            read: data["read"] as? Bool ?? false,
            taskId: data["task_id"] as? String,
            workerId: data["worker_id"] as? String,
            createdAt: (data["created_at"] as? Timestamp)?.dateValue()
        )
    }

    deinit {
        taskListener?.remove()
        workerListener?.remove()
        notificationListener?.remove()
    }
}
