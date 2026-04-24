import SwiftUI
import Kingfisher

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [VideoModel] = []
    @State private var categories: [NewCategoryItem] = []
    @State private var isLoading = false
    @State private var selectedCategory: String?
    @State private var selectedType: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search movies, series...", text: $searchText)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; searchResults = [] }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding()
                
                ScrollView {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if searchResults.isEmpty {
                        VStack(spacing: 16) {
                            if !categories.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                                            selectedCategory = nil
                                            performSearch()
                                        }
                                        ForEach(categories) { category in
                                            CategoryChip(
                                                title: category.name ?? category.nameEn ?? "",
                                                isSelected: selectedCategory == category.nb
                                            ) {
                                                selectedCategory = category.nb
                                                performSearch()
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            Text("Search for movies and series")
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 50)
                    } else {
                        LazyVStack {
                            ForEach(searchResults) { video in
                                NavigationLink(destination: VideoDetailView(video: video)) {
                                    SearchResultRow(video: video)
                                }
                            }
                        }
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await loadCategories()
            }
        }
    }
    
    private func loadCategories() async {
        do {
            categories = try await APIService.shared.getCategories()
        } catch {
            print("Error loading categories: \(error)")
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        Task {
            await MainActor.run { isLoading = true }
            
            do {
                let results = try await APIService.shared.searchVideos(
                    query: searchText,
                    categoryId: selectedCategory
                )
                await MainActor.run {
                    searchResults = results
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.red : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(20)
        }
    }
}

struct SearchResultRow: View {
    let video: VideoModel
    
    var body: some View {
        HStack(spacing: 12) {
            KFImage(URL(string: video.thumbnailUrl ?? ""))
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 80, height: 120)
                .cornerRadius(8)
                .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    if let year = video.year {
                        Text(year)
                    }
                    if let kind = video.kind {
                        Text("•")
                        Text(kind)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.gray)
                
                if let rate = video.rate {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(rate)
                    }
                    .font(.caption)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
    }
}

#Preview {
    SearchView()
        .preferredColorScheme(.dark)
}