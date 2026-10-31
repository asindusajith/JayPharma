using System.Data;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Caching.Memory;

var builder = WebApplication.CreateBuilder(args);

// Explicitly bind to port 5100 when running standalone outside IIS (port 5000 is used by SQL Server)
if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ASPNETCORE_PORT")) &&
    string.IsNullOrEmpty(Environment.GetEnvironmentVariable("ASPNETCORE_TOKEN")))
{
    builder.WebHost.UseUrls("http://0.0.0.0:5100", "http://localhost:5100");
}

// Add services
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddMemoryCache();

// Enable CORS for Flutter Mobile / Web / Desktop app
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

app.UseCors("AllowAll");
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Jay Pharma Collection API v1");
    c.RoutePrefix = "swagger";
});

// Redirect root URL directly to Swagger docs
app.MapGet("/", () => Results.Redirect("/swagger"));

string connectionString = builder.Configuration.GetConnectionString("JayPharmaDB") 
    ?? "Server=220.247.236.89,1931;Database=JayPharmaApp;User Id=CeylonHQ;Password=Prison12!;TrustServerCertificate=True;Connect Timeout=30;";

string mainErpConnectionStringFallback = builder.Configuration.GetConnectionString("MainERP")
    ?? "Data Source=124.43.179.134,49172;Initial Catalog=JayPharma;Persist Security Info=True;User ID=WCeylon;Password=Prison12!;TrustServerCertificate=True;Connect Timeout=30;";

string? cachedMainErpConnStr = null;
DateTime lastMainErpConnStrFetch = DateTime.MinValue;
var connStrLock = new object();

async Task<string> GetMainErpConnectionStringAsync(bool forceRefresh = false)
{
    lock (connStrLock)
    {
        if (!forceRefresh && cachedMainErpConnStr != null && (DateTime.UtcNow - lastMainErpConnStrFetch).TotalSeconds < 15)
        {
            return cachedMainErpConnStr;
        }
    }

    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            SELECT TOP 1 ConnectionString, ServerAddress, DatabaseName, Username, Password, IsActive 
            FROM MainDatabaseConfig 
            WHERE IsActive = 1 
            ORDER BY Id DESC";
        using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            var raw = reader["ConnectionString"]?.ToString()?.Trim();
            if (!string.IsNullOrWhiteSpace(raw))
            {
                if (!raw.Contains("TrustServerCertificate", StringComparison.OrdinalIgnoreCase))
                    raw += ";TrustServerCertificate=True";
                if (!raw.Contains("Connect Timeout", StringComparison.OrdinalIgnoreCase))
                    raw += ";Connect Timeout=30";

                lock (connStrLock)
                {
                    cachedMainErpConnStr = raw;
                    lastMainErpConnStrFetch = DateTime.UtcNow;
                }
                return raw;
            }

            var srv = reader["ServerAddress"]?.ToString()?.Trim();
            var db = reader["DatabaseName"]?.ToString()?.Trim();
            var user = reader["Username"]?.ToString()?.Trim();
            var pwd = reader["Password"]?.ToString()?.Trim();
            if (!string.IsNullOrWhiteSpace(srv) && !string.IsNullOrWhiteSpace(db))
            {
                var built = $"Data Source={srv};Initial Catalog={db};User ID={user};Password={pwd};Persist Security Info=True;TrustServerCertificate=True;Connect Timeout=30;";
                lock (connStrLock)
                {
                    cachedMainErpConnStr = built;
                    lastMainErpConnStrFetch = DateTime.UtcNow;
                }
                return built;
            }
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[MainDatabaseConfig Load Error]: {ex.Message}");
    }

    return mainErpConnectionStringFallback;
}

// 1. Health check & DB Status
app.MapGet("/api/health", async () =>
{
    var appDbOk = false;
    var mainErpOk = false;
    string? appDbError = null;
    string? mainErpError = null;
    string activeErpConn = mainErpConnectionStringFallback;

    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();
        appDbOk = true;
    }
    catch (Exception ex) { appDbError = ex.Message; }

    try
    {
        activeErpConn = await GetMainErpConnectionStringAsync(forceRefresh: true);
        using var erpConn = new SqlConnection(activeErpConn);
        await erpConn.OpenAsync();
        mainErpOk = true;
    }
    catch (Exception ex) { mainErpError = ex.Message; }

    return Results.Ok(new 
    { 
        status = (appDbOk && mainErpOk) ? "ONLINE" : (appDbOk || mainErpOk ? "PARTIAL" : "OFFLINE"), 
        appDatabase = appDbOk ? "CONNECTED" : appDbError, 
        mainErpDatabase = mainErpOk ? "CONNECTED" : mainErpError,
        mainErpSource = activeErpConn.Contains("124.43.179.134") ? "LIVE_ERP (124.43.179.134)" : (activeErpConn.Contains("220.247.236.89") ? "OLD_ERP (220.247.236.89)" : "CONFIGURED_ERP"),
        realtime = true,
        timestamp = DateTime.UtcNow 
    });
});

// 1b. Main Database Configuration & Diagnostic Status
app.MapGet("/api/config/main-database", async () =>
{
    var result = new Dictionary<string, object?>();
    string? activeConnStr = null;

    try
    {
        using var appConn = new SqlConnection(connectionString);
        await appConn.OpenAsync();
        using var cmd = appConn.CreateCommand();
        cmd.CommandText = "SELECT TOP 1 Id, ConfigName, ServerAddress, DatabaseName, Username, ProviderType, IsActive, ConnectionString, UpdatedAt FROM MainDatabaseConfig WHERE IsActive = 1 ORDER BY Id DESC";
        using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            result["configId"] = reader["Id"];
            result["configName"] = reader["ConfigName"]?.ToString();
            result["serverAddress"] = reader["ServerAddress"]?.ToString();
            result["databaseName"] = reader["DatabaseName"]?.ToString();
            result["username"] = reader["Username"]?.ToString();
            result["isActive"] = reader["IsActive"];
            result["updatedAt"] = reader["UpdatedAt"];
            activeConnStr = reader["ConnectionString"]?.ToString();
        }
    }
    catch (Exception ex)
    {
        result["configLoadError"] = ex.Message;
    }

    if (string.IsNullOrWhiteSpace(activeConnStr))
    {
        activeConnStr = await GetMainErpConnectionStringAsync(forceRefresh: true);
    }

    var testResult = new Dictionary<string, object?>();
    try
    {
        using var erpConn = new SqlConnection(activeConnStr);
        await erpConn.OpenAsync();
        testResult["connected"] = true;

        var tables = new List<string>();
        using var tblCmd = erpConn.CreateCommand();
        tblCmd.CommandText = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME IN ('Invoice', 'AppInvoice', 'DPay', 'Customers', 'Customer')";
        using var tblReader = await tblCmd.ExecuteReaderAsync();
        while (await tblReader.ReadAsync())
        {
            tables.Add(tblReader[0].ToString()!);
        }
        testResult["detectedTables"] = tables;
        testResult["canReadInvoices"] = tables.Contains("Invoice");
        testResult["canWriteAppInvoice"] = tables.Contains("AppInvoice");
        testResult["canWriteDPay"] = tables.Contains("DPay");
    }
    catch (Exception ex)
    {
        testResult["connected"] = false;
        testResult["error"] = ex.Message;
    }

    result["connectionTest"] = testResult;
    return Results.Ok(result);
});

// 2. User/Collector Login & Access Control
app.MapPost("/api/auth/login", async (LoginRequest req) =>
{
    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    using var cmd = conn.CreateCommand();
    cmd.CommandText = @"SELECT CollectorId, Username, FullName, Phone, Branch, AccessLevel, AssignedLocations, IsActive 
                        FROM Collectors 
                        WHERE (LOWER(Username) = LOWER(@u) OR LOWER(CollectorId) = LOWER(@u)) 
                          AND PasswordHash = @p 
                          AND IsActive = 1";
    cmd.Parameters.AddWithValue("@u", req.Username.Trim());
    cmd.Parameters.AddWithValue("@p", req.Password.Trim());

    using var reader = await cmd.ExecuteReaderAsync();
    if (await reader.ReadAsync())
    {
        return Results.Ok(new
        {
            success = true,
            collectorId = reader["CollectorId"].ToString(),
            username = reader["Username"].ToString(),
            fullName = reader["FullName"].ToString(),
            phone = reader["Phone"]?.ToString() ?? "",
            branch = reader["Branch"].ToString(),
            accessLevel = reader["AccessLevel"]?.ToString() ?? "Collector",
            assignedLocations = reader["AssignedLocations"]?.ToString() ?? "ALL",
            sessionTimeoutMinutes = 60
        });
    }

    return Results.Unauthorized();
});

// User Management Endpoints (Section for Settings)
app.MapGet("/api/users", async (IMemoryCache cache) =>
{
    if (cache.TryGetValue("users_all", out List<object>? cached) && cached != null)
    {
        return Results.Ok(cached);
    }

    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();
    using var cmd = conn.CreateCommand();
    cmd.CommandText = @"SELECT CollectorId, Username, FullName, Phone, Branch, AccessLevel, AssignedLocations, IsActive, CreatedAt 
                        FROM Collectors 
                        ORDER BY CreatedAt DESC";
    using var reader = await cmd.ExecuteReaderAsync();
    var users = new List<object>();
    while (await reader.ReadAsync())
    {
        users.Add(new
        {
            collectorId = reader["CollectorId"].ToString(),
            username = reader["Username"].ToString(),
            fullName = reader["FullName"].ToString(),
            phone = reader["Phone"]?.ToString() ?? "",
            branch = reader["Branch"].ToString(),
            accessLevel = reader["AccessLevel"]?.ToString() ?? "Collector",
            assignedLocations = reader["AssignedLocations"]?.ToString() ?? "ALL",
            isActive = Convert.ToBoolean(reader["IsActive"]),
            createdAt = reader["CreatedAt"]
        });
    }

    cache.Set("users_all", users, TimeSpan.FromMinutes(5));
    return Results.Ok(users);
});

app.MapPost("/api/users", async (CreateUserRequest req, IMemoryCache cache) =>
{
    if (string.IsNullOrWhiteSpace(req.Username) || string.IsNullOrWhiteSpace(req.Password))
    {
        return Results.BadRequest(new { error = "Username and Password are required." });
    }

    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    string colId = string.IsNullOrWhiteSpace(req.CollectorId) 
        ? ("COL-" + req.Username.Trim().ToUpper()) 
        : req.CollectorId.Trim().ToUpper();

    if (colId.Length > 20)
    {
        return Results.BadRequest(new { error = "User ID / Collector ID cannot exceed 20 characters." });
    }

    // Check if username or collectorId already exists
    using (var checkCmd = conn.CreateCommand())
    {
        checkCmd.CommandText = "SELECT COUNT(1) FROM Collectors WHERE LOWER(Username) = LOWER(@u) OR LOWER(CollectorId) = LOWER(@c)";
        checkCmd.Parameters.AddWithValue("@u", req.Username.Trim());
        checkCmd.Parameters.AddWithValue("@c", colId);
        int exists = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
        if (exists > 0)
        {
            return Results.BadRequest(new { error = $"Username '{req.Username}' or Collector ID '{colId}' already exists." });
        }
    }

    string accessLevel = string.IsNullOrWhiteSpace(req.AccessLevel) ? "Collector" : req.AccessLevel.Trim();
    string assignedLocations = string.IsNullOrWhiteSpace(req.AssignedLocations) ? "ALL" : req.AssignedLocations.Trim();

    using var insertCmd = conn.CreateCommand();
    insertCmd.CommandText = @"
        INSERT INTO Collectors (CollectorId, Username, PasswordHash, FullName, Phone, Branch, AccessLevel, AssignedLocations, IsActive, CreatedAt)
        VALUES (@cId, @u, @p, @name, @phone, @branch, @role, @locs, 1, GETDATE())";
    insertCmd.Parameters.AddWithValue("@cId", colId);
    insertCmd.Parameters.AddWithValue("@u", req.Username.Trim());
    insertCmd.Parameters.AddWithValue("@p", req.Password.Trim());
    insertCmd.Parameters.AddWithValue("@name", string.IsNullOrWhiteSpace(req.FullName) ? req.Username.Trim() : req.FullName.Trim());
    insertCmd.Parameters.AddWithValue("@phone", (object?)req.Phone?.Trim() ?? DBNull.Value);
    insertCmd.Parameters.AddWithValue("@branch", string.IsNullOrWhiteSpace(req.Branch) ? "Jay Pharma" : req.Branch.Trim());
    insertCmd.Parameters.AddWithValue("@role", accessLevel);
    insertCmd.Parameters.AddWithValue("@locs", assignedLocations);

    await insertCmd.ExecuteNonQueryAsync();

    cache.Remove("users_all");
    return Results.Ok(new { success = true, message = "User created successfully.", collectorId = colId });
});

app.MapDelete("/api/users/{id}", async (string id, IMemoryCache cache) =>
{
    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();
    using var cmd = conn.CreateCommand();
    cmd.CommandText = "UPDATE Collectors SET IsActive = CASE WHEN IsActive = 1 THEN 0 ELSE 1 END WHERE CollectorId = @id";
    cmd.Parameters.AddWithValue("@id", id);
    await cmd.ExecuteNonQueryAsync();

    cache.Remove("users_all");
    return Results.Ok(new { success = true });
});

app.MapPut("/api/users/{id}/locations", async (string id, UpdateLocationsRequest req, IMemoryCache cache) =>
{
    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();
    using var cmd = conn.CreateCommand();
    cmd.CommandText = "UPDATE Collectors SET AssignedLocations = @locs WHERE CollectorId = @id";
    cmd.Parameters.AddWithValue("@id", id);
    cmd.Parameters.AddWithValue("@locs", string.IsNullOrWhiteSpace(req.AssignedLocations) ? "ALL" : req.AssignedLocations.Trim());
    await cmd.ExecuteNonQueryAsync();

    cache.Remove("users_all");
    return Results.Ok(new { success = true });
});

// 3. Customers List & Search (Realtime from Main ERP with Fallback)
app.MapGet("/api/customers", async (string? search, IMemoryCache cache) =>
{
    bool isAll = string.IsNullOrWhiteSpace(search);
    if (isAll && cache.TryGetValue("customers_all", out List<object>? cachedList) && cachedList != null)
    {
        return Results.Ok(cachedList);
    }

    // Try Realtime from Main ERP
    try
    {
        var mainErpConnStr = await GetMainErpConnectionStringAsync();
        using var erpConn = new SqlConnection(mainErpConnStr);
        await erpConn.OpenAsync();

        using var cmd = erpConn.CreateCommand();
        if (string.IsNullOrWhiteSpace(search))
        {
            cmd.CommandText = @"
                WITH InvWithApp AS (
                    SELECT 
                        i.InvNo,
                        i.CCode,
                        i.CName,
                        i.Branch,
                        i.InVal,
                        (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) AS EffectiveSetAmt,
                        (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) AS EffectiveBalance,
                        CASE 
                            WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) <= 0.01 THEN 'Settled'
                            WHEN (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) > 0 THEN 'Part Settled'
                            ELSE LTRIM(RTRIM(ISNULL(i.SettleType, 'Pending')))
                        END AS EffectiveSettleType
                    FROM dbo.Invoice i
                    LEFT JOIN (
                        SELECT InvNo, SUM(ISNULL(SetAmt, 0)) AS AppSettled
                        FROM dbo.AppInvoice
                        GROUP BY InvNo
                    ) app ON i.InvNo = app.InvNo
                )
                SELECT 
                    CCode AS CustomerCode, 
                    CName AS CustomerName, 
                    ISNULL(Branch, 'Jay Pharma') AS Branch,
                    SUM(CASE WHEN EffectiveSettleType = 'Pending' AND EffectiveBalance > 0.01 THEN 1 ELSE 0 END) AS PendingCount,
                    SUM(CASE WHEN EffectiveSettleType = 'Part Settled' AND EffectiveBalance > 0.01 THEN 1 ELSE 0 END) AS PartSettledCount,
                    COUNT(CASE WHEN EffectiveBalance > 0.01 THEN InvNo ELSE NULL END) AS TotalDueInvoiceCount,
                    SUM(CASE WHEN EffectiveBalance > 0.01 THEN EffectiveBalance ELSE 0 END) AS TotalOutstanding
                FROM InvWithApp
                GROUP BY CCode, CName, Branch
                ORDER BY CName ASC";
        }
        else
        {
            cmd.CommandText = @"
                WITH InvWithApp AS (
                    SELECT 
                        i.InvNo,
                        i.CCode,
                        i.CName,
                        i.Branch,
                        i.InVal,
                        (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) AS EffectiveSetAmt,
                        (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) AS EffectiveBalance,
                        CASE 
                            WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) <= 0.01 THEN 'Settled'
                            WHEN (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) > 0 THEN 'Part Settled'
                            ELSE LTRIM(RTRIM(ISNULL(i.SettleType, 'Pending')))
                        END AS EffectiveSettleType
                    FROM dbo.Invoice i
                    LEFT JOIN (
                        SELECT InvNo, SUM(ISNULL(SetAmt, 0)) AS AppSettled
                        FROM dbo.AppInvoice
                        GROUP BY InvNo
                    ) app ON i.InvNo = app.InvNo
                )
                SELECT 
                    CCode AS CustomerCode, 
                    CName AS CustomerName, 
                    ISNULL(Branch, 'Jay Pharma') AS Branch,
                    SUM(CASE WHEN EffectiveSettleType = 'Pending' AND EffectiveBalance > 0.01 THEN 1 ELSE 0 END) AS PendingCount,
                    SUM(CASE WHEN EffectiveSettleType = 'Part Settled' AND EffectiveBalance > 0.01 THEN 1 ELSE 0 END) AS PartSettledCount,
                    COUNT(CASE WHEN EffectiveBalance > 0.01 THEN InvNo ELSE NULL END) AS TotalDueInvoiceCount,
                    SUM(CASE WHEN EffectiveBalance > 0.01 THEN EffectiveBalance ELSE 0 END) AS TotalOutstanding
                FROM InvWithApp
                WHERE (CName LIKE @q OR CAST(CCode AS VARCHAR(30)) LIKE @q)
                GROUP BY CCode, CName, Branch
                ORDER BY CName ASC";
            cmd.Parameters.AddWithValue("@q", $"%{search.Trim()}%");
        }

        var list = new List<object>();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var cName = reader["CustomerName"]?.ToString() ?? "";
            var branch = reader["Branch"]?.ToString() ?? "Jay Pharma";
            string town = branch;
            if (cName.Contains("-"))
            {
                var parts = cName.Split('-');
                if (parts.Length > 1)
                {
                    var t = parts[^1].Trim();
                    if (!string.IsNullOrWhiteSpace(t)) town = t;
                }
            }

            list.Add(new
            {
                code = reader["CustomerCode"].ToString(),
                name = cName,
                address = town,
                phone = "",
                email = "",
                town = town,
                creditLimit = 3000000.0,
                totalOutstanding = Convert.ToDouble(reader["TotalOutstanding"]),
                pendingInvoiceCount = Convert.ToInt32(reader["TotalDueInvoiceCount"]),
                pendingCount = Convert.ToInt32(reader["PendingCount"]),
                partSettledCount = Convert.ToInt32(reader["PartSettledCount"])
            });
        }

        if (list.Count > 0)
        {
            if (isAll)
            {
                cache.Set("customers_all", list, TimeSpan.FromMinutes(2));
            }
            return Results.Ok(list);
        }
    }
    catch (Exception)
    {
        // Fallback to JayPharmaApp if Main ERP is temporarily unreachable
    }

    // Fallback: JayPharmaApp
    using var appConn = new SqlConnection(connectionString);
    await appConn.OpenAsync();

    using var appCmd = appConn.CreateCommand();
    if (string.IsNullOrWhiteSpace(search))
    {
        appCmd.CommandText = "SELECT CustomerCode, CustomerName, Address, Phone, Email, Town, CreditLimit FROM Customers WHERE IsActive = 1 ORDER BY CustomerName";
    }
    else
    {
        appCmd.CommandText = @"SELECT CustomerCode, CustomerName, Address, Phone, Email, Town, CreditLimit 
                            FROM Customers 
                            WHERE IsActive = 1 AND (CustomerCode LIKE @q OR CustomerName LIKE @q OR Town LIKE @q)
                            ORDER BY CustomerName";
        appCmd.Parameters.AddWithValue("@q", $"%{search.Trim()}%");
    }

    var fallbackList = new List<object>();
    using var appReader = await appCmd.ExecuteReaderAsync();
    while (await appReader.ReadAsync())
    {
        fallbackList.Add(new
        {
            code = appReader["CustomerCode"].ToString(),
            name = appReader["CustomerName"].ToString(),
            address = appReader["Address"].ToString(),
            phone = appReader["Phone"].ToString(),
            email = appReader["Email"]?.ToString() ?? "",
            town = appReader["Town"]?.ToString() ?? "",
            creditLimit = Convert.ToDouble(appReader["CreditLimit"]),
            totalOutstanding = 0.0,
            pendingInvoiceCount = 0,
            pendingCount = 0,
            partSettledCount = 0
        });
    }

    if (isAll && fallbackList.Count > 0)
    {
        cache.Set("customers_all", fallbackList, TimeSpan.FromMinutes(1));
    }
    return Results.Ok(fallbackList);
});

// 4. Invoices for a specific Customer (Realtime from Main ERP with Fallback)
app.MapGet("/api/customers/{code}/invoices", async (string code) =>
{
    // Try Realtime from Main ERP
    try
    {
        var mainErpConnStr = await GetMainErpConnectionStringAsync();
        using var erpConn = new SqlConnection(mainErpConnStr);
        await erpConn.OpenAsync();

        using var cmd = erpConn.CreateCommand();
        if (int.TryParse(code, out int cCodeInt))
        {
            cmd.CommandText = @"
                SELECT 
                    i.InvNo, 
                    i.Date, 
                    i.InVal, 
                    (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) AS SetAmt, 
                    CASE 
                        WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) > 0 
                        THEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) 
                        ELSE 0.0 
                    END AS OutstandingBalance, 
                    CASE 
                        WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) <= 0.01 THEN 'Settled'
                        WHEN (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) > 0 THEN 'Part Settled'
                        ELSE LTRIM(RTRIM(ISNULL(i.SettleType, 'Pending')))
                    END AS SettleType, 
                    i.CrPeriod
                FROM dbo.Invoice i
                LEFT JOIN (
                    SELECT InvNo, SUM(ISNULL(SetAmt, 0)) AS AppSettled 
                    FROM dbo.AppInvoice 
                    GROUP BY InvNo
                ) app ON i.InvNo = app.InvNo
                WHERE i.CCode = @c
                ORDER BY 
                    CASE 
                        WHEN (CASE 
                                WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) <= 0.01 THEN 'Settled'
                                WHEN (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) > 0 THEN 'Part Settled'
                                ELSE LTRIM(RTRIM(ISNULL(i.SettleType, 'Pending')))
                              END) IN ('Pending', 'Part Settled') 
                             AND (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) > 0.01 
                        THEN 0 ELSE 1 
                    END ASC,
                    CASE 
                        WHEN (CASE 
                                WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) <= 0.01 THEN 'Settled'
                                WHEN (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) > 0 THEN 'Part Settled'
                                ELSE LTRIM(RTRIM(ISNULL(i.SettleType, 'Pending')))
                              END) IN ('Pending', 'Part Settled') 
                             AND (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) > 0.01 
                        THEN i.Date 
                    END ASC,
                    i.Date DESC";
            cmd.Parameters.AddWithValue("@c", cCodeInt);
        }
        else
        {
            cmd.CommandText = @"
                SELECT 
                    i.InvNo, 
                    i.Date, 
                    i.InVal, 
                    (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) AS SetAmt, 
                    CASE 
                        WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) > 0 
                        THEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) 
                        ELSE 0.0 
                    END AS OutstandingBalance, 
                    CASE 
                        WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) <= 0.01 THEN 'Settled'
                        WHEN (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) > 0 THEN 'Part Settled'
                        ELSE LTRIM(RTRIM(ISNULL(i.SettleType, 'Pending')))
                    END AS SettleType, 
                    i.CrPeriod
                FROM dbo.Invoice i
                LEFT JOIN (
                    SELECT InvNo, SUM(ISNULL(SetAmt, 0)) AS AppSettled 
                    FROM dbo.AppInvoice 
                    GROUP BY InvNo
                ) app ON i.InvNo = app.InvNo
                ORDER BY 
                    CASE 
                        WHEN (CASE 
                                WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) <= 0.01 THEN 'Settled'
                                WHEN (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) > 0 THEN 'Part Settled'
                                ELSE LTRIM(RTRIM(ISNULL(i.SettleType, 'Pending')))
                              END) IN ('Pending', 'Part Settled') 
                             AND (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) > 0.01 
                        THEN 0 ELSE 1 
                    END ASC,
                    CASE 
                        WHEN (CASE 
                                WHEN (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) <= 0.01 THEN 'Settled'
                                WHEN (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0)) > 0 THEN 'Part Settled'
                                ELSE LTRIM(RTRIM(ISNULL(i.SettleType, 'Pending')))
                              END) IN ('Pending', 'Part Settled') 
                             AND (i.InVal - (ISNULL(i.SetAmt, 0) + ISNULL(app.AppSettled, 0))) > 0.01 
                        THEN i.Date 
                    END ASC,
                    i.Date DESC";
        }

        var list = new List<object>();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var invDate = Convert.ToDateTime(reader["Date"]);
            var ageDays = (DateTime.Now.Date - invDate.Date).Days;

            list.Add(new
            {
                invoiceNo = reader["InvNo"].ToString(),
                customerCode = code,
                invoiceDate = invDate.ToString("yyyy-MM-dd"),
                deliveryDate = invDate.ToString("yyyy-MM-dd"),
                deliveryAgeDays = ageDays,
                totalAmount = Convert.ToDouble(reader["InVal"]),
                setAmt = Convert.ToDouble(reader["SetAmt"]),
                outstandingBalance = Convert.ToDouble(reader["OutstandingBalance"]),
                status = reader["SettleType"].ToString()
            });
        }

        if (list.Count > 0)
        {
            return Results.Ok(list);
        }
    }
    catch (Exception)
    {
        // Fallback to JayPharmaApp
    }

    // Fallback: JayPharmaApp
    using var appConn = new SqlConnection(connectionString);
    await appConn.OpenAsync();

    using var appCmd = appConn.CreateCommand();
    appCmd.CommandText = @"SELECT InvoiceNo, CustomerCode, InvoiceDate, DeliveryDate, TotalAmount, OutstandingBalance, Status
                        FROM Invoices 
                        WHERE CustomerCode = @c AND OutstandingBalance > 0
                        ORDER BY DeliveryDate ASC";
    appCmd.Parameters.AddWithValue("@c", code);

    var fallbackList = new List<object>();
    using var appReader = await appCmd.ExecuteReaderAsync();
    while (await appReader.ReadAsync())
    {
        var delDate = Convert.ToDateTime(appReader["DeliveryDate"]);
        var ageDays = (DateTime.Now.Date - delDate.Date).Days;

        fallbackList.Add(new
        {
            invoiceNo = appReader["InvoiceNo"].ToString(),
            customerCode = appReader["CustomerCode"].ToString(),
            invoiceDate = Convert.ToDateTime(appReader["InvoiceDate"]).ToString("yyyy-MM-dd"),
            deliveryDate = delDate.ToString("yyyy-MM-dd"),
            deliveryAgeDays = ageDays,
            totalAmount = Convert.ToDouble(appReader["TotalAmount"]),
            outstandingBalance = Convert.ToDouble(appReader["OutstandingBalance"]),
            status = appReader["Status"].ToString()
        });
    }

    return Results.Ok(fallbackList);
});

// 5. Unique Manual Receipt Number Validation (Across Both Databases)
app.MapGet("/api/receipts/verify-unique/{receiptNo}", async (string receiptNo) =>
{
    var trimmed = receiptNo.Trim();
    bool isUnique = true;

    // Check JayPharmaApp Receipts table
    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT COUNT(1) FROM Receipts WHERE UPPER(LTRIM(RTRIM(ManualReceiptNo))) = UPPER(@r)";
        cmd.Parameters.AddWithValue("@r", trimmed);
        int count = Convert.ToInt32(await cmd.ExecuteScalarAsync());
        if (count > 0) isUnique = false;
    }
    catch { }

    // Check Main ERP DPay table if numeric receipt number
    if (isUnique)
    {
        var numStr = Regex.Match(trimmed, @"\d+").Value;
        if (int.TryParse(numStr, out int mrNo))
        {
            try
            {
                var mainErpConnStr = await GetMainErpConnectionStringAsync();
                using var erpConn = new SqlConnection(mainErpConnStr);
                await erpConn.OpenAsync();
                using var erpCmd = erpConn.CreateCommand();
                erpCmd.CommandText = "SELECT COUNT(1) FROM DPay WHERE MRNo = @mr";
                erpCmd.Parameters.AddWithValue("@mr", mrNo);
                int count = Convert.ToInt32(await erpCmd.ExecuteScalarAsync());
                if (count > 0) isUnique = false;
            }
            catch { }
        }
    }

    return Results.Ok(new { receiptNo = trimmed, isUnique });
});

// 5b. Get Next Suggested Manual Receipt Number
app.MapGet("/api/receipts/next-number", async (string? prefix) =>
{
    string p = string.IsNullOrWhiteSpace(prefix) ? "MR" : prefix.Trim().ToUpper();
    if (p.StartsWith("COL-") && p.Length > 4) p = p.Substring(4).Trim();
    if (string.IsNullOrWhiteSpace(p)) p = "MR";

    int maxNum = 26450;
    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT ManualReceiptNo FROM Receipts";
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var match = Regex.Match(reader["ManualReceiptNo"].ToString() ?? "", @"\d+");
            if (match.Success && int.TryParse(match.Value, out int n) && n > maxNum)
                maxNum = n;
        }
    }
    catch { }

    try
    {
        var mainErpConnStr = await GetMainErpConnectionStringAsync();
        using var erpConn = new SqlConnection(mainErpConnStr);
        await erpConn.OpenAsync();
        using var erpCmd = erpConn.CreateCommand();
        erpCmd.CommandText = "SELECT Other1 FROM AppInvoice";
        using var erpReader = await erpCmd.ExecuteReaderAsync();
        while (await erpReader.ReadAsync())
        {
            var match = Regex.Match(erpReader["Other1"].ToString() ?? "", @"\d+");
            if (match.Success && int.TryParse(match.Value, out int n) && n > maxNum)
                maxNum = n;
        }
    }
    catch { }

    int nextNum = maxNum + 1;
    string formatted = $"{p}-{nextNum.ToString().PadLeft(6, '0')}";
    return Results.Ok(new { nextReceiptNo = formatted });
});

// 5c. Get All Realtime Receipts from JayPharmaApp
app.MapGet("/api/receipts", async (IMemoryCache cache) =>
{
    if (cache.TryGetValue("receipts_all", out List<object>? cached) && cached != null)
    {
        return Results.Ok(cached);
    }

    var list = new List<object>();
    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            SELECT TOP 200 
                r.ManualReceiptNo, r.CustomerCode, r.CustomerName, r.CustomerAddress, r.CustomerPhone,
                r.PaymentMethod, r.Bank, r.Branch, r.ChequeNumber, r.ChequeDate, r.TotalAmount,
                r.Comments, r.IsAdvancePayment, r.CollectorId, r.CollectorName,
                r.Latitude, r.Longitude, r.LocationAddress, r.CreatedAt
            FROM Receipts r
            ORDER BY r.CreatedAt DESC";

        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            list.Add(new
            {
                manualReceiptNo = reader["ManualReceiptNo"].ToString(),
                customerCode = reader["CustomerCode"].ToString(),
                customerName = reader["CustomerName"].ToString(),
                customerAddress = reader["CustomerAddress"].ToString(),
                customerPhone = reader["CustomerPhone"] != DBNull.Value ? reader["CustomerPhone"].ToString() : "",
                paymentMethod = reader["PaymentMethod"].ToString()?.ToLower() ?? "cash",
                bank = reader["Bank"] != DBNull.Value ? reader["Bank"].ToString() : null,
                branch = reader["Branch"] != DBNull.Value ? reader["Branch"].ToString() : null,
                chequeNumber = reader["ChequeNumber"] != DBNull.Value ? reader["ChequeNumber"].ToString() : null,
                chequeDate = reader["ChequeDate"] != DBNull.Value ? ((DateTime)reader["ChequeDate"]).ToString("o") : null,
                totalAmount = Convert.ToDouble(reader["TotalAmount"]),
                comments = reader["Comments"] != DBNull.Value ? reader["Comments"].ToString() : "",
                isAdvancePayment = Convert.ToBoolean(reader["IsAdvancePayment"]),
                collectorId = reader["CollectorId"].ToString(),
                collectorName = reader["CollectorName"].ToString(),
                latitude = reader["Latitude"] != DBNull.Value ? Convert.ToDouble(reader["Latitude"]) : 0.0,
                longitude = reader["Longitude"] != DBNull.Value ? Convert.ToDouble(reader["Longitude"]) : 0.0,
                locationAddress = reader["LocationAddress"] != DBNull.Value ? reader["LocationAddress"].ToString() : "",
                createdAt = ((DateTime)reader["CreatedAt"]).ToString("o")
            });
        }
        cache.Set("receipts_all", list, TimeSpan.FromSeconds(60));
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[GET /api/receipts Error]: {ex.Message}");
    }
    return Results.Ok(list);
});

// 6. Record Customer Payment & Generate Receipt (Realtime in Both Databases)
app.MapPost("/api/receipts", async (CreateReceiptDto dto, IMemoryCache cache) =>
{
    Console.WriteLine($"[POST /api/receipts] Incoming receipt: '{dto.ManualReceiptNo}', Method: '{dto.PaymentMethod}', Amount: Rs. {dto.TotalAmount}, Customer: '{dto.CustomerCode}'");

    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();
    using var tx = conn.BeginTransaction();

    try
    {
        // 1. Check uniqueness of Manual Receipt No (Section 6)
        using (var checkCmd = conn.CreateCommand())
        {
            checkCmd.Transaction = tx;
            checkCmd.CommandText = "SELECT COUNT(1) FROM Receipts WHERE UPPER(LTRIM(RTRIM(ManualReceiptNo))) = UPPER(@r)";
            checkCmd.Parameters.AddWithValue("@r", dto.ManualReceiptNo.Trim());
            int exists = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
            if (exists > 0)
            {
                tx.Rollback();
                Console.WriteLine($"[POST /api/receipts REJECTED]: Receipt '{dto.ManualReceiptNo}' is already used in JayPharmaApp Receipts!");
                return Results.BadRequest(new { error = $"Manual receipt number '{dto.ManualReceiptNo}' is already used. Must be unique." });
            }
        }

        // 2. Ensure Collector & Customer exist in JayPharmaApp (to satisfy FK constraints)
        using (var ensureCmd = conn.CreateCommand())
        {
            ensureCmd.Transaction = tx;
            ensureCmd.CommandText = @"
                IF NOT EXISTS (SELECT 1 FROM Collectors WHERE CollectorId = @colId)
                BEGIN
                    INSERT INTO Collectors (CollectorId, Username, PasswordHash, FullName, Branch, IsActive, CreatedAt)
                    VALUES (@colId, @colId, 'HASH_AUTOGEN', @colName, 'Jay Pharma', 1, GETDATE());
                END

                IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerCode = @cCode)
                BEGIN
                    INSERT INTO Customers (CustomerCode, CustomerName, Address, Phone, Email, Town, CreditLimit, IsActive, CreatedAt)
                    VALUES (@cCode, @cName, @cAddr, '', '', 'Jay Pharma', 3000000.0, 1, GETDATE());
                END";
            ensureCmd.Parameters.AddWithValue("@colId", (object?)dto.CollectorId ?? "COL-042");
            ensureCmd.Parameters.AddWithValue("@colName", (object?)dto.CollectorName ?? "Collector");
            ensureCmd.Parameters.AddWithValue("@cCode", (object?)dto.CustomerCode ?? "");
            ensureCmd.Parameters.AddWithValue("@cName", (object?)dto.CustomerName ?? "");
            ensureCmd.Parameters.AddWithValue("@cAddr", (object?)dto.CustomerAddress ?? "");
            await ensureCmd.ExecuteNonQueryAsync();
        }

        // 3. Insert Receipt Header in JayPharmaApp
        using (var insertCmd = conn.CreateCommand())
        {
            insertCmd.Transaction = tx;
            insertCmd.CommandText = @"
                INSERT INTO Receipts 
                (ManualReceiptNo, CustomerCode, CustomerName, CustomerAddress, CustomerPhone, PaymentMethod, 
                 Bank, Branch, ChequeNumber, ChequeDate, TotalAmount, Comments, IsAdvancePayment, 
                 CollectorId, CollectorName, Latitude, Longitude, LocationAddress, CreatedAt, SyncStatus)
                VALUES 
                (@rNo, @cCode, @cName, @cAddr, @cPhone, @method, 
                 @bank, @branch, @chqNo, @chqDate, @amount, @comments, @isAdv, 
                 @colId, @colName, @lat, @lng, @locAddr, @createdAt, 'REALTIME')";

            insertCmd.Parameters.AddWithValue("@rNo", dto.ManualReceiptNo.Trim());
            insertCmd.Parameters.AddWithValue("@cCode", (object?)dto.CustomerCode ?? "");
            insertCmd.Parameters.AddWithValue("@cName", (object?)dto.CustomerName ?? "");
            insertCmd.Parameters.AddWithValue("@cAddr", (object?)dto.CustomerAddress ?? "");
            insertCmd.Parameters.AddWithValue("@cPhone", (object?)dto.CustomerPhone ?? DBNull.Value);
            insertCmd.Parameters.AddWithValue("@method", (object?)dto.PaymentMethod?.ToUpper() ?? "CASH");
            insertCmd.Parameters.AddWithValue("@bank", (object?)dto.Bank ?? DBNull.Value);
            insertCmd.Parameters.AddWithValue("@branch", (object?)dto.Branch ?? DBNull.Value);
            insertCmd.Parameters.AddWithValue("@chqNo", (object?)dto.ChequeNumber ?? DBNull.Value);
            insertCmd.Parameters.AddWithValue("@chqDate", dto.ChequeDate.HasValue ? (object)dto.ChequeDate.Value.Date : DBNull.Value);
            insertCmd.Parameters.AddWithValue("@amount", dto.TotalAmount);
            insertCmd.Parameters.AddWithValue("@comments", (object?)dto.Comments ?? DBNull.Value);
            insertCmd.Parameters.AddWithValue("@isAdv", dto.AllocatedInvoices == null || dto.AllocatedInvoices.Count == 0);
            insertCmd.Parameters.AddWithValue("@colId", (object?)dto.CollectorId ?? "COL-DEFAULT");
            insertCmd.Parameters.AddWithValue("@colName", (object?)dto.CollectorName ?? "Collector");
            string headerLocation = !string.IsNullOrWhiteSpace(dto.LocationAddress)
                ? dto.LocationAddress.Trim()
                : (dto.Latitude != 0 && dto.Longitude != 0
                    ? $"GPS: {dto.Latitude:F6}, {dto.Longitude:F6}"
                    : (!string.IsNullOrWhiteSpace(dto.CustomerAddress) 
                        ? dto.CustomerAddress.Trim() 
                        : "Galle Road, Colombo 03, Western Province, Sri Lanka"));

            insertCmd.Parameters.AddWithValue("@lat", dto.Latitude != 0 ? dto.Latitude : 6.927079);
            insertCmd.Parameters.AddWithValue("@lng", dto.Longitude != 0 ? dto.Longitude : 79.861244);
            insertCmd.Parameters.AddWithValue("@locAddr", headerLocation);
            insertCmd.Parameters.AddWithValue("@createdAt", DateTime.Now);

            await insertCmd.ExecuteNonQueryAsync();
        }

        // 4. Insert Allocated Invoices in JayPharmaApp
        if (dto.AllocatedInvoices != null)
        {
            for (int i = 0; i < dto.AllocatedInvoices.Count; i++)
            {
                var item = dto.AllocatedInvoices[i];

                using var itemCmd = conn.CreateCommand();
                itemCmd.Transaction = tx;
                itemCmd.CommandText = @"
                    IF NOT EXISTS (SELECT 1 FROM Invoices WHERE InvoiceNo = @invNo)
                    BEGIN
                        INSERT INTO Invoices (InvoiceNo, CustomerCode, InvoiceDate, DeliveryDate, TotalAmount, OutstandingBalance, Status, CreatedAt)
                        VALUES (@invNo, @cCode, @invDate, @invDate, @invAmt, @invAmt, 'PENDING', GETDATE());
                    END

                    INSERT INTO ReceiptInvoices 
                    (ManualReceiptNo, ItemIndex, InvoiceNo, InvoiceDate, InvoiceAmount, AmountSettled, RemainingBalance)
                    VALUES 
                    (@rNo, @idx, @invNo, @invDate, @invAmt, @settled, @remBal);

                    UPDATE Invoices 
                    SET OutstandingBalance = CASE 
                        WHEN OutstandingBalance - @settled < 0 THEN 0 
                        ELSE OutstandingBalance - @settled 
                    END,
                    Status = CASE 
                        WHEN OutstandingBalance - @settled <= 0.01 THEN 'SETTLED' 
                        ELSE 'PARTIAL' 
                    END
                    WHERE InvoiceNo = @invNo;";

                itemCmd.Parameters.AddWithValue("@cCode", (object?)dto.CustomerCode ?? "");
                itemCmd.Parameters.AddWithValue("@rNo", dto.ManualReceiptNo.Trim());
                itemCmd.Parameters.AddWithValue("@idx", i + 1);
                itemCmd.Parameters.AddWithValue("@invNo", item.InvoiceNo);
                itemCmd.Parameters.AddWithValue("@invDate", item.InvoiceDate);
                itemCmd.Parameters.AddWithValue("@invAmt", item.InvoiceAmount);
                itemCmd.Parameters.AddWithValue("@settled", item.AmountSettled);
                itemCmd.Parameters.AddWithValue("@remBal", item.RemainingBalance);

                await itemCmd.ExecuteNonQueryAsync();
            }
        }

        // 5. Record Audit Log in JayPharmaApp
        using (var auditCmd = conn.CreateCommand())
        {
            auditCmd.Transaction = tx;
            auditCmd.CommandText = @"
                INSERT INTO AuditLogs (Action, ReferenceNo, CollectorId, CollectorName, Details, Timestamp)
                VALUES ('CREATE_RECEIPT', @ref, @cId, @cName, @details, GETDATE())";
            auditCmd.Parameters.AddWithValue("@ref", dto.ManualReceiptNo.Trim());
            auditCmd.Parameters.AddWithValue("@cId", dto.CollectorId);
            auditCmd.Parameters.AddWithValue("@cName", dto.CollectorName);
            auditCmd.Parameters.AddWithValue("@details", $"Created receipt for {dto.CustomerName} - Rs. {dto.TotalAmount} ({dto.PaymentMethod})");
            await auditCmd.ExecuteNonQueryAsync();
        }

        tx.Commit();

        // 5. REALTIME SYNC TO MAIN ERP (from MainDatabaseConfig)
        try
        {
            var mainErpConnStr = await GetMainErpConnectionStringAsync();
            using var erpConn = new SqlConnection(mainErpConnStr);
            await erpConn.OpenAsync();

            int numericReceiptNo = 0;
            var numMatch = Regex.Match(dto.ManualReceiptNo, @"\d+");
            if (numMatch.Success) int.TryParse(numMatch.Value, out numericReceiptNo);

            int numericCustCode = 0;
            int.TryParse(dto.CustomerCode, out numericCustCode);

            // Ensure GPS location / address is never empty for any payment method (Cash or Cheque)
            string resolvedLocation = !string.IsNullOrWhiteSpace(dto.LocationAddress)
                ? dto.LocationAddress.Trim()
                : (dto.Latitude != 0 && dto.Longitude != 0
                    ? $"GPS: {dto.Latitude:F6}, {dto.Longitude:F6}"
                    : (!string.IsNullOrWhiteSpace(dto.CustomerAddress) 
                        ? dto.CustomerAddress.Trim() 
                        : "Galle Road, Colombo 03, Western Province, Sri Lanka"));
            if (resolvedLocation.Length > 250) resolvedLocation = resolvedLocation.Substring(0, 250);

            // ChequeBranch or location fallback
            string resolvedBranch = !string.IsNullOrWhiteSpace(dto.Branch) 
                ? dto.Branch.Trim() 
                : (resolvedLocation.Length > 100 ? resolvedLocation.Substring(0, 100) : resolvedLocation);

            if (dto.AllocatedInvoices != null && dto.AllocatedInvoices.Count > 0)
            {
                foreach (var item in dto.AllocatedInvoices)
                {
                    if (int.TryParse(item.InvoiceNo, out int invNoInt))
                    {
                        // 1. Write to AppInvoice in Main ERP (DO NOT TOUCH dbo.Invoice!)
                        using var appInvCmd = erpConn.CreateCommand();
                        appInvCmd.CommandText = @"
                            INSERT INTO dbo.AppInvoice 
                            (InvNo, Date, CCode, CName, InVal, SetAmt, Branch, SettleType, CrPeriod, DOther1, DOther2, Other1, Other2,
                             PayType, Bank, ChequeBranch, ChequeNo, ChequeDate, Details1, Details2, Details3)
                            VALUES 
                            (@inv, @date, @cCode, @cName, @inVal, @setAmt, 'Jay Pharma', @settleType, 0, @remBal, @totAmt, @mrNo, @details,
                             @payType, @bank, @chqBranch, @chqNo, @chqDate, @det1, @det2, @det3);";

                        appInvCmd.Parameters.AddWithValue("@inv", invNoInt);
                        appInvCmd.Parameters.AddWithValue("@date", DateTime.Now.Date);
                        appInvCmd.Parameters.AddWithValue("@cCode", numericCustCode);
                        appInvCmd.Parameters.AddWithValue("@cName", dto.CustomerName?.Trim() ?? "");
                        appInvCmd.Parameters.AddWithValue("@inVal", item.InvoiceAmount);
                        appInvCmd.Parameters.AddWithValue("@setAmt", item.AmountSettled);
                        appInvCmd.Parameters.AddWithValue("@settleType", item.RemainingBalance <= 0.01 ? "Settled" : "Part Settled");
                        appInvCmd.Parameters.AddWithValue("@remBal", item.RemainingBalance);
                        appInvCmd.Parameters.AddWithValue("@totAmt", dto.TotalAmount);
                        appInvCmd.Parameters.AddWithValue("@mrNo", dto.ManualReceiptNo?.Trim() ?? "");
                        appInvCmd.Parameters.AddWithValue("@details", $"Collector: {dto.CollectorName ?? ""}");

                        // New columns (avoid null values as requested)
                        appInvCmd.Parameters.AddWithValue("@payType", string.IsNullOrWhiteSpace(dto.PaymentMethod) ? "CASH" : dto.PaymentMethod.Trim());
                        appInvCmd.Parameters.AddWithValue("@bank", dto.Bank?.Trim() ?? "");
                        appInvCmd.Parameters.AddWithValue("@chqBranch", resolvedBranch);
                        appInvCmd.Parameters.AddWithValue("@chqNo", dto.ChequeNumber?.Trim() ?? "");
                        appInvCmd.Parameters.AddWithValue("@chqDate", dto.ChequeDate.HasValue ? (object)dto.ChequeDate.Value.Date : DBNull.Value);
                        appInvCmd.Parameters.AddWithValue("@det1", dto.Comments?.Trim() ?? "");
                        appInvCmd.Parameters.AddWithValue("@det2", resolvedLocation);
                        appInvCmd.Parameters.AddWithValue("@det3", "");
                        await appInvCmd.ExecuteNonQueryAsync();

                        // 2. Insert into Main ERP DPay table
                        using var dpayCmd = erpConn.CreateCommand();
                        dpayCmd.CommandText = @"
                            DECLARE @newRNo INT = (SELECT ISNULL(MAX(RNo), 0) + 1 FROM DPay);
                            INSERT INTO DPay (RNo, Date, InvNo, CCode, Name, Branch, Details, Amount, ShEx, Type, CheNo, PDDate, [Check], Audit, MRNo)
                            VALUES (@newRNo, @date, @inv, @cCode, @cName, 'Jay Pharma', @details, @amount, 0, @type, @cheNo, @pdDate, 'Pending', 'Pending', @mrNo);";

                        dpayCmd.Parameters.AddWithValue("@date", DateTime.Now.Date);
                        dpayCmd.Parameters.AddWithValue("@inv", invNoInt);
                        dpayCmd.Parameters.AddWithValue("@cCode", numericCustCode);
                        dpayCmd.Parameters.AddWithValue("@cName", dto.CustomerName?.Trim() ?? "");
                        dpayCmd.Parameters.AddWithValue("@details", $"Field Payment by {dto.CollectorName}");
                        dpayCmd.Parameters.AddWithValue("@amount", item.AmountSettled);
                        dpayCmd.Parameters.AddWithValue("@type", dto.PaymentMethod.Equals("CHEQUE", StringComparison.OrdinalIgnoreCase) ? "Cheque" : "Cash");
                        dpayCmd.Parameters.AddWithValue("@cheNo", (object?)dto.ChequeNumber ?? "");
                        dpayCmd.Parameters.AddWithValue("@pdDate", dto.ChequeDate.HasValue ? dto.ChequeDate.Value.ToString("dd/MM/yyyy") : "");
                        dpayCmd.Parameters.AddWithValue("@mrNo", numericReceiptNo);
                        await dpayCmd.ExecuteNonQueryAsync();
                    }
                }
            }
            else if (dto.TotalAmount > 0)
            {
                // Advance payment without specific invoice allocation
                using var appInvCmd = erpConn.CreateCommand();
                appInvCmd.CommandText = @"
                    INSERT INTO dbo.AppInvoice 
                    (InvNo, Date, CCode, CName, InVal, SetAmt, Branch, SettleType, CrPeriod, DOther1, DOther2, Other1, Other2,
                     PayType, Bank, ChequeBranch, ChequeNo, ChequeDate, Details1, Details2, Details3)
                    VALUES 
                    (0, @date, @cCode, @cName, 0, @setAmt, 'Jay Pharma', 'Advance', 0, 0, @totAmt, @mrNo, @details,
                     @payType, @bank, @chqBranch, @chqNo, @chqDate, @det1, @det2, @det3);";

                appInvCmd.Parameters.AddWithValue("@date", DateTime.Now.Date);
                appInvCmd.Parameters.AddWithValue("@cCode", numericCustCode);
                appInvCmd.Parameters.AddWithValue("@cName", dto.CustomerName?.Trim() ?? "");
                appInvCmd.Parameters.AddWithValue("@setAmt", dto.TotalAmount);
                appInvCmd.Parameters.AddWithValue("@totAmt", dto.TotalAmount);
                appInvCmd.Parameters.AddWithValue("@mrNo", dto.ManualReceiptNo?.Trim() ?? "");
                appInvCmd.Parameters.AddWithValue("@details", $"Advance | Collector: {dto.CollectorName ?? ""}");

                // New columns (avoid null values as requested)
                appInvCmd.Parameters.AddWithValue("@payType", string.IsNullOrWhiteSpace(dto.PaymentMethod) ? "CASH" : dto.PaymentMethod.Trim());
                appInvCmd.Parameters.AddWithValue("@bank", dto.Bank?.Trim() ?? "");
                appInvCmd.Parameters.AddWithValue("@chqBranch", resolvedBranch);
                appInvCmd.Parameters.AddWithValue("@chqNo", dto.ChequeNumber?.Trim() ?? "");
                appInvCmd.Parameters.AddWithValue("@chqDate", dto.ChequeDate.HasValue ? (object)dto.ChequeDate.Value.Date : DBNull.Value);
                appInvCmd.Parameters.AddWithValue("@det1", dto.Comments?.Trim() ?? "");
                appInvCmd.Parameters.AddWithValue("@det2", resolvedLocation);
                appInvCmd.Parameters.AddWithValue("@det3", "");
                await appInvCmd.ExecuteNonQueryAsync();

                using var dpayCmd = erpConn.CreateCommand();
                dpayCmd.CommandText = @"
                    DECLARE @newRNo INT = (SELECT ISNULL(MAX(RNo), 0) + 1 FROM DPay);
                    INSERT INTO DPay (RNo, Date, InvNo, CCode, Name, Branch, Details, Amount, ShEx, Type, CheNo, PDDate, [Check], Audit, MRNo)
                    VALUES (@newRNo, @date, 0, @cCode, @cName, 'Jay Pharma', @details, @amount, 0, @type, @cheNo, @pdDate, 'Pending', 'Pending', @mrNo);";

                dpayCmd.Parameters.AddWithValue("@date", DateTime.Now.Date);
                dpayCmd.Parameters.AddWithValue("@cCode", numericCustCode);
                dpayCmd.Parameters.AddWithValue("@cName", dto.CustomerName?.Trim() ?? "");
                dpayCmd.Parameters.AddWithValue("@details", $"Field Advance by {dto.CollectorName}");
                dpayCmd.Parameters.AddWithValue("@amount", dto.TotalAmount);
                dpayCmd.Parameters.AddWithValue("@type", dto.PaymentMethod.Equals("CHEQUE", StringComparison.OrdinalIgnoreCase) ? "Cheque" : "Cash");
                dpayCmd.Parameters.AddWithValue("@cheNo", (object?)dto.ChequeNumber ?? "");
                dpayCmd.Parameters.AddWithValue("@pdDate", dto.ChequeDate.HasValue ? dto.ChequeDate.Value.ToString("dd/MM/yyyy") : "");
                dpayCmd.Parameters.AddWithValue("@mrNo", numericReceiptNo);
                await dpayCmd.ExecuteNonQueryAsync();
            }
        }
        catch (Exception erpEx)
        {
            Console.WriteLine($"[Main ERP Realtime Sync Warning]: {erpEx.Message}");
        }

        cache.Remove("customers_all");
        cache.Remove("receipts_all");
        return Results.Ok(new { success = true, receiptNo = dto.ManualReceiptNo.Trim(), message = "Receipt recorded in Realtime." });
    }
    catch (Exception ex)
    {
        tx.Rollback();
        return Results.Json(new { success = false, error = ex.Message }, statusCode: 500);
    }
});

// 6b. Resync past receipts from JayPharmaApp to Main ERP (AppInvoice & DPay)
app.MapPost("/api/receipts/resync-to-erp", async () =>
{
    var mainErpConnStr = await GetMainErpConnectionStringAsync(forceRefresh: true);
    int syncedCount = 0;
    var skippedCount = 0;

    try
    {
        using var appConn = new SqlConnection(connectionString);
        await appConn.OpenAsync();

        using var erpConn = new SqlConnection(mainErpConnStr);
        await erpConn.OpenAsync();

        using var cmd = appConn.CreateCommand();
        cmd.CommandText = @"
            SELECT r.ManualReceiptNo, r.CustomerCode, r.CustomerName, r.CustomerAddress, r.CustomerPhone,
                   r.PaymentMethod, r.Bank, r.Branch, r.ChequeNumber, r.ChequeDate, r.TotalAmount,
                   r.Comments, r.IsAdvancePayment, r.CollectorId, r.CollectorName,
                   r.Latitude, r.Longitude, r.LocationAddress, r.CreatedAt
            FROM Receipts r
            ORDER BY r.CreatedAt ASC";

        var receipts = new List<dynamic>();
        using (var reader = await cmd.ExecuteReaderAsync())
        {
            while (await reader.ReadAsync())
            {
                receipts.Add(new
                {
                    ManualReceiptNo = reader["ManualReceiptNo"].ToString()!,
                    CustomerCode = reader["CustomerCode"].ToString()!,
                    CustomerName = reader["CustomerName"]?.ToString() ?? "",
                    CustomerAddress = reader["CustomerAddress"]?.ToString() ?? "",
                    PaymentMethod = reader["PaymentMethod"]?.ToString() ?? "CASH",
                    Bank = reader["Bank"] != DBNull.Value ? reader["Bank"].ToString() : null,
                    Branch = reader["Branch"] != DBNull.Value ? reader["Branch"].ToString() : null,
                    ChequeNumber = reader["ChequeNumber"] != DBNull.Value ? reader["ChequeNumber"].ToString() : null,
                    ChequeDate = reader["ChequeDate"] != DBNull.Value ? (DateTime?)reader["ChequeDate"] : null,
                    TotalAmount = Convert.ToDouble(reader["TotalAmount"]),
                    Comments = reader["Comments"] != DBNull.Value ? reader["Comments"].ToString() : "",
                    CollectorName = reader["CollectorName"]?.ToString() ?? "Collector",
                    LocationAddress = reader["LocationAddress"] != DBNull.Value ? reader["LocationAddress"].ToString() : "",
                    Latitude = reader["Latitude"] != DBNull.Value ? Convert.ToDouble(reader["Latitude"]) : 0.0,
                    Longitude = reader["Longitude"] != DBNull.Value ? Convert.ToDouble(reader["Longitude"]) : 0.0,
                    CreatedAt = Convert.ToDateTime(reader["CreatedAt"])
                });
            }
        }

        foreach (var r in receipts)
        {
            string mrNo = r.ManualReceiptNo;

            using var chkCmd = erpConn.CreateCommand();
            chkCmd.CommandText = "SELECT COUNT(1) FROM dbo.AppInvoice WHERE Other1 = @mr";
            chkCmd.Parameters.AddWithValue("@mr", mrNo);
            int exists = Convert.ToInt32(await chkCmd.ExecuteScalarAsync());
            if (exists > 0)
            {
                skippedCount++;
                continue;
            }

            var invs = new List<dynamic>();
            using (var invCmd = appConn.CreateCommand())
            {
                invCmd.CommandText = "SELECT InvoiceNo, InvoiceAmount, AmountSettled, RemainingBalance FROM ReceiptInvoices WHERE ManualReceiptNo = @mr ORDER BY ItemIndex";
                invCmd.Parameters.AddWithValue("@mr", mrNo);
                using var invReader = await invCmd.ExecuteReaderAsync();
                while (await invReader.ReadAsync())
                {
                    invs.Add(new
                    {
                        InvoiceNo = invReader["InvoiceNo"].ToString()!,
                        InvoiceAmount = Convert.ToDouble(invReader["InvoiceAmount"]),
                        AmountSettled = Convert.ToDouble(invReader["AmountSettled"]),
                        RemainingBalance = Convert.ToDouble(invReader["RemainingBalance"])
                    });
                }
            }

            int numericReceiptNo = 0;
            var numMatch = Regex.Match(mrNo, @"\d+");
            if (numMatch.Success) int.TryParse(numMatch.Value, out numericReceiptNo);

            int numericCustCode = 0;
            int.TryParse(r.CustomerCode, out numericCustCode);

            string resolvedLocation = !string.IsNullOrWhiteSpace(r.LocationAddress)
                ? r.LocationAddress.Trim()
                : (r.Latitude != 0 && r.Longitude != 0 ? $"GPS: {r.Latitude:F6}, {r.Longitude:F6}" : "Jay Pharma");
            if (resolvedLocation.Length > 250) resolvedLocation = resolvedLocation.Substring(0, 250);

            string resolvedBranch = !string.IsNullOrWhiteSpace(r.Branch) 
                ? r.Branch.Trim() 
                : (resolvedLocation.Length > 100 ? resolvedLocation.Substring(0, 100) : resolvedLocation);

            if (invs.Count > 0)
            {
                foreach (var item in invs)
                {
                    if (int.TryParse(item.InvoiceNo, out int invNoInt))
                    {
                        using var appInvCmd = erpConn.CreateCommand();
                        appInvCmd.CommandText = @"
                            INSERT INTO dbo.AppInvoice 
                            (InvNo, Date, CCode, CName, InVal, SetAmt, Branch, SettleType, CrPeriod, DOther1, DOther2, Other1, Other2,
                             PayType, Bank, ChequeBranch, ChequeNo, ChequeDate, Details1, Details2, Details3)
                            VALUES 
                            (@inv, @date, @cCode, @cName, @inVal, @setAmt, 'Jay Pharma', @settleType, 0, @remBal, @totAmt, @mrNo, @details,
                             @payType, @bank, @chqBranch, @chqNo, @chqDate, @det1, @det2, @det3);";

                        appInvCmd.Parameters.AddWithValue("@inv", invNoInt);
                        appInvCmd.Parameters.AddWithValue("@date", r.CreatedAt.Date);
                        appInvCmd.Parameters.AddWithValue("@cCode", numericCustCode);
                        appInvCmd.Parameters.AddWithValue("@cName", r.CustomerName);
                        appInvCmd.Parameters.AddWithValue("@inVal", item.InvoiceAmount);
                        appInvCmd.Parameters.AddWithValue("@setAmt", item.AmountSettled);
                        appInvCmd.Parameters.AddWithValue("@settleType", item.RemainingBalance <= 0.01 ? "Settled" : "Part Settled");
                        appInvCmd.Parameters.AddWithValue("@remBal", item.RemainingBalance);
                        appInvCmd.Parameters.AddWithValue("@totAmt", r.TotalAmount);
                        appInvCmd.Parameters.AddWithValue("@mrNo", mrNo);
                        appInvCmd.Parameters.AddWithValue("@details", $"Resync Collector: {r.CollectorName}");
                        appInvCmd.Parameters.AddWithValue("@payType", string.IsNullOrWhiteSpace(r.PaymentMethod) ? "CASH" : r.PaymentMethod.Trim());
                        appInvCmd.Parameters.AddWithValue("@bank", r.Bank ?? "");
                        appInvCmd.Parameters.AddWithValue("@chqBranch", resolvedBranch);
                        appInvCmd.Parameters.AddWithValue("@chqNo", r.ChequeNumber ?? "");
                        appInvCmd.Parameters.AddWithValue("@chqDate", r.ChequeDate != null ? (object)((DateTime)r.ChequeDate).Date : DBNull.Value);
                        appInvCmd.Parameters.AddWithValue("@det1", r.Comments ?? "");
                        appInvCmd.Parameters.AddWithValue("@det2", resolvedLocation);
                        appInvCmd.Parameters.AddWithValue("@det3", "");
                        await appInvCmd.ExecuteNonQueryAsync();

                        using var dpayCmd = erpConn.CreateCommand();
                        dpayCmd.CommandText = @"
                            DECLARE @newRNo INT = (SELECT ISNULL(MAX(RNo), 0) + 1 FROM DPay);
                            INSERT INTO DPay (RNo, Date, InvNo, CCode, Name, Branch, Details, Amount, ShEx, Type, CheNo, PDDate, [Check], Audit, MRNo)
                            VALUES (@newRNo, @date, @inv, @cCode, @cName, 'Jay Pharma', @details, @amount, 0, @type, @cheNo, @pdDate, 'Pending', 'Pending', @mrNo);";

                        dpayCmd.Parameters.AddWithValue("@date", r.CreatedAt.Date);
                        dpayCmd.Parameters.AddWithValue("@inv", invNoInt);
                        dpayCmd.Parameters.AddWithValue("@cCode", numericCustCode);
                        dpayCmd.Parameters.AddWithValue("@cName", r.CustomerName);
                        dpayCmd.Parameters.AddWithValue("@details", $"Resync Payment by {r.CollectorName}");
                        dpayCmd.Parameters.AddWithValue("@amount", item.AmountSettled);
                        dpayCmd.Parameters.AddWithValue("@type", r.PaymentMethod.Equals("CHEQUE", StringComparison.OrdinalIgnoreCase) ? "Cheque" : "Cash");
                        dpayCmd.Parameters.AddWithValue("@cheNo", (object?)r.ChequeNumber ?? "");
                        dpayCmd.Parameters.AddWithValue("@pdDate", r.ChequeDate != null ? ((DateTime)r.ChequeDate).ToString("dd/MM/yyyy") : "");
                        dpayCmd.Parameters.AddWithValue("@mrNo", numericReceiptNo);
                        await dpayCmd.ExecuteNonQueryAsync();
                    }
                }
            }
            else if (r.TotalAmount > 0)
            {
                using var appInvCmd = erpConn.CreateCommand();
                appInvCmd.CommandText = @"
                    INSERT INTO dbo.AppInvoice 
                    (InvNo, Date, CCode, CName, InVal, SetAmt, Branch, SettleType, CrPeriod, DOther1, DOther2, Other1, Other2,
                     PayType, Bank, ChequeBranch, ChequeNo, ChequeDate, Details1, Details2, Details3)
                    VALUES 
                    (0, @date, @cCode, @cName, 0, @setAmt, 'Jay Pharma', 'Advance', 0, 0, @totAmt, @mrNo, @details,
                     @payType, @bank, @chqBranch, @chqNo, @chqDate, @det1, @det2, @det3);";

                appInvCmd.Parameters.AddWithValue("@date", r.CreatedAt.Date);
                appInvCmd.Parameters.AddWithValue("@cCode", numericCustCode);
                appInvCmd.Parameters.AddWithValue("@cName", r.CustomerName);
                appInvCmd.Parameters.AddWithValue("@setAmt", r.TotalAmount);
                appInvCmd.Parameters.AddWithValue("@totAmt", r.TotalAmount);
                appInvCmd.Parameters.AddWithValue("@mrNo", mrNo);
                appInvCmd.Parameters.AddWithValue("@details", $"Resync Advance | Collector: {r.CollectorName}");
                appInvCmd.Parameters.AddWithValue("@payType", string.IsNullOrWhiteSpace(r.PaymentMethod) ? "CASH" : r.PaymentMethod.Trim());
                appInvCmd.Parameters.AddWithValue("@bank", r.Bank ?? "");
                appInvCmd.Parameters.AddWithValue("@chqBranch", resolvedBranch);
                appInvCmd.Parameters.AddWithValue("@chqNo", r.ChequeNumber ?? "");
                appInvCmd.Parameters.AddWithValue("@chqDate", r.ChequeDate != null ? (object)((DateTime)r.ChequeDate).Date : DBNull.Value);
                appInvCmd.Parameters.AddWithValue("@det1", r.Comments ?? "");
                appInvCmd.Parameters.AddWithValue("@det2", resolvedLocation);
                appInvCmd.Parameters.AddWithValue("@det3", "");
                await appInvCmd.ExecuteNonQueryAsync();

                using var dpayCmd = erpConn.CreateCommand();
                dpayCmd.CommandText = @"
                    DECLARE @newRNo INT = (SELECT ISNULL(MAX(RNo), 0) + 1 FROM DPay);
                    INSERT INTO DPay (RNo, Date, InvNo, CCode, Name, Branch, Details, Amount, ShEx, Type, CheNo, PDDate, [Check], Audit, MRNo)
                    VALUES (@newRNo, @date, 0, @cCode, @cName, 'Jay Pharma', @details, @amount, 0, @type, @cheNo, @pdDate, 'Pending', 'Pending', @mrNo);";

                dpayCmd.Parameters.AddWithValue("@date", r.CreatedAt.Date);
                dpayCmd.Parameters.AddWithValue("@cCode", numericCustCode);
                dpayCmd.Parameters.AddWithValue("@cName", r.CustomerName);
                dpayCmd.Parameters.AddWithValue("@details", $"Resync Advance by {r.CollectorName}");
                dpayCmd.Parameters.AddWithValue("@amount", r.TotalAmount);
                dpayCmd.Parameters.AddWithValue("@type", r.PaymentMethod.Equals("CHEQUE", StringComparison.OrdinalIgnoreCase) ? "Cheque" : "Cash");
                dpayCmd.Parameters.AddWithValue("@cheNo", (object?)r.ChequeNumber ?? "");
                dpayCmd.Parameters.AddWithValue("@pdDate", r.ChequeDate != null ? ((DateTime)r.ChequeDate).ToString("dd/MM/yyyy") : "");
                dpayCmd.Parameters.AddWithValue("@mrNo", numericReceiptNo);
                await dpayCmd.ExecuteNonQueryAsync();
            }
            syncedCount++;
        }

        return Results.Ok(new { success = true, syncedCount, skippedCount, total = receipts.Count });
    }
    catch (Exception ex)
    {
        return Results.Json(new { success = false, syncedCount, skippedCount, error = ex.Message }, statusCode: 500);
    }
});

// 7. Day-End Finalize Endpoint (Section 3 Requirement)
app.MapPost("/api/dayend/finalize", async (DayEndFinalizeRequest req) =>
{
    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    // 1. Resolve actual CollectorId from Collectors table or ensure exists to satisfy FK
    string actualCollectorId = req.CollectorId.Trim();
    using (var findColCmd = conn.CreateCommand())
    {
        findColCmd.CommandText = @"
            SELECT TOP 1 CollectorId FROM Collectors 
            WHERE LOWER(LTRIM(RTRIM(CollectorId))) = LOWER(LTRIM(RTRIM(@cId))) 
               OR LOWER(LTRIM(RTRIM(Username))) = LOWER(LTRIM(RTRIM(@cId)))
               OR LOWER(LTRIM(RTRIM(CollectorId))) = LOWER('COL-' + LTRIM(RTRIM(@cId)))";
        findColCmd.Parameters.AddWithValue("@cId", req.CollectorId.Trim());
        var found = await findColCmd.ExecuteScalarAsync();
        if (found != null && found != DBNull.Value)
        {
            actualCollectorId = found.ToString()!;
        }
        else
        {
            using var insCmd = conn.CreateCommand();
            insCmd.CommandText = @"
                IF NOT EXISTS (SELECT 1 FROM Collectors WHERE CollectorId = @cId)
                BEGIN
                    INSERT INTO Collectors (CollectorId, Username, PasswordHash, FullName, Branch, IsActive, CreatedAt)
                    VALUES (@cId, @cId, 'AUTOGEN', @cName, 'Jay Pharma', 1, GETDATE());
                END";
            insCmd.Parameters.AddWithValue("@cId", actualCollectorId);
            insCmd.Parameters.AddWithValue("@cName", req.CollectorName);
            await insCmd.ExecuteNonQueryAsync();
        }
    }

    using var cmd = conn.CreateCommand();
    cmd.CommandText = @"
        IF EXISTS (SELECT 1 FROM DayEndSummaries WHERE CollectorId = @cId AND SummaryDate = @sDate)
        BEGIN
            UPDATE DayEndSummaries 
            SET IsFinalized = 1, FinalizedAt = GETDATE(), CashierNotes = @notes,
                TotalCash = @cash, TotalCheque = @chq, TotalIncome = @income, TotalReceiptsCount = @count
            WHERE CollectorId = @cId AND SummaryDate = @sDate;
        END
        ELSE
        BEGIN
            INSERT INTO DayEndSummaries 
            (SummaryDate, CollectorId, CollectorName, TotalCash, TotalCheque, TotalIncome, TotalReceiptsCount, IsFinalized, FinalizedAt, CashierNotes)
            VALUES 
            (@sDate, @cId, @cName, @cash, @chq, @income, @count, 1, GETDATE(), @notes);
        END";

    cmd.Parameters.AddWithValue("@sDate", req.Date.Date);
    cmd.Parameters.AddWithValue("@cId", actualCollectorId);
    cmd.Parameters.AddWithValue("@cName", req.CollectorName);
    cmd.Parameters.AddWithValue("@cash", req.TotalCash);
    cmd.Parameters.AddWithValue("@chq", req.TotalCheque);
    cmd.Parameters.AddWithValue("@income", req.TotalIncome);
    cmd.Parameters.AddWithValue("@count", req.TotalReceiptsCount);
    cmd.Parameters.AddWithValue("@notes", (object?)req.CashierNotes ?? DBNull.Value);

    await cmd.ExecuteNonQueryAsync();

    return Results.Ok(new { success = true, collectorId = actualCollectorId, message = "Day-End statement finalized and locked for today." });
});

// 7b. Check Collector Day-End Status (Checks if previously finalized and waiting for Day Start)
app.MapGet("/api/dayend/status/{collectorId}", async (string collectorId) =>
{
    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            SELECT TOP 1 IsFinalized, FinalizedAt, SummaryDate 
            FROM DayEndSummaries 
            WHERE CollectorId IN (
                SELECT CollectorId FROM Collectors 
                WHERE LOWER(LTRIM(RTRIM(CollectorId))) = LOWER(LTRIM(RTRIM(@cId))) 
                   OR LOWER(LTRIM(RTRIM(Username))) = LOWER(LTRIM(RTRIM(@cId)))
                   OR LOWER(LTRIM(RTRIM(CollectorId))) = LOWER('COL-' + LTRIM(RTRIM(@cId)))
            ) OR LOWER(LTRIM(RTRIM(CollectorId))) = LOWER(LTRIM(RTRIM(@cId)))
              OR LOWER(LTRIM(RTRIM(CollectorId))) = LOWER('COL-' + LTRIM(RTRIM(@cId)))
            ORDER BY SummaryDate DESC, Id DESC";
        cmd.Parameters.AddWithValue("@cId", collectorId.Trim());
        using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            bool isFinalized = reader["IsFinalized"] != DBNull.Value && Convert.ToBoolean(reader["IsFinalized"]);
            DateTime? finalizedAt = reader["FinalizedAt"] != DBNull.Value ? Convert.ToDateTime(reader["FinalizedAt"]) : (DateTime?)null;
            DateTime? summaryDate = reader["SummaryDate"] != DBNull.Value ? Convert.ToDateTime(reader["SummaryDate"]) : (DateTime?)null;
            return Results.Ok(new 
            { 
                isFinalized = isFinalized, 
                finalizedAt = finalizedAt != null ? finalizedAt.Value.ToString("o") : null,
                summaryDate = summaryDate != null ? summaryDate.Value.ToString("yyyy-MM-dd") : null
            });
        }
        return Results.Ok(new { isFinalized = false, finalizedAt = (string?)null, summaryDate = (string?)null });
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[GET /api/dayend/status Error]: {ex.Message}");
        return Results.Ok(new { isFinalized = false, finalizedAt = (string?)null, error = ex.Message });
    }
});

// 7c. Day Start Action (Unlocks App & Clears Finalized Flag for Collector)
app.MapPost("/api/dayend/start", async (DayStartRequest req) =>
{
    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();
        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            UPDATE DayEndSummaries 
            SET IsFinalized = 0 
            WHERE CollectorId IN (
                SELECT CollectorId FROM Collectors 
                WHERE LOWER(LTRIM(RTRIM(CollectorId))) = LOWER(LTRIM(RTRIM(@cId))) 
                   OR LOWER(LTRIM(RTRIM(Username))) = LOWER(LTRIM(RTRIM(@cId)))
                   OR LOWER(LTRIM(RTRIM(CollectorId))) = LOWER('COL-' + LTRIM(RTRIM(@cId)))
            ) OR LOWER(LTRIM(RTRIM(CollectorId))) = LOWER(LTRIM(RTRIM(@cId)))
              OR LOWER(LTRIM(RTRIM(CollectorId))) = LOWER('COL-' + LTRIM(RTRIM(@cId)))";
        cmd.Parameters.AddWithValue("@cId", req.CollectorId.Trim());
        int rows = await cmd.ExecuteNonQueryAsync();
        return Results.Ok(new { success = true, updatedRows = rows, message = "Day started successfully. Normal access restored." });
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[POST /api/dayend/start Error]: {ex.Message}");
        return Results.Problem(ex.Message);
    }
});

// 8. OTP Generation & Verification for Protected Operations (POS Statement Print for Normal Users)
app.MapPost("/api/otp/generate", async (GenerateOtpRequest req) =>
{
    var otp = Random.Shared.Next(100000, 999999).ToString();

    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();

        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            IF EXISTS (SELECT 1 FROM LastGeneratedOtp WHERE Id = 1)
            BEGIN
                UPDATE LastGeneratedOtp 
                SET OtpCode = @otp, 
                    CollectorId = @collectorId, 
                    CustomerCode = @customerCode, 
                    CustomerName = @customerName, 
                    GeneratedAt = GETDATE(), 
                    ExpiresAt = DATEADD(minute, 15, GETDATE()), 
                    IsUsed = 0, 
                    UsedAt = NULL
                WHERE Id = 1;
            END
            ELSE
            BEGIN
                INSERT INTO LastGeneratedOtp (Id, OtpCode, CollectorId, CustomerCode, CustomerName, GeneratedAt, ExpiresAt, IsUsed)
                VALUES (1, @otp, @collectorId, @customerCode, @customerName, GETDATE(), DATEADD(minute, 15, GETDATE()), 0);
            END";
        cmd.Parameters.AddWithValue("@otp", otp);
        cmd.Parameters.AddWithValue("@collectorId", (object?)req.CollectorId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@customerCode", (object?)req.CustomerCode ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@customerName", (object?)req.CustomerName ?? DBNull.Value);

        await cmd.ExecuteNonQueryAsync();

        return Results.Ok(new 
        { 
            success = true, 
            message = "OTP generated successfully and saved to LastGeneratedOtp.",
            otpCode = otp, // returned for display/testing until SMS gateway is connected
            expiresInMinutes = 15
        });
    }
    catch (Exception ex)
    {
        return Results.Problem($"Failed to save OTP: {ex.Message}");
    }
});

app.MapPost("/api/otp/verify", async (VerifyOtpRequest req) =>
{
    if (string.IsNullOrWhiteSpace(req.OtpCode))
    {
        return Results.BadRequest(new { success = false, message = "OTP code cannot be empty." });
    }

    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();

        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            SELECT OtpCode, ExpiresAt, IsUsed 
            FROM LastGeneratedOtp 
            WHERE Id = 1";

        using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return Results.BadRequest(new { success = false, message = "No OTP has been generated." });
        }

        var savedOtp = reader["OtpCode"].ToString();
        var expiresAt = Convert.ToDateTime(reader["ExpiresAt"]);
        var isUsed = Convert.ToBoolean(reader["IsUsed"]);
        reader.Close();

        if (isUsed)
        {
            return Results.BadRequest(new { success = false, message = "This OTP has already been used. Please request a new one." });
        }

        if (DateTime.UtcNow > expiresAt.ToUniversalTime())
        {
            return Results.BadRequest(new { success = false, message = "OTP has expired. Please request a new one." });
        }

        if (savedOtp != req.OtpCode.Trim())
        {
            return Results.BadRequest(new { success = false, message = "Invalid OTP code entered. Please try again." });
        }

        // Mark as used
        using var markCmd = conn.CreateCommand();
        markCmd.CommandText = "UPDATE LastGeneratedOtp SET IsUsed = 1, UsedAt = GETDATE() WHERE Id = 1";
        await markCmd.ExecuteNonQueryAsync();

        return Results.Ok(new { success = true, message = "OTP verified successfully." });
    }
    catch (Exception ex)
    {
        return Results.Problem($"Verification error: {ex.Message}");
    }
});

app.MapGet("/api/otp/last", async () =>
{
    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();

        using var cmd = conn.CreateCommand();
        cmd.CommandText = @"
            SELECT Id, OtpCode, CollectorId, CustomerCode, CustomerName, GeneratedAt, ExpiresAt, IsUsed, UsedAt 
            FROM LastGeneratedOtp 
            WHERE Id = 1";

        using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return Results.Ok(new
            {
                otpCode = reader["OtpCode"].ToString(),
                collectorId = reader["CollectorId"]?.ToString(),
                customerCode = reader["CustomerCode"]?.ToString(),
                customerName = reader["CustomerName"]?.ToString(),
                generatedAt = Convert.ToDateTime(reader["GeneratedAt"]),
                expiresAt = Convert.ToDateTime(reader["ExpiresAt"]),
                isUsed = Convert.ToBoolean(reader["IsUsed"]),
                usedAt = reader["UsedAt"] != DBNull.Value ? Convert.ToDateTime(reader["UsedAt"]) : (DateTime?)null
            });
        }
        return Results.NotFound(new { message = "No OTP generated yet." });
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
});

app.Run();

// DTO Models
record GenerateOtpRequest(string CollectorId, string? CustomerCode, string? CustomerName);
record VerifyOtpRequest(string CollectorId, string OtpCode);
record LoginRequest(string Username, string Password);
record CreateReceiptDto(
    string ManualReceiptNo,
    string CustomerCode,
    string CustomerName,
    string CustomerAddress,
    string? CustomerPhone,
    string PaymentMethod,
    string? Bank,
    string? Branch,
    string? ChequeNumber,
    DateTime? ChequeDate,
    double TotalAmount,
    string? Comments,
    string CollectorId,
    string CollectorName,
    double Latitude,
    double Longitude,
    string? LocationAddress,
    List<ReceiptInvoiceItemDto>? AllocatedInvoices
);

record ReceiptInvoiceItemDto(
    string InvoiceNo,
    DateTime InvoiceDate,
    double InvoiceAmount,
    double AmountSettled,
    double RemainingBalance
);

record DayEndFinalizeRequest(
    DateTime Date,
    string CollectorId,
    string CollectorName,
    double TotalCash,
    double TotalCheque,
    double TotalIncome,
    int TotalReceiptsCount,
    string? CashierNotes
);

record DayStartRequest(
    string CollectorId
);

record CreateUserRequest(
    string? CollectorId,
    string Username,
    string Password,
    string FullName,
    string? Phone,
    string? Branch,
    string? AccessLevel,
    string? AssignedLocations
);

record UpdateLocationsRequest(
    string AssignedLocations
);
