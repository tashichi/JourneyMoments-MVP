import SwiftUI

struct ProjectListView: View {
    let projects: [Project]
    let onCreateProject: () -> Void
    let onOpenProject: (Project) -> Void
    let onPlayProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void  // 🔧 追加: 削除用コールバック
    
    @State private var showDeleteAlert = false
    @State private var projectToDelete: Project?
    
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
        // 🔧 追加: 削除確認アラート
        .alert("プロジェクトを削除", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                if let project = projectToDelete {
                    onDeleteProject(project)
                }
                projectToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                projectToDelete = nil
            }
        } message: {
            if let project = projectToDelete {
                Text("「\(project.name)」を削除しますか？\nこの操作は取り消せません。")
            }
        }
    }
    
    // MARK: - ヘッダー
    private var headerView: some View {
        VStack(spacing: 10) {
            Text("JourneyMoments")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Button(action: onCreateProject) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("新しいプロジェクト")
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
            
            Text("プロジェクトがありません")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("新しいプロジェクトを作成して\n1秒動画を撮影しましょう！")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // プロジェクト一覧（美しいデザイン版）
    private var projectListView: some View {
        List {
            ForEach(projects) { project in
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
                                Text("\(project.segmentCount)秒")
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
                        Button(action: { onOpenProject(project) }) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                Text("撮影")
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
                            Button(action: { onPlayProject(project) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.caption)
                                    Text("再生")
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
                .background(Color(.systemGray6).opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing) {
                    Button("削除") {
                        print("🔍 削除対象: \(project.name)")
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

    // formatDate関数を追加（ProjectListViewの中に）
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}  // 🔧 ProjectListView の正しい終了位置

// MARK: - ProjectRowView
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
                        Text("\(project.segmentCount)秒")
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
                        Text("撮影")
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
                            Text("再生")
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
            Project(name: "東京旅行", segments: [
                VideoSegment(uri: "sample1", facing: "back", order: 1)
            ])
        ]
        
        ProjectListView(
            projects: sampleProjects,
            onCreateProject: {},
            onOpenProject: { _ in },
            onPlayProject: { _ in },
            onDeleteProject: { _ in }
        )
    }
}
