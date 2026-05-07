# 📘 Smart Expense Tracker — Technical Documentation

| | |
|---|---|
| **App Name** | Smart Expense Tracker |
| **Version** | 1.0.0+1 |
| **Framework** | Flutter (Dart) |
| **Backend** | Firebase Authentication + Cloud Firestore |
| **State Management** | Provider (ChangeNotifier) |
| **Platform** | Android, iOS |
| **Course** | Mobile Application Lab — Final Project |
| **Date** | May 2026 |

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Core Functionalities](#2-core-functionalities)
3. [Project Structure](#3-project-structure)
4. [Data Models](#4-data-models)
5. [Screens & UI](#5-screens--ui)
6. [Services](#6-services)
7. [Widgets](#7-widgets)
8. [API Documentation (Firebase)](#8-api-documentation-firebase)
9. [Firestore Database Schema](#9-firestore-database-schema)
10. [Build & Deployment](#10-build--deployment)

---

## 1. Project Overview

**Smart Expense Tracker** is a cross-platform mobile application built with the **Flutter** framework. It provides users with a comprehensive personal finance management solution — enabling them to track income and expenses by category, set and monitor category-wise budgets, visualize financial patterns through interactive charts, and export reports in PDF or Excel format.

The app uses **Firebase Authentication** for secure user management and **Cloud Firestore** as its real-time NoSQL database. All data is scoped per authenticated user using Firestore's hierarchical collection structure. Application state is managed through the **Provider** pattern using `ChangeNotifier`.

### Application Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      Flutter App                         │
│                                                          │
│  ┌─────────┐   ┌──────────┐   ┌────────┐   ┌────────┐  │
│  │ Screens │ → │ Provider │ → │Services│ → │ Models │  │
│  └─────────┘   └──────────┘   └────┬───┘   └────────┘  │
│                                     │                    │
└─────────────────────────────────────┼────────────────────┘
                                      │
                         ┌────────────▼────────────┐
                         │        Firebase          │
                         │                         │
                         │  ┌─────────────────┐    │
                         │  │ Firebase Auth   │    │
                         │  └─────────────────┘    │
                         │  ┌─────────────────┐    │
                         │  │ Cloud Firestore │    │
                         │  └─────────────────┘    │
                         └─────────────────────────┘
```

### App Entry Flow

```
main() → Firebase.initializeApp() → MultiProvider
              │
              ▼
         AuthWrapper
         /          \
  isAuthenticated   not authenticated
        │                  │
  DashboardScreen     LoginScreen
```

---

## 2. Core Functionalities

### 🔐 2.1 User Authentication

- **Registration:** New users sign up with name, email, and password. On success, a Firestore document is created at `users/{uid}` storing name, email, and `created_at` timestamp. Firebase `displayName` is also updated.
- **Login:** Existing users authenticate via `FirebaseAuth.signInWithEmailAndPassword()`. Specific error codes (`user-not-found`, `wrong-password`, `too-many-requests`) are translated into user-friendly messages.
- **Auto-Login:** Firebase `authStateChanges()` stream automatically restores session on app restart — no manual token handling required.
- **Password Reset:** `FirebaseAuth.sendPasswordResetEmail()` sends a reset link to the user's inbox.
- **Profile Update:** Users can update their display name, which is saved to both Firebase Auth (`displayName`) and Firestore.
- **Logout:** `FirebaseAuth.signOut()` clears the session and returns the user to the login screen.

---

### 📊 2.2 Dashboard

- Displays three **summary cards**: Total Income, Total Expenses, and Current Balance.
- Shows an interactive **chart** (`ChartWidget`) with category-wise expense breakdown.
- Lists **recent transactions** using the `RecentTransactions` widget.
- Renders a **budget notification** widget if any budget is approaching or has exceeded its limit.

---

### 💸 2.3 Expense Management

- Add expense with: title, amount, category, date, optional description.
- View all expenses in a scrollable list, ordered by date (newest first) via Firestore `orderBy`.
- **Real-time updates** via Firestore `Stream` — list updates automatically when data changes.
- Delete an expense — removes the Firestore document.
- Update an existing expense entry.
- Filter by date and category using `SearchFilterBar`.

---

### 💵 2.4 Income Management

- Add income with: title, amount, category (Salary / Freelance / Investment / Business / Other), date.
- View and delete income records.
- Same real-time Firestore stream as expenses.

---

### 🎯 2.5 Budget Management

- Set budgets **per category** with a period of `monthly` or `yearly`.
- `BudgetService.getBudgetStatus()` fetches the current month's expense transactions from Firestore and calculates spending per category.
- **Warning state** (`isWarning`): triggered when spending reaches **≥ 80%** of the budget limit.
- **Exceeded state** (`isExceeded`): triggered when spending **exceeds 100%** of the limit.
- Budget notification widget is displayed on the dashboard when any category is in warning or exceeded state.
- Full CRUD: create, update, and delete budgets via Firestore.

---

### 📄 2.6 PDF Report Generation

`PDFService` generates A4-format PDF reports with three sections:

1. **Summary Table** — Total Income (green), Total Expense (red), Balance (blue)
2. **Category Breakdown Table** — expense amount and percentage per category, sorted by amount
3. **Transaction Table** — Date, Title, Category, Amount (Tk), Type; rows color-coded green (income) / red (expense)

**Report types supported:**
- **Daily** — Single date
- **Monthly** — `generateMonthlyReport()` filters by month/year
- **Yearly** — `generateYearlyReport()` filters by year
- **All Time** — All transactions; date range shown as "Since {oldest date}"

PDF is shared or printed using the device's native share sheet via `Printing.sharePdf()`.

---

### 📊 2.7 Excel Export

`ExcelExport.exportTransactions()` generates a `.xlsx` file with columns:

| Column | Content |
|---|---|
| Title | Transaction title |
| Category | Transaction category |
| Amount (Tk) | Amount as a number |
| Date | Formatted as `yyyy-MM-dd` |
| Type | `income` or `expense` |

- Header row is **bold**.
- File is saved to the device's application documents directory via `path_provider`.
- Filename format: `{type}_report_{yyyy-MM-dd_HH-mm}.xlsx`

---

### 🌙 2.8 Theme Management

- Toggle between **Light Mode** and **Dark Mode**.
- Preference saved to `SharedPreferences` (key: `isDarkMode`) and persists between sessions.
- Light theme: blue primary (`Colors.blue`), white cards, grey `#F5F5F5` background.
- Dark theme: `#121212` background, `#1E1E1E` cards, white text.

---

## 3. Project Structure

```
expense_tracker/
├── lib/
│   ├── models/
│   │   ├── transaction.dart        # Transaction data model
│   │   ├── budget.dart             # Budget & BudgetStatus models
│   │   └── category.dart           # CustomCategory, CategoryHelper
│   │
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── expense_screen.dart
│   │   ├── income_screen.dart
│   │   ├── budget_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── budget_notification_widget.dart
│   │   └── pdf_download_dialog.dart
│   │
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── transaction_service.dart
│   │   ├── budget_service.dart
│   │   ├── category_service.dart
│   │   ├── pdf_service.dart
│   │   └── theme_service.dart
│   │
│   ├── utils/
│   │   └── excel_export.dart
│   │
│   ├── widgets/
│   │   ├── chart_widget.dart
│   │   ├── recent_transactions.dart
│   │   ├── search_filter_bar.dart
│   │   ├── summary_card.dart
│   │   └── transaction_card.dart
│   │
│   ├── firebase_options.dart
│   └── main.dart
│
├── assets/images/logo1.png
├── android/
├── ios/
├── web/
├── test/widget_test.dart
├── firebase.json
├── pubspec.yaml
└── README.md
```

---

## 4. Data Models

### 4.1 `Transaction`

```dart
class Transaction {
  final String id;          // Firestore document ID
  final String title;       // Transaction label
  final double amount;      // Amount in Taka
  final String category;    // Category name
  final DateTime date;      // Transaction date
  final String type;        // 'income' or 'expense'
  final String? description; // Optional note
}
```

**Firestore serialization:**
- `fromFirestore(Map data)` — reads Firestore `Timestamp` and converts to `DateTime`
- `toFirestore()` — converts `DateTime` to Firestore `Timestamp` for storage

---

### 4.2 `Budget`

```dart
class Budget {
  final String id;          // Firestore document ID
  final String userId;      // Owner's Firebase UID
  final String category;    // Budget category name
  final double amount;      // Budget limit in Taka
  final String period;      // 'monthly' or 'yearly'
  final DateTime createdAt; // Creation timestamp
}
```

---

### 4.3 `BudgetStatus` (computed)

```dart
class BudgetStatus {
  final Budget budget;
  final double spent;       // Total spent in current month for this category
  final double remaining;   // budget.amount - spent
  final double percentage;  // (spent / budget.amount) * 100
  final bool isExceeded;    // spent > budget.amount
  final bool isWarning;     // percentage >= 80%
}
```

---

### 4.4 `CustomCategory`

```dart
class CustomCategory {
  final String id;
  final String userId;
  final String name;        // Category label
  final String type;        // 'income' or 'expense'
  final String? icon;       // Optional icon identifier
  final String? color;      // Optional hex color string
  final DateTime createdAt;
}
```

---

### 4.5 Default Categories (`CategoryHelper`)

**Income categories:**
`Salary`, `Freelance`, `Investment`, `Business`, `Other`

**Expense categories:**
`Food`, `Transport`, `Shopping`, `Entertainment`, `Bills`, `Healthcare`, `Education`, `Other`

`CategoryHelper.getAllCategories(type, customCategories)` merges default categories with the user's custom categories.

---

## 5. Screens & UI

### `main.dart`
Initializes Firebase synchronously before `runApp()`. Sets up `MultiProvider` with `AuthService` and `ThemeService`. `AuthWrapper` listens to `AuthService.isAuthenticated` and renders `DashboardScreen` or `LoginScreen` accordingly.

---

### `login_screen.dart`
- Email and password text fields with validation.
- **Login** button calls `AuthService.loginWithMessage()` which returns specific Firebase error codes translated to human-readable messages (e.g., `wrong-password` → "Wrong password. Please try again.").
- **Forgot Password** link calls `AuthService.sendPasswordReset()` and shows result in a dialog.
- Navigation to `SignupScreen`.

---

### `signup_screen.dart`
- Name, email, and password fields.
- Calls `AuthService.signupWithMessage()`.
- On success, creates Firestore user profile and navigates to Dashboard.

---

### `dashboard_screen.dart`
- Displays `SummaryCard` widgets for Balance, Total Income, Total Expense.
- `ChartWidget` shows expense breakdown by category.
- `RecentTransactions` widget lists latest entries.
- `BudgetNotificationWidget` shown if any budget is in warning/exceeded state.
- Bottom navigation bar linking to all main screens.

---

### `expense_screen.dart`
- Streams expenses in real-time from Firestore via `TransactionService.transactionsStream(type: 'expense')`.
- `FloatingActionButton` opens an add-expense bottom sheet or dialog.
- Each item rendered as `TransactionCard`; swipe or tap to delete.
- `SearchFilterBar` enables filtering by date range and category.

---

### `income_screen.dart`
- Same structure as `expense_screen.dart` but scoped to `type: 'income'`.
- Income categories: Salary, Freelance, Investment, Business, Other.

---

### `budget_screen.dart`
- Form to create a budget: select category, enter amount, choose period (monthly/yearly).
- Lists existing budgets with a progress bar showing `BudgetStatus.percentage`.
- Color-coded: green (safe), orange (warning ≥80%), red (exceeded).
- Edit and delete options per budget entry.

---

### `settings_screen.dart`
- Displays user name and email fetched from `AuthService`.
- Edit name field → calls `AuthService.updateName()` (updates both Firebase Auth `displayName` and Firestore document).
- Dark/Light toggle → calls `ThemeService.toggleTheme()`.
- Profile picture selection via `image_picker`.
- **Logout** button → calls `AuthService.logout()` → navigates to LoginScreen.

---

### `pdf_download_dialog.dart`
- Dialog for selecting report type: Daily, Monthly, Yearly, All Time.
- On confirm, calls appropriate `PDFService` method.
- Uses `Printing.sharePdf()` to open native share/print sheet.

---

### `budget_notification_widget.dart`
- Inline widget displayed on the Dashboard.
- Calls `BudgetService.getBudgetStatus()` and shows alert cards for categories in warning or exceeded states.

---

## 6. Services

### 6.1 `AuthService` (ChangeNotifier)

Wraps Firebase Authentication and Firestore user profile management.

| Method | Return | Description |
|---|---|---|
| `login(email, password)` | `Future<bool>` | Signs in with Firebase Auth |
| `loginWithMessage(email, password)` | `Future<Map>` | Login with detailed error messages |
| `signup(name, email, password)` | `Future<bool>` | Creates Firebase Auth account + Firestore profile |
| `signupWithMessage(name, email, password)` | `Future<Map>` | Signup with detailed error messages |
| `updateName(newName)` | `Future<bool>` | Updates Firebase Auth displayName + Firestore doc |
| `sendPasswordReset(email)` | `Future<Map>` | Sends Firebase password reset email |
| `logout()` | `Future<void>` | Signs out from Firebase Auth |
| `setAccountCreatedAtFromTransactions(date)` | `Future<void>` | Updates account creation date if transactions are older |

**Getters:**

| Getter | Type | Description |
|---|---|---|
| `isAuthenticated` | `bool` | True if Firebase user is not null |
| `userId` | `String?` | Current Firebase UID |
| `userName` | `String?` | Display name from Firestore |
| `userEmail` | `String?` | Email from Firebase Auth |
| `accountCreatedAt` | `DateTime?` | Account creation timestamp |

---

### 6.2 `TransactionService`

All Firestore operations are scoped to `users/{userId}/transactions`.

| Method | Return | Description |
|---|---|---|
| `getTransactions({type?})` | `Future<List<Transaction>>` | Fetch all transactions, optionally filtered by type (filtered in Dart) |
| `transactionsStream({type?})` | `Stream<List<Transaction>>` | Real-time Firestore stream of transactions |
| `addTransaction(transaction)` | `Future<Transaction?>` | Add a new transaction document |
| `updateTransaction(id, transaction)` | `Future<bool>` | Update an existing transaction |
| `deleteTransaction(id)` | `Future<bool>` | Delete a transaction document |
| `getSummary()` | `Future<Map<String, double>>` | Returns `totalIncome`, `totalExpense`, `balance` |
| `getMonthlySummary(year, month)` | `Future<Map<String, double>>` | Summary filtered by month using Firestore `where` |

> **Note:** Transactions are ordered by `date` descending in Firestore. Type filtering is performed in Dart to avoid composite index requirements.

---

### 6.3 `BudgetService`

All Firestore operations are scoped to `users/{userId}/budgets`.

| Method | Return | Description |
|---|---|---|
| `getBudgets()` | `Future<List<Budget>>` | Fetch all budgets for the user |
| `getBudgetStatus()` | `Future<Map<String, BudgetStatus>>` | Calculate current month's spending vs budget per category |
| `createBudget(budget)` | `Future<bool>` | Create new budget document |
| `updateBudget(id, budget)` | `Future<bool>` | Update existing budget |
| `deleteBudget(id)` | `Future<bool>` | Delete budget document |

> `getBudgetStatus()` queries `transactions` where `type == 'expense'` and `date` is within the current month, then aggregates spending by category and computes `BudgetStatus` for each budget.

---

### 6.4 `CategoryService`

All Firestore operations are scoped to `users/{userId}/categories`.

| Method | Return | Description |
|---|---|---|
| `getCustomCategories()` | `Future<List<CustomCategory>>` | Fetch all custom categories ordered by `created_at` |
| `createCategory(category)` | `Future<bool>` | Create new custom category |
| `updateCategory(id, category)` | `Future<bool>` | Update existing category |
| `deleteCategory(id)` | `Future<bool>` | Delete category document |

---

### 6.5 `PDFService` (static)

| Method | Return | Description |
|---|---|---|
| `generateReport(transactions, startDate, endDate, reportType)` | `Future<Uint8List>` | Builds full A4 PDF with 3 sections |
| `generateMonthlyReport(transactions, month, year)` | `Future<Uint8List>` | Filters by month, calls `generateReport` |
| `generateYearlyReport(transactions, year)` | `Future<Uint8List>` | Filters by year, calls `generateReport` |
| `savePDF(pdfData, filename)` | `Future<void>` | Shares PDF via native share sheet |
| `printPDF(pdfData)` | `Future<void>` | Opens native print dialog |

**PDF Sections:**
1. **Header** — Report title, report type label, date range string
2. **Summary Table** — Income (green bg), Expense (red bg), Balance (blue bg)
3. **Category Breakdown** — Category, Amount, Percentage; sorted by amount descending
4. **Transaction Table** — Date, Title, Category, Amount (Tk), Type; color-coded rows

---

### 6.6 `ThemeService` (ChangeNotifier)

| Method / Getter | Description |
|---|---|
| `toggleTheme()` | Flips `_isDarkMode`, saves to `SharedPreferences` key `isDarkMode` |
| `isDarkMode` | Boolean getter for current theme mode |
| `lightTheme` | Blue-primary `ThemeData` with white cards |
| `darkTheme` | Dark `#121212` scaffold with `#1E1E1E` card surface |

---

### 6.7 `ExcelExport` (static)

| Method | Description |
|---|---|
| `exportTransactions(transactions, type)` | Creates `.xlsx` with headers + data rows; saves to app documents directory via `path_provider` |

---

## 7. Widgets

### `SummaryCard`
Displays a labeled financial metric card.
- **Props:** `title` (String), `amount` (double), `color` (Color)
- Used on Dashboard for Balance, Total Income, Total Expense

### `TransactionCard`
Renders a single transaction row in a list.
- Shows category icon, title, amount, and formatted date
- Amount is displayed in green for income, red for expense

### `RecentTransactions`
A scrollable widget listing the most recent transactions using `TransactionCard`.

### `ChartWidget`
Interactive chart using the `fl_chart` package.
- Renders pie chart or bar chart based on expense data per category
- Accepts `Map<String, double>` of category → total amount

### `SearchFilterBar`
Reusable filter component placed above transaction lists.
- Text input for keyword search
- Date range picker
- Dropdown for category and type filtering

---

## 8. API Documentation (Firebase)

This app does not use a traditional REST API. All data operations go through the **Firebase SDK** directly. The following documents the Firebase service calls made.

---

### 8.1 Firebase Authentication

| Operation | Firebase Method | Description |
|---|---|---|
| Sign Up | `createUserWithEmailAndPassword(email, password)` | Creates new user account |
| Update Display Name | `user.updateDisplayName(name)` | Sets Firebase Auth display name |
| Sign In | `signInWithEmailAndPassword(email, password)` | Authenticates existing user |
| Password Reset | `sendPasswordResetEmail(email)` | Sends reset link to email |
| Sign Out | `signOut()` | Ends user session |
| Auth State | `authStateChanges()` | Stream that emits on login/logout |

**Firebase Auth Error Codes Handled:**

| Code | User-Facing Message |
|---|---|
| `user-not-found` | No account found with this email |
| `wrong-password` / `invalid-credential` | Wrong password. Please try again |
| `email-already-in-use` | An account already exists with this email |
| `weak-password` | Password is too weak. Use at least 6 characters |
| `invalid-email` | Invalid email address |
| `user-disabled` | This account has been disabled |
| `too-many-requests` | Too many attempts. Try again later |

---

### 8.2 Cloud Firestore Operations

#### Collection: `users/{userId}`

| Operation | Method | Description |
|---|---|---|
| Create profile | `set({name, email, created_at})` | On signup |
| Read profile | `get()` | On login to load name and creation date |
| Update name | `update({name})` | On profile edit |

---

#### Collection: `users/{userId}/transactions`

| Operation | Firestore Method | Details |
|---|---|---|
| Fetch all | `orderBy('date', descending: true).get()` | Returns all transactions newest first |
| Real-time stream | `orderBy('date', descending: true).snapshots()` | Live updates |
| Add | `add(transaction.toFirestore())` | New document auto-ID |
| Update | `doc(id).update(data)` | Partial update |
| Delete | `doc(id).delete()` | Remove document |
| Monthly filter | `where('date', >=, startOfMonth).where('date', <=, endOfMonth).get()` | Used in budget status |

**Transaction Document Structure:**
```json
{
  "title": "Lunch",
  "amount": 150.0,
  "category": "Food",
  "date": "<Firestore Timestamp>",
  "type": "expense",
  "description": "Optional note"
}
```

---

#### Collection: `users/{userId}/budgets`

| Operation | Firestore Method |
|---|---|
| Fetch all | `get()` |
| Add | `add(budget.toFirestore())` |
| Update | `doc(id).update(data)` |
| Delete | `doc(id).delete()` |

**Budget Document Structure:**
```json
{
  "category": "Food",
  "amount": 3000.0,
  "period": "monthly",
  "created_at": "<Firestore Timestamp>"
}
```

---

#### Collection: `users/{userId}/categories`

| Operation | Firestore Method |
|---|---|
| Fetch all | `orderBy('created_at', descending: false).get()` |
| Add | `add(category.toFirestore())` |
| Update | `doc(id).update(data)` |
| Delete | `doc(id).delete()` |

**Category Document Structure:**
```json
{
  "name": "Groceries",
  "type": "expense",
  "icon": "shopping_cart",
  "color": "#FF5733",
  "created_at": "<Firestore Timestamp>"
}
```

---

## 9. Firestore Database Schema

```
Firestore (Root)
└── users/
    └── {userId}/                          ← Firebase Auth UID
        │
        ├── [Document: user profile]
        │   ├── name: string
        │   ├── email: string
        │   └── created_at: Timestamp
        │
        ├── transactions/
        │   └── {transactionId}/
        │       ├── title: string
        │       ├── amount: number
        │       ├── category: string
        │       ├── date: Timestamp
        │       ├── type: string           ← "income" | "expense"
        │       └── description: string?
        │
        ├── budgets/
        │   └── {budgetId}/
        │       ├── category: string
        │       ├── amount: number
        │       ├── period: string         ← "monthly" | "yearly"
        │       └── created_at: Timestamp
        │
        └── categories/
            └── {categoryId}/
                ├── name: string
                ├── type: string           ← "income" | "expense"
                ├── icon: string?
                ├── color: string?
                └── created_at: Timestamp
```

### Default Categories (built-in, not stored in Firestore)

**Income:** `Salary`, `Freelance`, `Investment`, `Business`, `Other`

**Expense:** `Food`, `Transport`, `Shopping`, `Entertainment`, `Bills`, `Healthcare`, `Education`, `Other`

Custom categories created by the user are stored in the `categories` subcollection and merged with defaults at runtime by `CategoryHelper.getAllCategories()`.

---

## 10. Build & Deployment

### Run in Debug Mode
```bash
flutter run
```

### Run on Specific Device
```bash
flutter devices
flutter run -d <device-id>
```

### Build Release APK (Android)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Build App Bundle (for Google Play)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### Install Directly on Device
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Build for iOS
```bash
flutter build ios --release
```

### Run Tests
```bash
flutter test
```

### Generate Splash Screen & Launcher Icons
```bash
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

---

## ✅ Submission Checklist

- [x] Project pushed to GitHub
- [x] `README.md` added to repository root
- [x] `DOCUMENTATION.md` added to repository root
- [x] Firebase backend fully functional (Auth + Firestore)
- [x] PDF report generation implemented
- [x] Excel export implemented
- [x] Dark/Light theme implemented
- [x] Custom launcher icon configured
- [x] Splash screen configured
- [ ] App screenshots added to `README.md`
- [ ] APK built and tested on physical Android device

---

*Documentation prepared for Mobile Application Lab — Final Exam Submission, May 2026*