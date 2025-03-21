using System.ComponentModel.DataAnnotations;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace OutdoorsyCloudyMvc.Models;

public class Review
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; } = string.Empty;

    [Required]
    [StringLength(20, MinimumLength = 3, ErrorMessage = "Name must be between 3 and 20 characters")]
    [BsonElement("name")]
    public string Name { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    [RegularExpression(@"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$", ErrorMessage = "Invalid email address")]
    [BsonElement("email")]
    public string Email { get; set; } = string.Empty;

    [Required]
    [StringLength(300, MinimumLength = 5, ErrorMessage = "Comment must be between 5 and 300 characters")]
    [BsonElement("comment")]
    public string Comment { get; set; } = string.Empty;

    [BsonElement("date")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [BsonElement("approved")]
    public bool IsApproved { get; set; } = true; // Optional, for moderation
}