# Sar-E: Sari-Sari Store Management System

Sar-E is a comprehensive Point of Sale (POS), Inventory, and Credit Management system built specifically for traditional neighborhood stores (Sari-Sari stores) in the Philippines.

Built with **Flutter** for cross-platform compatibility, the system uses an **offline-first architecture** with **SQLite** for instant local data access, and synchronizes data to **Firebase Firestore** seamlessly in the background.

## 🚀 Key Features

*   **Hybrid POS (Point of Sale):**
    *   Fast checkout with cart management.
    *   Dynamic payment methods (Cash and E-Wallet via QR Code overlays).
    *   Automatic change calculation for cash payments.
*   **Smart Inventory Management:**
    *   Real-time stock tracking with low-stock threshold alerts.
    *   Dynamic price catalog capable of ingesting suggested prices.
*   **Digital Listahan (Credit Tracker):**
    *   Track customer debts, record repayments, and calculate outstanding balances.
    *   Automated overdue flagging for past-due credits.
*   **Offline-First & Cloud Sync:**
    *   100% functional without an internet connection using a 16-table local SQLite database.
    *   Background sync queue (`firestore_sync`) pushes changes to Firebase when the device goes online.
*   **Robust Analytics:**
    *   Monitor Revenue, COGS, Gross Profit, and Profit Margins.
    *   Generate and export detailed Sales Reports as PDF documents.
*   **Secure Authentication:**
    *   PIN-based setup and login.
    *   Security lockouts after multiple failed attempts.

## 🛠️ Tech Stack

*   **Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **State Management:** [Riverpod](https://riverpod.dev/) (`flutter_riverpod` 2.x)
*   **Local Database:** SQLite via [`sqflite`](https://pub.dev/packages/sqflite)
*   **Cloud Backend:** Firebase (Firestore) via `firebase_core` & `cloud_firestore`
*   **Utilities:** `connectivity_plus` (online status), `qr_flutter` (E-Wallet generation), `printing` & `pdf` (Report generation), `uuid` (UUID generation).

## 📁 Architecture Overview (Clean Architecture)

The project strictly follows Domain-Driven Clean Architecture to separate UI, state, and data persistence:

```text
lib/
├── application/         # Riverpod Notifiers (State Management)
├── data/
│   ├── local/           # AppDatabase (SQLite) and Data Access Objects (DAOs)
│   └── sync/            # Firebase sync queue logic
├── domain/              # Pure Dart domain entities (Product, Transaction, etc.)
├── screens/             # Flutter UI Views (POS, Inventory, Listahan, etc.)
├── theme/               # Global AppTheme and AppColors
└── widgets/             # Reusable UI components
```

## ⚙️ Getting Started

### Prerequisites

*   Flutter SDK (3.x or higher)
*   Dart SDK
*   Android Studio / Xcode for device emulation
*   Firebase Project (for cloud sync features)

### Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/sare.git
    cd sare/frontend
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration:**
    *   This project requires Firebase to operate its cloud sync queue.
    *   Run `flutterfire configure` to generate your `firebase_options.dart`.
    *   Alternatively, manually add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files to their respective directories.

4.  **Run the App:**
    ```bash
    flutter run
    ```

## 🔒 Security Notes

The initial owner setup requires a secure 4-6 digit PIN. This PIN is hashed locally using **SHA-256** and is required for all subsequent logins. Failing the PIN entry 5 times will trigger a 30-minute lockout.
