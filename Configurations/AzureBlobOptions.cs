namespace OutdoorsyCloudyMvc.Configurations;

public class AzureBlobOptions
{
    public const string SectionName = "AzureBlob";
    
    public string BaseUrl { get; set; } = string.Empty;
    public string ContainerName { get; set; } = string.Empty;

    public string ContainerUrl => $"{BaseUrl}/{ContainerName}";
}