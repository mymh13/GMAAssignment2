using OutdoorsyCloudyMvc.Models;
using MongoDB.Driver;

namespace OutdoorsyCloudyMvc.Repositories;

public class MongoDbReviewRepository : IReviewRepository
{
    private readonly IMongoCollection<Review> _reviews;

    public MongoDbReviewRepository(IMongoCollection<Review> reviews)
    {
        _reviews = reviews;
    }

    public async Task<IEnumerable<Review>> GetAllReviewsAsync()
    {
        return await _reviews.Find(_ => true).ToListAsync();
    }

    public async Task<Review?> GetReviewByEmailAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return null;

        return await _reviews.Find(r => r.Email == email).FirstOrDefaultAsync();
    }

    public async Task<bool> AddReviewAsync(Review review)
    {
        if (review == null || string.IsNullOrWhiteSpace(review.Email))
            return false;

        var existing = await GetReviewByEmailAsync(review.Email);
        if (existing != null)
            return false;

        try
        {
            await _reviews.InsertOneAsync(review);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> UpdateReviewAsync(Review review)
    {
        if (review == null || string.IsNullOrWhiteSpace(review.Email))
            return false;

        try
        {
            var result = await _reviews.ReplaceOneAsync(r => r.Email == review.Email, review, new ReplaceOptions { IsUpsert = true });
            return result.ModifiedCount > 0;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> DeleteReviewAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return false;

        try
        {
            var result = await _reviews.DeleteOneAsync(r => r.Email == email);
            return result.DeletedCount > 0;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> ExistsAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return false;

        return await _reviews.CountDocumentsAsync(r => r.Email == email) > 0;
    }
}
