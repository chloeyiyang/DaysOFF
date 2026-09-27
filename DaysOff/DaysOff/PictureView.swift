//
//  PictureView.swift
//  DaysOff
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Picture Module Color Extensions
// 注：非 fileprivate —— burgundy / pictureTextDark 也被 GalleryView.swift 使用
extension Color {
    static let pictureIcyBlue1 = Color(red: 0.85, green: 0.92, blue: 0.98)
    static let pictureIcyBlue2 = Color(red: 0.78, green: 0.88, blue: 0.96)
    static let pictureIcyBlue3 = Color(red: 0.70, green: 0.84, blue: 0.94)
    static let pictureTextDark = Color(red: 0.25, green: 0.35, blue: 0.45)
    static let pictureButtonBlue = Color(red: 0.35, green: 0.60, blue: 0.85)
    static let pictureConfirmGreen = Color(red: 0.35, green: 0.70, blue: 0.45)
    static let pictureCancelRed = Color(red: 0.75, green: 0.35, blue: 0.35)
    static let pictureNavy = Color(red: 0.10, green: 0.20, blue: 0.40)
    static let burgundy = Color(red: 0.50, green: 0.07, blue: 0.20)
}

// MARK: - Picture Module Types
struct PicturePainting: Identifiable {
    let id: UUID
    let image: Image
    let data: Data
    let date: String
    var blessing: String
    var isPublic: Bool

    init(id: UUID = UUID(), image: Image, data: Data, date: String, blessing: String, isPublic: Bool) {
        self.id = id
        self.image = image
        self.data = data
        self.date = date
        self.blessing = blessing
        self.isPublic = isPublic
    }
}

struct TypeSection: Identifiable {
    let id: UUID
    var type: String?  // nil = not yet selected
    var pictures: [PicturePainting]

    init(id: UUID = UUID(), type: String?, pictures: [PicturePainting]) {
        self.id = id
        self.type = type
        self.pictures = pictures
    }
}

let artworkTypes = ["绘画", "书法", "手工", "陶艺", "厨艺", "园艺", "其他"]

// MARK: - Saved picture section persistence (Codable, UserDefaults-backed)
private let kSavedArtworkSectionsKeyPrefix = "gallery_saved_artwork_sections_"

private func savedSectionsKey(userId: String) -> String {
    kSavedArtworkSectionsKeyPrefix + userId
}

private let kExhibitedCountsKeyPrefix = "gallery_exhibited_counts_"
private func exhibitedCountsKey(userId: String) -> String {
    kExhibitedCountsKeyPrefix + userId
}

struct SavedArtworkEntry: Codable, Identifiable {
    let id: UUID          // matches PicturePainting id
    let data: Data
    let date: String
    var blessing: String
    var isPublic: Bool
}

struct SavedSectionEntry: Codable, Identifiable {
    let id: UUID          // matches TypeSection id
    var type: String?
    var artworks: [SavedArtworkEntry]
}

struct PictureCurvyCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.35
        
        path.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        
        let offset1 = CGPoint(x: radius * 0.25, y: -radius * 0.1)
        path.addArc(center: CGPoint(x: center.x + offset1.x, y: center.y + offset1.y), radius: radius * 0.7, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        
        let offset2 = CGPoint(x: -radius * 0.2, y: radius * 0.15)
        path.addArc(center: CGPoint(x: center.x + offset2.x, y: center.y + offset2.y), radius: radius * 0.5, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        
        return path
    }
}

// MARK: - Image Validation Helpers
fileprivate extension Data {
    var isImageFormatValid: Bool {
        guard count >= 12 else { return false }
        let bytes = [UInt8](prefix(12))
        // JPEG
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF { return true }
        // PNG
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 { return true }
        // GIF
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 { return true }
        // HEIC / HEIF — ftyp box at offset 4
        if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 {
            let brand = String(bytes: bytes[8...11], encoding: .ascii) ?? ""
            return ["heic", "heix", "hevc", "hevx", "mif1", "mif2", "msf1"].contains(brand)
        }
        return false
    }
}

// MARK: - MuseumWallBackground
struct MuseumWallBackground: View {
    var body: some View {
        ZStack {
            baseWallGradient
            
            WallTextureView()
            
            topLightingGradient
            
            sideShadowsGradient
            
            bottomShadowGradient
        }
        .ignoresSafeArea()
    }
    
    private var baseWallGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.91, blue: 0.87),
                Color(red: 0.88, green: 0.86, blue: 0.82),
                Color(red: 0.83, green: 0.81, blue: 0.77)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var topLightingGradient: some View {
        GeometryReader { geo in
            RadialGradient(
                colors: [
                    Color.white.opacity(0.25),
                    Color.white.opacity(0.05),
                    Color.white.opacity(0)
                ],
                center: UnitPoint(x: 0.5, y: -0.2),
                startRadius: geo.size.width * 0.1,
                endRadius: geo.size.width * 0.8
            )
        }
    }
    
    private var sideShadowsGradient: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.12),
                Color.black.opacity(0),
                Color.black.opacity(0),
                Color.black.opacity(0.12)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var bottomShadowGradient: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0),
                Color.black.opacity(0),
                Color.black.opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct WallTextureView: View {
    private func darkGrainOffset(index: Int) -> CGPoint {
        let x = sin(Double(index * 73) * 0.1) * 0.5 + 0.5
        let y = cos(Double(index * 117) * 0.1) * 0.5 + 0.5
        return CGPoint(x: x, y: y)
    }
    
    private func darkGrainSize(index: Int) -> CGFloat {
        return CGFloat(sin(Double(index * 31) * 0.1) * 0.5 + 1) * 1.2
    }
    
    private func lightGrainOffset(index: Int) -> CGPoint {
        let x = sin(Double(index * 57 + 10) * 0.1) * 0.5 + 0.5
        let y = cos(Double(index * 133 + 20) * 0.1) * 0.5 + 0.5
        return CGPoint(x: x, y: y)
    }
    
    private func lightGrainSize(index: Int) -> CGFloat {
        return CGFloat(sin(Double(index * 29) * 0.1) * 0.5 + 0.8) * 1.0
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<100, id: \.self) { i in
                    let offset = darkGrainOffset(index: i)
                    let size = darkGrainSize(index: i)
                    Circle()
                        .fill(Color.black.opacity(0.03))
                        .frame(width: size, height: size)
                        .position(x: offset.x * geo.size.width, y: offset.y * geo.size.height)
                }
                
                ForEach(0..<80, id: \.self) { i in
                    let offset = lightGrainOffset(index: i)
                    let size = lightGrainSize(index: i)
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: size, height: size)
                        .position(x: offset.x * geo.size.width, y: offset.y * geo.size.height)
                }
            }
        }
    }
}


// MARK: - Section frame preference key (for drag-and-drop targeting)
struct SectionFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - 和纸编织背景：灰竖条填满 + 粉横条双色逐行交替
private struct WovenPaperBackground: View {
    var stripeWidth: CGFloat = 32
    private let blushPink  = Color(red: 242/255, green: 216/255, blue: 205/255).opacity(0.38)
    private let grayishPink = Color(red: 228/255, green: 215/255, blue: 210/255).opacity(0.32)
    private let lightGray  = Color(red: 210/255, green: 208/255, blue: 205/255).opacity(0.28)
    private let lightGray2 = Color(red: 220/255, green: 217/255, blue: 214/255).opacity(0.20)

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                let sw = stripeWidth

                // 1. 垂直灰条：填满整宽（无间隙）
                //    偶数列：原灰色（"有灰条纹"位置）
                //    奇数列：稍淡灰色（"无灰条纹"位置，仍然用灰色填满）
                var col = 0
                var x: CGFloat = 0
                while x < w {
                    let isGrayStripeCol = col % 2 == 0
                    ctx.fill(
                        Path(CGRect(x: x, y: 0, width: sw, height: h)),
                        with: .color(isGrayStripeCol ? lightGray : lightGray2)
                    )
                    col += 1
                    x = CGFloat(col) * sw
                }

                // 2. 水平横条：双色逐行交替反转
                //    偶数行：有灰条纹列 → 灰粉色，无灰条纹列 → 胭脂粉
                //    奇数行：有灰条纹列 → 胭脂粉，无灰条纹列 → 灰粉色
                var row = 0
                var y: CGFloat = 0
                while y < h {
                    var c = 0
                    var vx: CGFloat = 0
                    while vx < w {
                        let isGrayStripeCol = c % 2 == 0
                        let useGrayishPink: Bool
                        if row % 2 == 0 {
                            useGrayishPink = isGrayStripeCol
                        } else {
                            useGrayishPink = !isGrayStripeCol
                        }

                        ctx.fill(
                            Path(CGRect(x: vx, y: y, width: sw, height: sw)),
                            with: .color(useGrayishPink ? grayishPink : blushPink)
                        )
                        c += 1
                        vx = CGFloat(c) * sw
                    }
                    row += 1
                    y = CGFloat(row) * sw
                }
            }
        }
    }
}

// MARK: - PictureView
struct PictureView: View {
    var username: String = ""
    var userId: String = ""
    @StateObject private var exhibitionStore = ExhibitionStore.shared
    @State private var showUploadConfirm = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var sections: [TypeSection] = []
    @State private var floatingPicture: PicturePainting? = nil
    @State private var sectionFrames: [Int: CGRect] = [:]
    @State private var selectedPainting: PicturePainting?
    @State private var errorMessage = ""
    @State private var saveMessage = ""
    @State private var typePulse: Bool = false   // "请选择类型" 闪烁循环状态
    @GestureState private var dragTranslation: CGSize = .zero
    var onExhibitionConfirmed: ((String) -> Void)? = nil

    private var paintings: [PicturePainting] {
        sections.flatMap { $0.pictures }
    }
    
    // Exhibition flow state
    @State private var showExhibitionSelection = false
    @State private var exhibitionSelectedIds: Set<UUID> = []
    @State private var navigateToGallery = false
    @State private var exhibitionPaintingIds: Set<UUID> = []
    @AppStorage("gallery_draft_painting_ids") private var draftPaintingIdsData: Data = Data()
    @State private var exhibitedCounts: [String: Int] = [:]
    @State private var deleteConfirmPainting: PicturePainting? = nil

    private var draftPaintingIds: Set<UUID> {
        if let ids = try? JSONDecoder().decode([UUID].self, from: draftPaintingIdsData) {
            return Set(ids)
        }
        return []
    }

    private func saveDraftPaintingIds(_ ids: Set<UUID>) {
        if let data = try? JSONEncoder().encode(Array(ids)) {
            draftPaintingIdsData = data
        }
    }

    private func clearDraftPaintingIds() {
        draftPaintingIdsData = Data()
    }

    private func loadExhibitedCounts() {
        exhibitedCounts = [:]
        let key = exhibitedCountsKey(userId: userId)
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            exhibitedCounts = [:]
            return
        }
        exhibitedCounts = decoded
    }

    private func saveExhibitedCounts() {
        let key = exhibitedCountsKey(userId: userId)
        if let encoded = try? JSONEncoder().encode(exhibitedCounts) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func exhibitedCount(for paintingId: UUID) -> Int {
        exhibitedCounts[paintingId.uuidString] ?? 0
    }

    private func incrementExhibitedCount(for paintingId: UUID) {
        exhibitedCounts[paintingId.uuidString] = exhibitedCount(for: paintingId) + 1
        saveExhibitedCounts()
    }
    
    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private var selectedExhibitionPaintings: [PicturePainting] {
        paintings.filter { exhibitionSelectedIds.contains($0.id) }
    }
    
    var body: some View {
        GeometryReader { contentGeo in
            ZStack {
                // =============== 背景层：纯白底 + 胭脂粉/浅灰和纸编织 ===============
                Color.white
                    .ignoresSafeArea()

                WovenPaperBackground()
                    .ignoresSafeArea()

                // =============== 内容层：所有 UI 元素，居中对齐 ===============
                VStack(spacing: 16) {
                    headerView

                    if !paintings.isEmpty || floatingPicture != nil {
                        paintingsGrid
                    }

                    Spacer()

                    actionButtonsView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .onChange(of: selectedPhoto) { _, newItem in
                    handlePhotoSelection(newItem)
                }

                if showUploadConfirm {
                    confirmDialog
                }

                if !errorMessage.isEmpty {
                    errorAlert
                }

                if selectedPainting != nil {
                    polaroidView
                }

                if showExhibitionSelection {
                    exhibitionSelectionOverlay
                }

                if deleteConfirmPainting != nil {
                    deleteConfirmDialog
                }

                // Floating picture (appears at center, user drags to place)
                if let floating = floatingPicture {
                    floating.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 2, y: 4)
                        .position(
                            x: contentGeo.size.width / 2 + dragTranslation.width,
                            y: contentGeo.size.height / 2 + dragTranslation.height
                        )
                        .gesture(
                            DragGesture(coordinateSpace: .named("contentArea"))
                                .updating($dragTranslation) { value, state, _ in
                                    state = value.translation
                                }
                                .onEnded { value in
                                    placeFloatingPicture(at: value.location)
                                }
                        )

                    // Hint text
                    Text(L("拖动图片到上方放置", "Drag image to place above"))
                        .font(.pingFang(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .position(x: contentGeo.size.width / 2, y: contentGeo.size.height / 2 + 120)
                }

            }
            .coordinateSpace(name: "contentArea")
            .navigationDestination(isPresented: $navigateToGallery) {
                GalleryContentView(
                    exhibitionPaintings: selectedExhibitionPaintings,
                    autoShowPrepare: true,
                    userId: userId,
                    userName: username,
                    onExhibitionConfirmed: { name in
                        exhibitionPaintingIds = exhibitionSelectedIds
                        clearDraftPaintingIds()
                        for pid in exhibitionSelectedIds {
                            incrementExhibitedCount(for: pid)
                        }
                        onExhibitionConfirmed?(name)
                    }
                )
            }
            .animation(.easeInOut(duration: 0.3), value: showUploadConfirm)
            .animation(.easeInOut(duration: 0.3), value: errorMessage.isEmpty)
            .animation(.easeInOut(duration: 0.3), value: selectedPainting != nil)
            .animation(.easeInOut(duration: 0.3), value: showExhibitionSelection)
            .animation(.easeInOut(duration: 0.3), value: deleteConfirmPainting != nil)
            .animation(.easeInOut(duration: 0.3), value: floatingPicture != nil)
            .animation(.easeInOut(duration: 0.3), value: saveMessage.isEmpty)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadSavedSections()
                loadExhibitedCounts()
                // 启动"请选择类型"闪烁循环（typePulse false↔true 无限循环）
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    typePulse.toggle()
                }
            }
            // 云同步审核拒绝（违规/格式）：复用页面 errorAlert 提示，并消费状态避免重复弹
            .onReceive(exhibitionStore.$showModerationAlert) { show in
                if show {
                    errorMessage = exhibitionStore.moderationMessage
                    exhibitionStore.showModerationAlert = false
                }
            }
            // Save-success banner — 放到安全区最顶端，不遮挡"作品"标题
            .overlay(alignment: .top) {
                if !saveMessage.isEmpty {
                    Text(saveMessage)
                        .font(.pingFang(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.45, green: 0.70, blue: 0.45))
                        .cornerRadius(8)
                        .offset(y: -20)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 4) {
            Text(L("\(username)的作品", "\(username)'s Works"))
                .font(.pingFang(size: 24, weight: .bold))
                .foregroundColor(Color(red: 218/255, green: 136/255, blue: 144/255))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 16)
    }
    
    private var paintingsGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .center, spacing: 20) {
                ForEach(sections.indices, id: \.self) { index in
                    sectionView(for: sections[index], at: index)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: SectionFrameKey.self,
                                    value: [index: geo.frame(in: .named("contentArea"))]
                                )
                            }
                        )
                }
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .onPreferenceChange(SectionFrameKey.self) { frames in
            sectionFrames = frames
        }
    }

    // MARK: - Section view (big rectangle box + type dropdown inside + 3-col grid inside)
    private func sectionView(for section: TypeSection, at index: Int) -> some View {
        VStack(alignment: .center, spacing: 12) {
            // Type dropdown — inside the box, above the picture grid
            typeDropdown(for: index, selectedType: section.type)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            // 3-column grid of pictures
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(section.pictures) { painting in
                    paintingThumbnail(painting)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .overlay(
            // 直角矩形描边，无圆角，四边等粗细均匀
            // strokeBorder 画在路径内侧，避免 ScrollView 裁剪右边缘
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(Color(red: 146/255, green: 28/255, blue: 56/255).opacity(0.45), lineWidth: 1.0)
        )
    }

    // MARK: - Type dropdown
    private func typeDropdown(for index: Int, selectedType: String?) -> some View {
        Menu {
            ForEach(artworkTypes, id: \.self) { type in
                Button(A(type)) {
                    sections[index].type = type
                    saveSections()   // 选完类型后自动保存
                }
            }
            if selectedType != nil {
                Divider()
                Button(L("清除选择", "Clear Selection"), role: .destructive) {
                    sections[index].type = nil
                    saveSections()   // 清除后也自动保存
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedType.map { A($0) } ?? L("请选择类型", "Select Type"))
                    .font(.pingFang(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(selectedType == nil ? .gray : .pictureTextDark)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.85))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.burgundy.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            // 闪烁提醒：未选类型时 opacity 在 0.4 ↔ 1.0 间循环
            .opacity(selectedType == nil ? (typePulse ? 0.4 : 1.0) : 1.0)
        }
    }

    // MARK: - Painting thumbnail
    private func paintingThumbnail(_ painting: PicturePainting) -> some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack(alignment: .topTrailing) {
                // 图片本体：点击放大，用 contentShape 精确限定命中区域
                painting.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
                    .clipped()
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 3)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedPainting = painting }

                // Delete X for non-exhibition, non-draft pictures
                if !exhibitionPaintingIds.contains(painting.id) && !draftPaintingIds.contains(painting.id) {
                    Button(action: { deleteConfirmPainting = painting }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                    .padding(4)
                }

                // Star(s) for exhibited count — bottom right
                let exhibitedCount = self.exhibitedCount(for: painting.id)
                if exhibitedCount > 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(0..<min(exhibitedCount, 5), id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                }
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.9))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.orange.opacity(0.5), lineWidth: 0.5)
                                    )
                            )
                            .padding(4)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 10) {
            Button(action: {
                showUploadConfirm = true
            }) {
                Text(L("点击上传", "Tap to Upload"))
                    .font(.pingFang(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 140, height: 38)
                    .background(Color.burgundy)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
            }

            Button(action: {
                exhibitionSelectedIds = []
                showExhibitionSelection = true
            }) {
                Text(L("开设展览", "Open Exhibition"))
                    .font(.pingFang(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 140, height: 38)
                    .background(
                        paintings.count >= 10
                            ? Color.burgundy
                            : Color.gray.opacity(0.5)
                    )
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
            }
            .disabled(paintings.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 24)
    }
    
    private var polaroidView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { selectedPainting = nil }
            
            if let painting = selectedPainting {
                VStack(spacing: 0) {
                    painting.image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320, maxHeight: 320)
                    
                    HStack {
                        Spacer()
                        Text(painting.blessing)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.pictureTextDark)
                        Spacer()
                        Text(painting.date)
                            .font(.system(size: 11))
                            .foregroundColor(.pictureTextDark.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(2)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 4, y: 6)
            }
        }
    }
    
    private var confirmDialog: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { showUploadConfirm = false }

            VStack(spacing: 20) {
                Text(L("请确认这是您的原创作品", "This is your original work"))
                    .font(.pingFang(size: 18, weight: .medium))
                    .foregroundColor(.pictureTextDark)
                    .multilineTextAlignment(.center)

                // 单个对勾按钮：点击触发 PhotosPicker 选照片继续流程
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.pictureConfirmGreen)
                }
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        }
    }
    
    private var errorAlert: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { errorMessage = "" }
            
            VStack(spacing: 16) {
                Text(errorMessage)
                    .font(.system(size: 16))
                    .foregroundColor(.pictureTextDark)
                
                Button(action: { errorMessage = "" }) {
                    Text(L("确定", "Confirm"))
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(Color.pictureButtonBlue)
                        .cornerRadius(8)
                }
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        }
    }
    
    // MARK: - Exhibition Flow
    private var exhibitionSelectionOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                HStack {
                    Text(L("选择10幅作品开设画展", "Select 10 artworks to open an exhibition"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(L("已选 \(exhibitionSelectedIds.count)/10", "Selected \(exhibitionSelectedIds.count)/10"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(paintings) { painting in
                            let isSelected = exhibitionSelectedIds.contains(painting.id)
                            Button(action: {
                                if isSelected {
                                    exhibitionSelectedIds.remove(painting.id)
                                } else if exhibitionSelectedIds.count < 10 {
                                    exhibitionSelectedIds.insert(painting.id)
                                }
                            }) {
                                ZStack {
                                    painting.image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minHeight: 100, maxHeight: 140)
                                        .clipped()
                                        .cornerRadius(8)
                                        .opacity(isSelected ? 0.7 : 1.0)
                                    
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(red: 0.45, green: 0.95, blue: 0.65), lineWidth: 3)
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color(red: 0.45, green: 0.95, blue: 0.65))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: 400)
                
                HStack(spacing: 16) {
                    Button(action: {
                        showExhibitionSelection = false
                        exhibitionSelectedIds = []
                    }) {
                        Text(L("取消", "Cancel"))
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.6))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        if exhibitionSelectedIds.count < 10 {
                            errorMessage = "请选择十张作品，点击确定"
                        } else {
                            saveDraftPaintingIds(exhibitionSelectedIds)
                            showExhibitionSelection = false
                            navigateToGallery = true
                        }
                    }) {
                        Text(L("确定", "Confirm"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(exhibitionSelectedIds.count == 10 ? Color.pictureButtonBlue : Color.gray.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Delete Flow
    private var deleteConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { deleteConfirmPainting = nil }

            VStack(spacing: 16) {
                Text(L("确认删除这幅作品？", "Delete this artwork?"))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.pictureTextDark)

                HStack(spacing: 24) {
                    Button(action: { deleteConfirmPainting = nil }) {
                        Text(L("取消", "Cancel"))
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.6))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        if let painting = deleteConfirmPainting {
                            removePainting(painting)
                        }
                        deleteConfirmPainting = nil
                    }) {
                        Text(L("删除", "Delete"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Color.pictureCancelRed)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(28)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        showUploadConfirm = false

        Task {
            if var data = try? await item.loadTransferable(type: Data.self) {
                let sizeLimit = 5 * 1024 * 1024

                // 超过5MB时自动压缩画质，直到小于5MB
                if data.count > sizeLimit {
                    #if canImport(UIKit)
                    if let uiImage = UIImage(data: data) {
                        var quality: CGFloat = 0.9
                        while quality > 0.1 {
                            if let compressed = uiImage.jpegData(compressionQuality: quality),
                               compressed.count < sizeLimit {
                                data = compressed
                                break
                            }
                            quality -= 0.1
                        }
                        // 如果调质量仍压缩不到5MB以下，缩放图片尺寸再压缩
                        if data.count > sizeLimit {
                            let scaled = resizeImage(uiImage, maxDimension: 2000)
                            if let compressed = scaled.jpegData(compressionQuality: 0.7),
                               compressed.count < sizeLimit {
                                data = compressed
                            }
                        }
                    }
                    #endif
                }

                // 压缩后仍超过5MB才拒绝
                if data.count > sizeLimit {
                    await MainActor.run {
                        errorMessage = L("您上传的图片过大，请调整后重新上传", "The size of the picture exceeds limit, please adjust and upload again")
                        selectedPhoto = nil
                    }
                    return
                }

                if !data.isImageFormatValid {
                    await MainActor.run {
                        errorMessage = "不支持的图片格式，请上传JPEG、PNG、HEIC或GIF格式的图片"
                        selectedPhoto = nil
                    }
                    return
                }

                #if canImport(UIKit)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        floatingPicture = PicturePainting(
                            image: Image(uiImage: uiImage),
                            data: data,
                            date: currentDate,
                            blessing: "",
                            isPublic: false
                        )
                        saveUserPictureData(data)
                        selectedPhoto = nil
                    }
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: data) {
                    await MainActor.run {
                        floatingPicture = PicturePainting(
                            image: Image(nsImage: nsImage),
                            data: data,
                            date: currentDate,
                            blessing: "",
                            isPublic: false
                        )
                        saveUserPictureData(data)
                        selectedPhoto = nil
                    }
                }
                #endif
            }
        }
    }

    // MARK: - Drag-and-drop placement logic
    private func placeFloatingPicture(at point: CGPoint) {
        guard let floating = floatingPicture else { return }

        let sortedFrames = sectionFrames.sorted { $0.key < $1.key }

        // 1. If drop point is inside any section box → append to that section
        for (index, frame) in sortedFrames {
            if point.y >= frame.minY && point.y <= frame.maxY {
                sections[index].pictures.append(floating)
                floatingPicture = nil
                saveSections()   // 拖入图片后自动保存
                return
            }
        }

        // 2. Otherwise find the section whose bottom edge is closest above the drop
        //    point, and insert a new section right below it (i.e. at its index + 1).
        //    This lets users drop below the first box, between two boxes, or
        //    below the last box — each case produces a new section correctly placed.
        var bestIndex: Int = -1
        var bestMaxY: CGFloat = -CGFloat.greatestFiniteMagnitude
        for (index, frame) in sortedFrames {
            if frame.maxY < point.y && frame.maxY > bestMaxY {
                bestMaxY = frame.maxY
                bestIndex = index
            }
        }

        let newSection = TypeSection(type: nil, pictures: [floating])
        if bestIndex >= 0 && bestIndex + 1 <= sections.count {
            sections.insert(newSection, at: bestIndex + 1)
        } else {
            // No section above the drop (point is above all boxes); still put at top.
            if sections.isEmpty {
                sections.append(newSection)
            } else {
                sections.insert(newSection, at: 0)
            }
        }
        floatingPicture = nil
        saveSections()   // 新建 section 后自动保存
    }

    // MARK: - Remove painting from sections
    private func removePainting(_ painting: PicturePainting) {
        for i in sections.indices {
            if let j = sections[i].pictures.firstIndex(where: { $0.id == painting.id }) {
                sections[i].pictures.remove(at: j)
                if sections[i].pictures.isEmpty {
                    sections.remove(at: i)
                }
                break
            }
        }
        exhibitionSelectedIds.remove(painting.id)
        saveSections()   // 删除后立即持久化，防止退出再进入时被删作品复活
    }

    // MARK: - Save sections (pictures + type selections) to UserDefaults
    private func saveSections() {
        let saved = sections.map { section -> SavedSectionEntry in
            SavedSectionEntry(
                id: section.id,
                type: section.type,
                artworks: section.pictures.map { painting in
                    SavedArtworkEntry(
                        id: painting.id,
                        data: painting.data,
                        date: painting.date,
                        blessing: painting.blessing,
                        isPublic: painting.isPublic
                    )
                }
            )
        }

        guard let data = try? JSONEncoder().encode(saved) else {
            saveMessage = L("保存失败，请重试", "Save failed, please retry")
            scheduleClearSaveMessage()
            return
        }
        UserDefaults.standard.set(data, forKey: savedSectionsKey(userId: userId))
        UserSyncStore.shared.pushWorks(userId: userId)

        let total = sections.reduce(0) { $0 + $1.pictures.count }
        let typesCount = sections.filter { $0.type != nil }.count
        let isEn = L("zh", "en") == "en"
        let picWord = total == 1 ? "Picture" : "Pictures"
        let catWord = typesCount == 1 ? "Category" : "Categories"
        if typesCount == sections.count && !sections.isEmpty {
            saveMessage = isEn
                ? "Saved \(total) \(picWord), \(typesCount) \(catWord)"
                : "已保存 \(total) 张作品，\(typesCount) 个分类"
        } else {
            saveMessage = isEn
                ? "Saved \(total) \(picWord)"
                : "已保存 \(total) 张作品"
        }
        scheduleClearSaveMessage()
    }

    // MARK: - Load saved sections on appear (only when nothing is in memory yet)
    private func loadSavedSections() {
        guard sections.isEmpty else { return }
        let key = savedSectionsKey(userId: userId)
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([SavedSectionEntry].self, from: data) else { return }

        sections = saved.compactMap { entry in
            let pictures: [PicturePainting] = entry.artworks.compactMap { artwork in
                guard let image = pictureCreateImage(from: artwork.data) else { return nil }
                return PicturePainting(
                    id: artwork.id,
                    image: image,
                    data: artwork.data,
                    date: artwork.date,
                    blessing: artwork.blessing,
                    isPublic: artwork.isPublic
                )
            }
            guard !pictures.isEmpty else { return nil }
            return TypeSection(id: entry.id, type: entry.type, pictures: pictures)
        }
    }

    private func scheduleClearSaveMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                saveMessage = ""
            }
        }
    }
}

private func pictureCreateImage(from data: Data) -> Image? {
    #if canImport(UIKit)
    if let uiImage = UIImage(data: data) {
        return Image(uiImage: uiImage)
    }
    #elseif canImport(AppKit)
    if let nsImage = NSImage(data: data) {
        return Image(nsImage: nsImage)
    }
    #endif
    return nil
}

#if canImport(UIKit)
/// 缩放图片到指定最大边长（保持宽高比）
private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    let maxSide = max(size.width, size.height)
    guard maxSide > maxDimension else { return image }
    let scale = maxDimension / maxSide
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}
#endif

