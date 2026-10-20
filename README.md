# JAY PHARMA (PVT) LTD
## Digital Cash Collection & Receipt System

A high-performance, enterprise-grade mobile cash collection and receipt issuing application developed for **Jay Pharma (Pvt) Ltd** field representatives and cash collectors. 

This system digitizes the field payment collection process by equipping collectors with a tablet or mobile device connected to a portable receipt printer, eliminating manual handwritten duplicate receipts while connecting directly to Jay Pharma's existing **SQL Server** database.

---

## 🏛️ System Architecture

```
┌────────────────────────────────────────────────────────┐
│           Jay Pharma Flutter Mobile App                │
│ (Android Tablet / Phone, Windows Desktop, Web)         │
│  - Offline-first cache & validation engine             │
│  - ESC/POS & PDF Portable Bluetooth Printing           │
│  - GPS Location Tracking & Device Access Guard         │
│  - Dual Language (English & සිංහල)                     │
└───────────────────────────┬────────────────────────────┘
                            │ REST API (JSON / HTTP)
                            ▼
┌────────────────────────────────────────────────────────┐
│           Jay Pharma C# Web API Backend                │
│           (ASP.NET Core / .NET 8 / 10)                 │
│  - Strict Manual Receipt Uniqueness Validation         │
│  - Idempotency & Transaction rollback protection       │
│  - Audit Trail Engine (Section 6)                      │
└───────────────────────────┬────────────────────────────┘
                            │ SqlClient (TDS Protocol)
                            ▼
┌────────────────────────────────────────────────────────┐
│           Microsoft SQL Server Database                │
│                  (JayPharmaDB)                         │
│  - Customers, Invoices, Receipts, ReceiptInvoices      │
│  - DayEndSummaries, Collectors, AuditLogs              │
└────────────────────────────────────────────────────────┘
```

---

## 📱 Features & Document Requirements Implementation

### 1. Home Screen (Section 2.1)
- **Executive Dashboard**: Displays real-time metrics for today's collections: Total Collection Amount, Cash Amount, Cheque Amount, Number of Receipts issued, and Day-End Status.
- **Operations Grid**:
  1. **Accept Payment**: Launch field collection workflow.
  2. **Receipts**: View historical receipts issued by the logged-in collector.
  3. **Customers**: View customer directory and invoice balances.
  4. **Day-End Summary**: Daily reconciliation and finalization statement.
- **Sync Data**: One-tap synchronization with backend SQL Server database showing the last synchronization timestamp.
- **Day-End Lock Guard**: Prominently displays an alert banner if the day has been finalized.

### 2. Accept Payment Workflow (Section 2.2)

#### Step 1: Select Customer Screen
- Fast search by **Customer Number** (e.g. `C1001`) or **Customer Name** (e.g. `City Pharmacy`).
- Filter by town/district (Colombo, Kandy, Negombo, Kurunegala, Gampaha, Ja-Ela).
- Displays customer name, address, phone number, and count of outstanding invoices.
- Strict requirement: collector must select the correct customer to proceed.

#### Step 2: Customer Details & Payment Information Screen
- **Customer Card**: Displays Customer Code, Name, Address, and Phone.
  > **Document Rule Adhered To**: *Does not display the customer's total outstanding balance in the customer details section.*
- **Payment Method**:
  - **Cash**: Instant cash collection mode.
  - **Cheque**: Dynamic form appears with mandatory fields:
    - Bank Name (Sri Lankan bank selector: Commercial Bank, BOC, People's Bank, Sampath, HNB, etc.)
    - Branch Name
    - Cheque Number (Mandatory)
    - Cheque Date (Mandatory date picker)
- **Payment Amount**: Total cash/cheque amount handed over by customer, with quick amount chips.
- **Manual Receipt Number**:
  - Live uniqueness check against the database.
  - Duplicate manual receipt numbers are prevented and highlighted in red.
- **Outstanding Invoices List & Dynamic Auto-Allocation**:
  - Displays all unpaid invoices up to the current date.
  - Each invoice shows: Checkbox, Invoice Number, Delivery Date, **Delivery Age (calculated from delivery date to current date)**, Outstanding Balance, and Allocated Pay Amount.
  - **Auto-Allocation Algorithm**:
    - When an invoice is checked, automatically allocates available payment against its balance.
    - If the available balance is less than the invoice balance, applies a **Partial Payment**.
    - If the available payment reaches Rs. 0.00: **Prevents the collector from selecting additional invoices** and displays an alert message (*"Entire payment amount has already been allocated."*).
- **Advance Payment Support**:
  - Allows proceeding without selecting any invoices when recording an advance payment on account.
- **Notes / Comment**: Optional text field for collector comments or special invoice references.

#### Step 3: Preview Payment Details
- Executive review screen showing customer details, payment method, cheque particulars, total amount, itemized invoice allocation table, GPS coordinates, and collector notes.
- Includes **"Generate Receipt"** (Primary CTA) and **"Edit Details"** (to modify entries before final commitment).

### 3. Portable Receipt Printing & Confirmation (Section 2.3 & Page 5)
- **Exact Layout Matching Sample Receipt**:
  - `JAY PHARMA (PVT) LTD` header with Colombo 07 address, Tel, Email, and VAT No: `123456789-7000`.
  - Prominent red highlighted receipt number: `MR-026458`.
  - Date and `CUSTOMER COPY` label.
  - Customer particulars and payment mode.
  - Itemized table (`#`, `Invoice No.`, `Invoice Date`, `Invoice Amount`, `Amount Settled`).
  - Total Paid and *"Received with thanks."*
  - Collector's signature box.
- Direct Bluetooth printing to **58mm and 80mm ESC/POS portable thermal printers** or PDF output.
- **SMS Payment Confirmation**: Automated SMS notification simulation sent to customer's mobile upon successful receipt generation.

### 4. Receipts History & OTP-Restricted Reprinting (Section 2.5)
- Filter receipts by **Date Range** (defaults to the current date).
- Filter receipts recorded exclusively by the logged-in collector.
- View detailed receipt modal.
- **Controlled Reprint with OTP**:
  > **Document Rule Adhered To**: *Receipt reprinting is restricted by default. In exceptional cases, reprint is permitted only upon valid Manager / Cashier OTP verification.*
  - Prompts for a 6-digit OTP.
  - Upon valid OTP, prints a marked duplicate (`** DUPLICATE COPY - REPRINTED UNDER OTP **`).
  - Increments reprint counter and writes an immutable record to the audit trail.

### 5. Customers Screen (Section 2.6)
- Search customer directory by code or name.
- Expand customer profile to view all outstanding invoices, delivery ages in days, original amounts, and current balances.
- Shortcut button to start payment collection directly for that customer.

### 6. Day-End Summary Statement (Section 3)
- Calculates daily financial totals:
  - **Total Cash Collected (Rs.)**
  - **Total Cheque Amount Collected (Rs.)**
  - **Itemized list of Cheques received** (Cheque Number, Bank, Customer, Amount, Cheque Date)
  - **Total Income Collected (Cash + Cheque)**
  - Full breakdown of all receipts issued for the day.
- **Collection Lock Enforcement**:
  > **Document Rule Adhered To**: *Once the day-end process is finalized and submitted, the representative/cash collector is permanently blocked from recording any further payments for that day.*
- **Printable Day-End Statement**:
  - Generates official settlement statement.
  - Dual signature lines for **Cash Collector** and **Back-Office Cashier**.
  - One copy is retained by the collector for records.

### 7. Security, Device Restrictions & Audit Trail (Sections 4 & 6)
- Authenticated collector accounts (`COL-042`).
- Authorized Device ID binding (`TAB-COL-042 - Samsung Galaxy Tab Active 3`).
- Location tracking enabled check with GPS coordinate capture.
- Session auto-logout after inactivity timeout (60 minutes).
- Complete security audit log tracking creation, reprint with OTP, day-end finalization, and sync events.

### 8. Language Support (Section 5)
- Full bilingual support with real-time toggle between **English** and **සිංහල (Sinhala)**.

---

## 🚀 How to Run

### 1. Database Setup (SQL Server)
Open **SQL Server Management Studio (SSMS)** and run the provided script:
```sql
-- File: JayPharma_Schema.sql
-- Executes table creations, indexes, constraints, and initial seed data matching the PDF
```

### 2. C# ASP.NET Core Web API Backend
Open a terminal in `backend/JayPharma.Api`:
```bash
dotnet run
```
The API starts on `http://localhost:5000` with Swagger documentation available at `http://localhost:5000/swagger`.

### 3. Flutter Mobile Application
Open a terminal in the root directory:
```bash
# Run tests
flutter test

# Run on Android Tablet / Phone
flutter run

# Run on Windows Desktop
flutter run -d windows

# Run in Chrome (Web)
flutter run -d chrome
```

---

## 📋 Credentials & Demo Values
- **Collector ID**: `COL-042`
- **Password**: `jay123`
- **Reprint Manager Master OTP**: `998877` (or auto-generated OTP in dialog)
- **Default Device ID**: `TAB-COL-042 (Samsung Tab Active 3)`
