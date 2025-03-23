namespace OutdoorsyCloudyMvc.Storage;

/// <summary>
/// Service interface for image handling using Azure Blob Storage.
/// Currently implemented but disabled pending authentication system.
/// Configuration: Uses BLOB_CONNECTION_STRING and BLOB_CONTAINER_NAME from environment.
/// </summary>
public interface IImageService
{
    // Future implementation will include:
    // Task<string> UploadImageAsync(IFormFile file);
    // Task DeleteImageAsync(string blobName);
    string GetImageUrl(string blobName);
}