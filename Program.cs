using Microsoft.AspNetCore.HttpOverrides;
using MongoDB.Driver;
using OutdoorsyCloudyMvc.Configurations;
using OutdoorsyCloudyMvc.Models;
using OutdoorsyCloudyMvc.Repositories;
using OutdoorsyCloudyMvc.Services;
using OutdoorsyCloudyMvc.Storage;

var builder = WebApplication.CreateBuilder(args);

// --- Load environment variables from .env file ---
var envFilePaths = new[]
{
    "/etc/OutdoorsyCloudyMvc/.env",
    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".config/OutdoorsyCloudyMvc/.env"),
    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OutdoorsyCloudyMvc/.env")
};

var envFilePath = envFilePaths.FirstOrDefault(File.Exists);
if (envFilePath != null)
{
    var lines = File.ReadAllLines(envFilePath);
    foreach (var line in lines)
    {
        var parts = line.Split('=', 2);
        if (parts.Length == 2)
        {
            Environment.SetEnvironmentVariable(parts[0], parts[1]);
        }
    }
    Console.WriteLine($"Environment variables loaded from {envFilePath}");
}
else
{
    Console.WriteLine("Warning: No .env file found in any of the expected locations.");
}

// --- Add services to the container ---
builder.Services.AddControllersWithViews();
builder.Services.AddHttpContextAccessor();

// --- Configure Azure Blob Storage ---
var blobConnectionString = Environment.GetEnvironmentVariable("BLOB_CONNECTION_STRING") ?? "";
var containerName = Environment.GetEnvironmentVariable("BLOB_CONTAINER_NAME") ?? "";

// Extract the blob endpoint from the connection string
var blobEndpoint = "";
if (!string.IsNullOrEmpty(blobConnectionString))
{
    var parts = blobConnectionString.Split(';');
    foreach (var part in parts)
    {
        if (part.StartsWith("BlobEndpoint="))
        {
            blobEndpoint = part.Substring("BlobEndpoint=".Length).TrimEnd('/');
            break;
        }
    }
}

builder.Configuration[AzureBlobOptions.SectionName + ":BaseUrl"] = blobEndpoint;
builder.Configuration[AzureBlobOptions.SectionName + ":ContainerName"] = containerName;

builder.Services.Configure<AzureBlobOptions>(
    builder.Configuration.GetSection(AzureBlobOptions.SectionName));

builder.Services.AddSingleton<IImageService, OutdoorsyCloudyMvc.Storage.AzureBlobImageService>();

// --- Configure MongoDB from ENV variables ---
var mongoOptions = new MongoDbOptions
{
    ConnectionString = Environment.GetEnvironmentVariable("MONGO_CONNECTION_STRING") ?? "",
    DatabaseName = Environment.GetEnvironmentVariable("MONGO_DATABASE_NAME") ?? "",
    CollectionName = Environment.GetEnvironmentVariable("MONGO_COLLECTION_NAME") ?? ""
};

builder.Services.AddSingleton<IMongoClient>(_ => new MongoClient(mongoOptions.ConnectionString));
builder.Services.AddSingleton<IMongoCollection<Review>>(sp =>
{
    var client = sp.GetRequiredService<IMongoClient>();
    var db = client.GetDatabase(mongoOptions.DatabaseName);
    return db.GetCollection<Review>(mongoOptions.CollectionName);
});

builder.Services.AddSingleton<IReviewRepository, MongoDbReviewRepository>();
builder.Services.AddScoped<IReviewService, ReviewService>();

// --- Kestrel / Security hardening ---
builder.WebHost.UseKestrel(opts => opts.AddServerHeader = false);
builder.WebHost.UseSetting("AllowedHosts", "*");

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

// --- Configure forwarded headers ---
var bastionIp = Environment.GetEnvironmentVariable("BASTION_VM_PRIVATE_IP") ?? "127.0.0.1";
var forwardedHeaders = new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
};
forwardedHeaders.KnownNetworks.Clear();
forwardedHeaders.KnownProxies.Clear();
forwardedHeaders.KnownProxies.Add(System.Net.IPAddress.Parse(bastionIp));
app.UseForwardedHeaders(forwardedHeaders);

// --- HTTP pipeline ---
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();

// --- Start Kestrel on internal port 5000 ---
app.Run("http://0.0.0.0:5000");