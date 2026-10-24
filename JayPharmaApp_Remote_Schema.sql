-- ====================================================================
-- JAY PHARMA (PVT) LTD
-- Database: JayPharmaApp (Remote Host: 220.247.236.89,1931)
-- ====================================================================

-- 1. Collectors / Users Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Collectors')
BEGIN
    CREATE TABLE Collectors (
        CollectorId VARCHAR(20) PRIMARY KEY,
        Username NVARCHAR(50) NOT NULL UNIQUE,
        PasswordHash NVARCHAR(256) NOT NULL,
        FullName NVARCHAR(100) NOT NULL,
        Phone VARCHAR(20) NULL,
        Branch NVARCHAR(50) NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 2. Device Authorizations Table (Section 4 & 6)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DeviceAuthorizations')
BEGIN
    CREATE TABLE DeviceAuthorizations (
        DeviceId VARCHAR(100) PRIMARY KEY,
        CollectorId VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Collectors(CollectorId),
        DeviceModel NVARCHAR(100) NOT NULL,
        IsAuthorized BIT NOT NULL DEFAULT 1,
        AuthorizedAt DATETIME NOT NULL DEFAULT GETDATE(),
        LastActiveAt DATETIME NULL
    );
END
GO

-- 3. Customers Table (Section 2.1, 2.2, 2.6)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Customers')
BEGIN
    CREATE TABLE Customers (
        CustomerCode VARCHAR(20) PRIMARY KEY,
        CustomerName NVARCHAR(150) NOT NULL,
        Address NVARCHAR(250) NOT NULL,
        Phone VARCHAR(30) NOT NULL,
        Email NVARCHAR(100) NULL,
        Town NVARCHAR(50) NOT NULL,
        CreditLimit DECIMAL(18, 2) NOT NULL DEFAULT 1000000.00,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
    );
    CREATE INDEX IX_Customers_Name ON Customers(CustomerName);
    CREATE INDEX IX_Customers_Town ON Customers(Town);
END
GO

-- 4. Invoices Table (Section 2.2, 2.6)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Invoices')
BEGIN
    CREATE TABLE Invoices (
        InvoiceNo VARCHAR(30) PRIMARY KEY,
        CustomerCode VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Customers(CustomerCode),
        InvoiceDate DATE NOT NULL,
        DeliveryDate DATE NOT NULL,
        TotalAmount DECIMAL(18, 2) NOT NULL,
        OutstandingBalance DECIMAL(18, 2) NOT NULL,
        Status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE()
    );
    CREATE INDEX IX_Invoices_Customer_Balance ON Invoices(CustomerCode, OutstandingBalance);
END
GO

-- 5. Receipts Table (Section 2.2, 2.3, 2.5, 6)
-- Manual receipt numbers must be unique and validated. Cannot be reused even if cancelled.
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Receipts')
BEGIN
    CREATE TABLE Receipts (
        ManualReceiptNo VARCHAR(30) PRIMARY KEY,
        CustomerCode VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Customers(CustomerCode),
        CustomerName NVARCHAR(150) NOT NULL,
        CustomerAddress NVARCHAR(250) NOT NULL,
        CustomerPhone VARCHAR(30) NULL,
        PaymentMethod VARCHAR(20) NOT NULL, -- CASH, CHEQUE
        Bank NVARCHAR(100) NULL,
        Branch NVARCHAR(100) NULL,
        ChequeNumber VARCHAR(50) NULL,
        ChequeDate DATE NULL,
        TotalAmount DECIMAL(18, 2) NOT NULL,
        Comments NVARCHAR(500) NULL,
        IsAdvancePayment BIT NOT NULL DEFAULT 0,
        CollectorId VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Collectors(CollectorId),
        CollectorName NVARCHAR(100) NOT NULL,
        Latitude DECIMAL(10, 7) NOT NULL,
        Longitude DECIMAL(10, 7) NOT NULL,
        LocationAddress NVARCHAR(250) NULL,
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
        IsCancelled BIT NOT NULL DEFAULT 0,
        CancelledAt DATETIME NULL,
        CancelledReason NVARCHAR(250) NULL,
        ReprintCount INT NOT NULL DEFAULT 0,
        SyncStatus VARCHAR(20) NOT NULL DEFAULT 'SYNCED'
    );
    CREATE INDEX IX_Receipts_Collector_Date ON Receipts(CollectorId, CreatedAt);
    CREATE INDEX IX_Receipts_Customer ON Receipts(CustomerCode);
END
GO

-- 6. Receipt Invoices Settlement Breakdown (Section 2.2, 2.3)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ReceiptInvoices')
BEGIN
    CREATE TABLE ReceiptInvoices (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        ManualReceiptNo VARCHAR(30) NOT NULL FOREIGN KEY REFERENCES Receipts(ManualReceiptNo),
        ItemIndex INT NOT NULL,
        InvoiceNo VARCHAR(30) NOT NULL FOREIGN KEY REFERENCES Invoices(InvoiceNo),
        InvoiceDate DATE NOT NULL,
        InvoiceAmount DECIMAL(18, 2) NOT NULL,
        AmountSettled DECIMAL(18, 2) NOT NULL,
        RemainingBalance DECIMAL(18, 2) NOT NULL
    );
    CREATE INDEX IX_ReceiptInvoices_Receipt ON ReceiptInvoices(ManualReceiptNo);
END
GO

-- 7. Day-End Summary Statement Table (Section 3)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DayEndSummaries')
BEGIN
    CREATE TABLE DayEndSummaries (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        SummaryDate DATE NOT NULL,
        CollectorId VARCHAR(20) NOT NULL FOREIGN KEY REFERENCES Collectors(CollectorId),
        CollectorName NVARCHAR(100) NOT NULL,
        TotalCash DECIMAL(18, 2) NOT NULL,
        TotalCheque DECIMAL(18, 2) NOT NULL,
        TotalIncome DECIMAL(18, 2) NOT NULL,
        TotalReceiptsCount INT NOT NULL,
        IsFinalized BIT NOT NULL DEFAULT 0,
        FinalizedAt DATETIME NULL,
        CashierNotes NVARCHAR(500) NULL,
        CashierSignedBy NVARCHAR(100) NULL,
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT UQ_Collector_Date UNIQUE (CollectorId, SummaryDate)
    );
END
GO

-- 8. Audit Logs Table (Section 6)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuditLogs')
BEGIN
    CREATE TABLE AuditLogs (
        Id BIGINT IDENTITY(1,1) PRIMARY KEY,
        Action VARCHAR(50) NOT NULL,
        ReferenceNo VARCHAR(50) NOT NULL,
        CollectorId VARCHAR(20) NOT NULL,
        CollectorName NVARCHAR(100) NOT NULL,
        Details NVARCHAR(MAX) NOT NULL,
        Timestamp DATETIME NOT NULL DEFAULT GETDATE()
    );
    CREATE INDEX IX_AuditLogs_Ref ON AuditLogs(ReferenceNo);
END
GO

-- 9. Main Database Connection / Configuration Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MainDatabaseConfig')
BEGIN
    CREATE TABLE MainDatabaseConfig (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        ConfigName NVARCHAR(100) NOT NULL DEFAULT 'Main ERP Database',
        DatabasePath NVARCHAR(500) NULL,
        ServerAddress NVARCHAR(200) NULL,
        DatabaseName NVARCHAR(100) NULL,
        Username NVARCHAR(100) NULL,
        Password NVARCHAR(255) NULL,
        ConnectionString NVARCHAR(MAX) NULL,
        ProviderType VARCHAR(50) NOT NULL DEFAULT 'MSSQL',
        IsActive BIT NOT NULL DEFAULT 1,
        LastSyncTime DATETIME NULL,
        SyncStatus VARCHAR(50) NULL DEFAULT 'INITIALIZED',
        SyncNotes NVARCHAR(MAX) NULL,
        CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
        UpdatedAt DATETIME NOT NULL DEFAULT GETDATE()
    );
END
GO


-- ====================================================================
-- SEED DATA MATCHING THE JAY PHARMA SPECIFICATION
-- ====================================================================

-- 1. Collector
IF NOT EXISTS (SELECT 1 FROM Collectors WHERE CollectorId = 'COL-042')
BEGIN
    INSERT INTO Collectors (CollectorId, Username, PasswordHash, FullName, Phone, Branch)
    VALUES ('COL-042', 'kasun', 'jay123', 'Kasun Perera', '077 123 4567', 'Colombo Division');

    INSERT INTO DeviceAuthorizations (DeviceId, CollectorId, DeviceModel, IsAuthorized)
    VALUES ('TAB-COL-042 (Samsung Tab Active 3)', 'COL-042', 'Samsung Galaxy Tab Active 3', 1);
END
GO

-- 2. Customers from Document
IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerCode = 'C1001')
BEGIN
    INSERT INTO Customers (CustomerCode, CustomerName, Address, Phone, Email, Town, CreditLimit) VALUES
    ('C1001', 'City Pharmacy', '123 Galle Road, Colombo 07', '011 234 5678', 'citypharmacy@gmail.com', 'Colombo 07', 1500000.00),
    ('C1002', 'HealthPlus Pharmacy', '45 Negombo Road, Negombo', '031 223 8890', 'healthplus.negombo@gmail.com', 'Negombo', 800000.00),
    ('C1003', 'MediCare Pharmacy', '88 Peradeniya Road, Kandy', '081 223 4455', 'medicare.kandy@gmail.com', 'Kandy', 1200000.00),
    ('C1004', 'Sunshine Pharmacy', '12 Colombo Road, Kurunegala', '037 222 1144', 'sunshine.pharma@gmail.com', 'Kurunegala', 750000.00),
    ('C1005', 'WellCare Pharmacy', '99 Main Street, Gampaha', '033 222 7788', 'wellcare.gampaha@gmail.com', 'Gampaha', 900000.00),
    ('C1006', 'New Life Pharmacy', '24 Station Road, Ja-Ela', '011 224 9911', 'newlife.jaela@gmail.com', 'Ja-Ela', 600000.00),
    ('C1007', 'Lanka Medicals', '67 Duplication Road, Colombo 03', '011 257 6633', 'lankamedicals@gmail.com', 'Colombo 03', 2000000.00);
END
GO

-- 3. Outstanding Invoices from Document Page 2, 3, 4
IF NOT EXISTS (SELECT 1 FROM Invoices WHERE InvoiceNo = 'INV-1045')
BEGIN
    INSERT INTO Invoices (InvoiceNo, CustomerCode, InvoiceDate, DeliveryDate, TotalAmount, OutstandingBalance, Status) VALUES
    ('INV-1045', 'C1001', '2026-09-12', '2026-09-12', 125000.00, 125000.00, 'UNPAID'),
    ('INV-1048', 'C1001', '2026-09-18', '2026-09-18', 87650.00,  87650.00,  'UNPAID'),
    ('INV-1051', 'C1001', '2026-09-25', '2026-09-25', 210000.00, 210000.00, 'UNPAID'),
    ('INV-1055', 'C1001', '2026-10-02', '2026-10-02', 65000.00,  65000.00,  'UNPAID'),
    ('INV-1060', 'C1002', '2026-09-20', '2026-09-20', 95000.00,  95000.00,  'UNPAID'),
    ('INV-1064', 'C1002', '2026-10-05', '2026-10-05', 140000.00, 140000.00, 'UNPAID'),
    ('INV-1070', 'C1003', '2026-09-15', '2026-09-15', 180000.00, 180000.00, 'UNPAID');
END
GO

-- 11. Last Generated OTP Table for Security Verification
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'LastGeneratedOtp')
BEGIN
    CREATE TABLE LastGeneratedOtp (
        Id INT PRIMARY KEY DEFAULT 1,
        OtpCode VARCHAR(10) NOT NULL,
        CollectorId VARCHAR(50) NULL,
        CustomerCode VARCHAR(50) NULL,
        CustomerName NVARCHAR(150) NULL,
        GeneratedAt DATETIME NOT NULL DEFAULT GETDATE(),
        ExpiresAt DATETIME NOT NULL,
        IsUsed BIT NOT NULL DEFAULT 0,
        UsedAt DATETIME NULL
    );
END
GO

