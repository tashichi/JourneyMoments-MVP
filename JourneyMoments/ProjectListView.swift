import SwiftUI
import Photos

struct ProjectListView: View {
    let projects: [Project]
    let onCreateProject: () -> Void
    let onOpenProject: (Project) -> Void
    let onPlayProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void
    let onRenameProject: (Project, String) -> Void
    let onExportProject: (Project) -> Void
    
    // ← 追加：購入マネージャーと課金画面表示状態
    @ObservedObject var purchaseManager: PurchaseManager
    @State private var showPurchaseView = false
    
    @State private var showDeleteAlert = false
    @State private var projectToDelete: Project?
    
    // Rename functionality state management
    @State private var showRenameAlert = false
    @State private var projectToRename: Project?
    @State private var newProjectName: String = ""
    
    // Export state management
    @State private var exportingProjects: Set<Int> = []
    
    var body: some View {
        ZStack {
            // Full screen black background
            Color.black
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Project list or empty state
                if projects.isEmpty {
                    emptyStateView
                } else {
                    projectListView
                }
            }
        }
        // Delete confirmation alert
        .alert("Delete Project", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    onDeleteProject(project)
                }
                projectToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                projectToDelete = nil
            }
        } message: {
            if let project = projectToDelete {
                Text("Delete \"\(project.name)\"?\nThis action cannot be undone.")
            }
        }
        // Rename alert
        .alert("Rename Project", isPresented: $showRenameAlert) {
            TextField("Project Name", text: $newProjectName)
                .textInputAutocapitalization(.words)
            
            Button("Save") {
                if let project = projectToRename, !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    onRenameProject(project, trimmedName)
                    print("Project renamed: \(project.name) → \(trimmedName)")
                }
                resetRenameState()
            }
            .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button("Cancel", role: .cancel) {
                resetRenameState()
            }
        } message: {
            if let project = projectToRename {
                Text("Enter a new name for \"\(project.name)\"")
            }
        }
        // ← 追加：課金画面の表示
        .sheet(isPresented: $showPurchaseView) {
            PurchaseView(purchaseManager: purchaseManager)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 10) {
            // ← 修正：上部にステータスと購入ボタンを配置
            HStack(spacing: 20) {
                // 左側：ステータス表示
                Text(purchaseManager.isPurchased ? "Full Version" : "Free Version")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(purchaseManager.isPurchased ? .green : .gray)
                
                Spacer()
                
                // 右側：購入ボタン（未課金時のみ表示）
                if !purchaseManager.isPurchased {
                    Button(action: {
                        showPurchaseView = true
                    }) {
                        Text("Full Version")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // ClipFlowタイトル
            Text("ClipFlow")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // New Projectボタン（既存）
            Button(action: onCreateProject) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Project")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "video.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Projects")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Create a new project to start\ncapturing 1-second videos!")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // Project List (Unified button sizes)
    private var projectListView: some View {
        List {
            ForEach(projects) { project in
                VStack(alignment: .leading, spacing: 12) {
                    // Project info (name tappable for editing)
                    VStack(alignment: .leading, spacing: 4) {
                        // Make project name tappable
                        Button(action: {
                            print("Project name tapped: \(project.name)")
                            startRenamingProject(project)
                        }) {
                            HStack {
                                Text(project.name)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                // Show edit icon
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .opacity(0.7)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "video.fill")
                                    .font(.caption)
                                Text("\(project.segmentCount)s")
                                    .font(.caption)
                            }
                            .foregroundColor(.yellow)
                            
                            Spacer()
                            
                            Text(formatDate(project.createdAt))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Bottom button area (Rec | Play | Export)
                    HStack(spacing: 0) {
                        // Record button
                        Button {
                            print("Record button tapped: \(project.name)")
                            onOpenProject(project)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                Text("Rec")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color.red)
                            .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Play button
                        Button {
                            print("Play button tapped: \(project.name)")
                            onPlayProject(project)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                Text("Play")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color.blue)
                            .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(project.segmentCount == 0)
                        .opacity(project.segmentCount == 0 ? 0.5 : 1.0)
                        
                        // Export button
                        Button {
                            print("Export button tapped: \(project.name)")
                            handleExportProject(project)
                        } label: {
                            HStack(spacing: 6) {
                                if exportingProjects.contains(project.id) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption)
                                    Text("Export")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(exportingProjects.contains(project.id) ? Color.orange.opacity(0.7) : Color.orange)
                            .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(exportingProjects.contains(project.id) || project.segmentCount == 0)
                        .opacity(project.segmentCount == 0 ? 0.5 : 1.0)
                    }
                    .cornerRadius(8)
                    .clipped()
                }
                .padding(16)
                .background(Color(.systemGray6).opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                // Swipe actions (delete only)
                .swipeActions(edge: .trailing) {
                    Button("Delete") {
                        print("Delete target: \(project.name)")
                        projectToDelete = project
                        showDeleteAlert = true
                    }
                    .tint(.red)
                }
            }
        }
        .background(Color.black)
        .scrollContentBackground(.hidden)
        .listStyle(PlainListStyle())
    }
    
    // Export processing
    private func handleExportProject(_ project: Project) {
        // Set exporting state
        exportingProjects.insert(project.id)
        
        // Handle export completion
        Task {
            // Execute export process (delegate to main screen)
            onExportProject(project)
            
            // Release exporting state after 2 seconds (actual completion handled separately)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                exportingProjects.remove(project.id)
            }
        }
    }
    
    // Rename related functions
    private func startRenamingProject(_ project: Project) {
        projectToRename = project
        newProjectName = project.name  // Set current name as initial value
        showRenameAlert = true
    }
    
    private func resetRenameState() {
        projectToRename = nil
        newProjectName = ""
        showRenameAlert = false
    }

    // formatDate function
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - ProjectRowView (existing as is - unused but retained)
struct ProjectRowView: View {
    let project: Project
    let onOpen: () -> Void
    let onPlay: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Project info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.caption)
                        Text("\(project.segmentCount)s")
                            .font(.caption)
                    }
                    .foregroundColor(.yellow)
                    
                    Spacer()
                    
                    Text(formatDate(project.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Buttons
            HStack(spacing: 12) {
                // Record button
                Button(action: onOpen) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                        Text("Rec")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .frame(width: 60, height: 32)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Play button (only if segments exist)
                if project.segmentCount > 0 {
                    Button(action: onPlay) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                            Text("Play")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(width: 60, height: 32)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct ProjectListView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProjects = [
            Project(name: "Tokyo Trip", segments: [
                VideoSegment(uri: "sample1", facing: "back", order: 1)
            ])
        ]
        
        let mockPurchaseManager = PurchaseManager()
        
        ProjectListView(
            projects: sampleProjects,
            onCreateProject: {},
            onOpenProject: { _ in },
            onPlayProject: { _ in },
            onDeleteProject: { _ in },
            onRenameProject: { _, _ in },
            onExportProject: { _ in },
            purchaseManager: mockPurchaseManager
        )
    }
}
