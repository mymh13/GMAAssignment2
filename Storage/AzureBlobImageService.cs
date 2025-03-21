using Microsoft.Extensions.Options;
using OutdoorsyCloudyMvc.Configurations;

namespace OutdoorsyCloudyMvc.Storage;

public class AzureBlobImageService : IImageService
{
    private readonly AzureBlobOptions _options;
    private readonly ILogger<AzureBlobImageService> _logger;
    private readonly IWebHostEnvironment _environment;

    public AzureBlobImageService(
        IOptions<AzureBlobOptions> options,
        ILogger<AzureBlobImageService> logger,
        IWebHostEnvironment environment)
    {
        _options = options.Value;
        _logger = logger;
        _environment = environment;
    }

    public string GetImageUrl(string imageName)
    {
        // First try to get from Azure Blob if configured
        if (!string.IsNullOrEmpty(_options.BaseUrl) && !string.IsNullOrEmpty(_options.ContainerName))
        {
            try
            {
                var blobUrl = $"{_options.BaseUrl}/{_options.ContainerName}/{imageName}";
                _logger.LogInformation($"Using Azure Blob URL: {blobUrl}");
                return blobUrl;
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to get Azure Blob URL: {ex.Message}");
            }
        }
        else
        {
            _logger.LogInformation("Azure Blob Storage not configured, falling back to local files");
        }

        // Fall back to local file if it exists
        var localPath = Path.Combine(_environment.WebRootPath, "images", imageName);
        if (System.IO.File.Exists(localPath))
        {
            var localUrl = $"/images/{imageName}";
            _logger.LogInformation($"Using local file URL: {localUrl}");
            return localUrl;
        }

        _logger.LogWarning($"Image not found in either Azure Blob or locally: {imageName}");
        return string.Empty;
    }
} 