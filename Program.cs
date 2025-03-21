using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

// Load env from file
var envFilePath = "/etc/OutdoorsyCloudyMvc/.env";
if (File.Exists(envFilePath))
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
}

// Add services to the container.
builder.Services.AddControllersWithViews();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

// Configure forwarded headers, this is because Kestrel runs behind an Nginx proxy
var bastionIp = Environment.GetEnvironmentVariable("BASTION_VM_PRIVATE_IP") ?? "127.0.0.1";
var forwardOptions = new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
};
forwardOptions.KnownNetworks.Clear(); // Clear the default networks
forwardOptions.KnownProxies.Clear();  // Clear the default proxies
forwardOptions.KnownProxies.Add(System.Net.IPAddress.Parse(bastionIp)); // BastionVM private IP

app.UseForwardedHeaders(forwardOptions);

app.UseHttpsRedirection();
app.UseRouting();

app.UseAuthorization();

app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();

// Run the app on port 5000, Kestrel is only listening locally so not accessible by Nginx
app.Run("http://0.0.0.0:5000");