# Sar-E: Sari-Sari Store Management System

## 📌 Project Overview

**Sar-E** is a comprehensive, mobile-first retail management system engineered specifically for traditional micro-retail enterprises (Sari-Sari stores) in the Philippines. The application aims to digitize and streamline point-of-sale (POS) operations, inventory tracking, and micro-credit management (locally known as "Listahan").

Designed to operate in low-connectivity environments, Sar-E employs an **Offline-First Architecture**. It guarantees zero downtime by performing all immediate read/write operations against a localized SQLite database, while an asynchronous background synchronization queue ensures eventual consistency with Firebase Cloud Firestore.

---

## 🏗️ System Architecture

The project strictly adheres to **Domain-Driven Design (DDD)** and **Clean Architecture** principles to ensure high cohesion, low coupling, and scalable maintainability.

### Architectural Layers
*   **Domain Layer (`lib/domain/`):** Contains pure business logic and entity models (e.g., `Product`, `Transaction`, `CreditEntry`). It holds no dependencies on external frameworks.
*   **Data Layer (`lib/data/`):** Implements the repository pattern. It is sub-divided into:
    *   **Local (`data/local/`):** Contains Data Access Objects (DAOs) interfacing with the 16-table SQLite relational database (`sqflite`).
    *   **Sync (`data/sync/`):** Manages the asynchronous operation queue, conflict resolution, and pushes data payloads to Firebase.
*   **Application Layer (`lib/application/`):** Acts as the bridge between Domain and UI. Utilizes `flutter_riverpod` for robust, reactive state management and dependency injection.
*   **Presentation Layer (`lib/screens/` & `lib/widgets/`):** The Flutter UI views. Designed with Material Design 3 guidelines for an intuitive, accessible user experience.

---

## 🚀 Core Modules & Features

### 1. Hybrid Point of Sale (POS)
*   **Dynamic Cart Management:** Optimized for high-throughput transactions.
*   **Multi-Modal Payment Gateway:** Supports traditional Cash transactions with algorithmic change computation, alongside integrated E-Wallet (GCash, Maya) processing via dynamic QR code generation (`qr_flutter`).

### 2. Inventory Management System
*   **Real-time Stock Tracking:** Implements deterministic decrementing upon successful transactions.
*   **Low-Stock Heuristics:** Automated threshold alerts for inventory replenishment.
*   **Dynamic Pricing Engine:** Supports algorithmic adjustments and multi-tier pricing ingestion.

### 3. Digital "Listahan" (Credit Ledger)
*   **Debt Tracking:** Comprehensive tracking of customer liabilities and installment-based repayments.
*   **Automated Lifecycle Management:** Background tasks proactively flag entries as `overdue` based on temporal evaluations against stored due dates.

### 4. Analytics & Reporting
*   **Financial Metrics:** Aggregates and computes key performance indicators (KPIs) such as Gross Revenue, Cost of Goods Sold (COGS), and Profit Margins.
*   **Data Exportation:** Generates formatted PDF reports via the `printing` and `pdf` libraries for external auditing and record-keeping.

---

## 🔒 Security Implementations

*   **Cryptographic Hashing:** The primary owner authentication utilizes a 4-6 digit PIN, which is securely hashed via **SHA-256** before local storage.
*   **Brute-Force Mitigation:** Implements an exponential backoff algorithm and a strict 30-minute security lockout after 5 consecutive failed authentication attempts.

---

## 🛠️ Technology Stack

| Component | Technology / Package | Justification |
| :--- | :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev/) (Dart) | Cross-platform compilation and high-performance rendering. |
| **State Management** | [Riverpod](https://riverpod.dev/) (`flutter_riverpod` 2.x) | Compile-safe, declarative state propagation and dependency injection. |
| **Local Persistence** | SQLite (`sqflite`) | ACID-compliant relational data storage for offline reliability. |
| **Cloud Infrastructure** | Firebase (Firestore) | NoSQL document database for scalable cloud synchronization. |
| **Utilities** | `connectivity_plus`, `uuid` | Network state detection and universally unique identifier generation. |

---

## ⚙️ Development Setup

### Prerequisites
*   Flutter SDK (v3.x+)
*   Dart SDK
*   Android Studio / Xcode (for emulation/compilation)
*   A configured Firebase Project

### Installation Protocol

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/giyuu0215/Sar-E-Flutter.git
    cd Sar-E-Flutter/sare
    ```

2.  **Resolve Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure Backend Services:**
    *   Initialize the Firebase environment utilizing the FlutterFire CLI:
        ```bash
        flutterfire configure
        ```
    *   *(Alternatively, inject the `google-services.json` or `GoogleService-Info.plist` artifacts manually into their respective build directories.)*

4.  **Compile & Execute:**
    ```bash
    flutter run
    ```
