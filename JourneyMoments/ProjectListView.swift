import SwiftUI

struct ProjectListView: View {
    let projects: [Project]
    let onCreateProject: () -> Void
    let onOpenProject: (Project) -> Void
    let onPlayProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void
    let onRenameProject: (Project, String) -> Void  // 🆕 追加: 名前変更用コールバック
    
    @State private var showDeleteAlert = false
    @State private var projectToDelete: Project?
    
    // 🆕 追加: 名前変更機能の状態管理
    @State private var showRenameAlert = false
    @State private var projectToRename: Project?
    @State private var newProjectName: String = ""
    
    var body: some View {
        ZStack {
            // 画面全体の黒背景
            Color.black
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // ヘッダー
                headerView
                
                // プロジェクト一覧 or 空状態
                if projects.isEmpty {
                    emptyStateView
                } else {
                    projectListView
                }
            }
        }
        // 削除確認アラート
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
        // 🆕 追加: 名前変更アラート
        .alert("Rename Project", isPresented: $showRenameAlert) {
            TextField("Project Name", text: $newProjectName)
                .textInputAutocapitalization(.words)
            
            Button("Save") {
                if let project = projectToRename, !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    onRenameProject(project, trimmedName)
                    print("✅ Project renamed: \(project.name) → \(trimmedName)")
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
    }
    
    // MARK: - ヘッダー
    private var headerView: some View {
        VStack(spacing: 10) {
            Text("ClipFlow")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
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
    
    // MARK: - 空状態
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
    
    // 🔧 修正: プロジェクト一覧（名前変更機能追加）
    private var projectListView: some View {
        List {
            ForEach(projects) { project in
                VStack(alignment: .leading, spacing: 12) {
                    // 🆕 修正: プロジェクト情報（名前タップで編集可能）
                    VStack(alignment: .leading, spacing: 4) {
                        // 🆕 プロジェクト名をタップ可能にする
                        Button(action: {
                            print("🏷️ Project name tapped: \(project.name)")
                            startRenamingProject(project)
                        }) {
                            HStack {
                                Text(project.name)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                // 🆕 編集アイコン表示
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
                    
                    // ボタン群（既存のまま）
                    HStack(spacing: 12) {
                        // 撮影ボタン
                        Button {
                            print("🔵 Record button tapped: \(project.name)")
                            onOpenProject(project)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                Text("Record")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 再生ボタン（セグメントがある場合のみ）
                        if project.segmentCount > 0 {
                            Button {
                                print("🔴 Play button tapped: \(project.name)")
                                onPlayProject(project)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.caption)
                                    Text("Play")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer()
                    }
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
                .swipeActions(edge: .trailing) {
                    // 🆕 追加: 名前変更アクション
                    Button("Rename") {
                        print("🏷️ Rename action: \(project.name)")
                        startRenamingProject(project)
                    }
                    .tint(.orange)
                    
                    Button("Delete") {
                        print("🔍 Delete target: \(project.name)")
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
    
    // 🆕 追加: 名前変更関連の関数
    private func startRenamingProject(_ project: Project) {
        projectToRename = project
        newProjectName = project.name  // 現在の名前を初期値として設定
        showRenameAlert = true
    }
    
    private func resetRenameState() {
        projectToRename = nil
        newProjectName = ""
        showRenameAlert = false
    }

    // formatDate関数（既存のまま）
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - ProjectRowView（既存のまま - 未使用だが保持）
struct ProjectRowView: View {
    let project: Project
    let onOpen: () -> Void
    let onPlay: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // プロジェクト情報
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
            
            // ボタン
            HStack(spacing: 12) {
                // 撮影ボタン
                Button(action: onOpen) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                        Text("Record")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                
                // 再生ボタン（セグメントがある場合のみ）
                if project.segmentCount > 0 {
                    Button(action: onPlay) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.caption)
                            Text("Play")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(15)
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
        
        ProjectListView(
            projects: sampleProjects,
            onCreateProject: {},
            onOpenProject: { _ in },
            onPlayProject: { _ in },
            onDeleteProject: { _ in },
            onRenameProject: { _, _ in }  // 🆕 追加
        )
    }
}
