# 🐾 Dog Health Tracker — iOS App

> AI-powered dog digestive health analysis via poop image recognition. Built with SwiftUI, Clean Architecture, and OpenAI Vision API.

---

## 📐 Architecture Overview

This project follows **Clean Architecture** with a strict **unidirectional dependency rule**:

```
Presentation Layer  →  Domain Layer  ←  Data Layer
```

No layer can depend on one above it. The **domain layer** is the pure business core — it has zero framework imports.

---

## 🗂 Project Structure

```
DogHealthTracker/
├── App/
│   ├── DogHealthTrackerApp.swift       # @main entry point
│   └── AppCoordinator.swift            # Root navigation (TabView)
│
├── Core/
│   ├── DI/
│   │   └── AppDIContainer.swift        # Composition root — all dependencies wired here
│   ├── Network/
│   │   └── NetworkClient.swift         # Protocol-driven HTTP client
│   ├── Utils/
│   │   └── BaseViewModel.swift         # Shared ViewModel state + perform() helper
│   └── Extensions/
│       └── UIImage+Extensions.swift    # Image compression utilities
│
├── Domain/                             # ⭐️ Pure Swift — NO framework imports
│   ├── Entities/
│   │   └── DomainEntities.swift        # All core business models
│   ├── Repositories/
│   │   └── RepositoryProtocols.swift   # Repository contracts (interfaces)
│   └── UseCases/
│       └── UseCases.swift              # Business logic orchestration
│
├── Data/                               # Implements Domain protocols
│   ├── DataSources/
│   │   ├── Remote/
│   │   │   └── OpenAIDataSource.swift  # OpenAI Vision API integration
│   │   └── Local/
│   │       └── LocalDataSources.swift  # File-based JSON persistence
│   ├── DTOs/
│   │   └── OpenAIDTOs.swift            # API request/response models
│   ├── Mappers/
│   │   └── AnalysisMapper.swift        # DTO → Domain entity conversions
│   └── Repositories/
│       └── ConcreteRepositories.swift  # Repository implementations
│
├── Features/                           # Feature-sliced UI modules
│   ├── Home/
│   │   ├── Views/HomeView.swift
│   │   └── ViewModels/HomeViewModel.swift
│   ├── Analysis/
│   │   ├── Views/AnalysisResultView.swift
│   │   └── ViewModels/AnalysisResultViewModel.swift
│   ├── History/
│   │   ├── Views/OtherViews.swift
│   │   └── ViewModels/OtherViewModels.swift
│   ├── DogProfile/
│   └── Settings/
│
├── DesignSystem/
│   ├── Theme/AppTheme.swift            # Color, Typography, Spacing tokens
│   └── Components/UIComponents.swift   # Reusable UI building blocks
│
└── Services/
    └── Camera/CameraView.swift         # UIImagePickerController wrapper
```

---

## 🏛 Architecture Patterns

### Clean Architecture (3 Layers)

| Layer        | Responsibility                                    | Dependencies         |
|--------------|---------------------------------------------------|----------------------|
| Domain       | Business rules, entities, use case contracts      | None (pure Swift)    |
| Data         | Network calls, local persistence, mappers         | Domain protocols     |
| Presentation | UI, ViewModels, navigation                        | Domain use cases     |

### MVVM + Use Cases

```
View  →  ViewModel  →  UseCase  →  Repository (protocol)
                                         ↓
                                   DataSource (remote/local)
```

### Dependency Injection (Constructor Injection)

All dependencies are injected via constructors — never resolved via singletons inside classes.  
The `AppDIContainer` (composition root) assembles the entire dependency graph at startup.

```swift
// ✅ Correct — dependencies injected
final class PoopAnalysisRepository {
    init(remoteDataSource: OpenAIDataSourceProtocol,
         localDataSource: AnalysisLocalDataSourceProtocol, ...) { }
}

// ❌ Wrong — static dependency
let repo = PoopAnalysisRepository(remote: OpenAIDataSource())  // hardcoded
```

---

## ✅ SOLID Principles Applied

| Principle | Application |
|-----------|-------------|
| **S** — Single Responsibility | Each class has one job: `AnalysisMapper` only maps, `PromptBuilder` only builds prompts |
| **O** — Open/Closed | Add new data sources by creating a new `OpenAIDataSourceProtocol` conformance, never modifying existing code |
| **L** — Liskov Substitution | All protocol implementations are interchangeable (e.g., mock vs real data source) |
| **I** — Interface Segregation | Repositories split into focused protocols (`PoopAnalysisRepositoryProtocol`, `DogProfileRepositoryProtocol`) |
| **D** — Dependency Inversion | ViewModels depend on `UseCaseProtocol`, not concrete use cases |

---

## 🤖 AI Integration (OpenAI Vision)

### Flow
```
UIImage  →  base64 JPEG  →  OpenAI GPT-4o Vision  →  JSON Response  →  Domain Entity
```

### Key Design Decisions

1. **Structured JSON output** — System prompt enforces a strict schema, making parsing deterministic
2. **Prompt engineering in `AnalysisPromptBuilder`** — Separated from networking code; easy to A/B test prompts
3. **Dog context injection** — Dog profile data enriches prompts for more accurate, personalized analysis
4. **Image compression pipeline** — Auto-quality reduction to stay under API limits while preserving analysis quality

---

## 📱 Features

### Current (v1.0)
- [x] Poop image capture via camera or photo library
- [x] AI-powered health analysis (detection, color, consistency, shape, size)
- [x] Overall health score (0–100) with tier rating
- [x] Blood, mucus, parasite, undigested food detection
- [x] Prioritized health recommendations with action steps
- [x] Analysis history with filtering and pagination
- [x] Dog profile for contextual AI analysis
- [x] Settings with API key management

### Roadmap (Easily Extensible)
- [ ] **Multi-dog support** — `DogProfileRepository.fetchAllDogProfiles()` is already implemented
- [ ] **Trend analytics** — Add `HealthTrendUseCase` consuming existing history data
- [ ] **Export (PDF/CSV)** — `ExportFormat` enum and setting already defined
- [ ] **Notifications** — `notificationsEnabled` setting and `reminderIntervalHours` ready
- [ ] **CloudKit sync** — Swap `CoreDataStorageService` for `CloudKitStorageService`
- [ ] **HealthKit integration** — Plug in as a new data source
- [ ] **Offline queue** — Add a pending-analysis queue in `PoopAnalysisRepository`
- [ ] **SwiftData migration** — Replace JSON storage with `@Model` entities

---

## 🧪 Testing Strategy

The protocol-driven architecture makes every layer independently testable:

```swift
// Unit test example — zero network calls needed
func testAnalyzePoopUseCase_withSmallImage_throwsImageTooSmall() async throws {
    let mockRepo = MockPoopAnalysisRepository()
    let sut = AnalyzePoopUseCase(repository: mockRepo)
    let tinyImage = UIImage(systemName: "photo")!
    
    await XCTAssertThrowsError(
        try await sut.execute(image: tinyImage, dogProfile: nil)
    ) { error in
        XCTAssertEqual(error as? DomainError, .imageTooSmall)
    }
}
```

---

## 🔧 Setup

1. Clone the repository
2. Open `DogHealthTracker.xcodeproj` in Xcode 15+
3. Set your iOS development team in project settings
4. Build and run on a device or simulator
5. Add your OpenAI API key in **Settings** tab (requires a key with GPT-4o access)

### Required Permissions (Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>Used to capture photos for health analysis</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to select existing photos for analysis</string>
```

---

## 🏗 Scalability Notes

This codebase is built to grow. Key expansion points:

- **New AI providers** → Implement `OpenAIDataSourceProtocol` with any LLM provider
- **New analysis types** → Add entity fields; update `AnalysisMapper` and `PromptBuilder`
- **Backend sync** → Replace `AnalysisLocalDataSource` with a hybrid remote/local implementation
- **New features** → Add a `Features/NewFeature/` folder with its own ViewModel + View
- **New screens** → Register new `make*ViewModel()` factory in `AppDIContainer`

---

*Built to demonstrate Clean Architecture + SOLID principles + AI integration in Swift/SwiftUI.*
