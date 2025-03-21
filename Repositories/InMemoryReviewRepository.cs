using OutdoorsyCloudyMvc.Models;
using System.Collections.Concurrent;

namespace OutdoorsyCloudyMvc.Repositories;

public class InMemoryReviewRepository : IReviewRepository
{
    private readonly ConcurrentDictionary<string, Review> _reviews = new(StringComparer.OrdinalIgnoreCase);

    public Task<IEnumerable<Review>> GetAllReviewsAsync()
    {
        return Task.FromResult(_reviews.Values.AsEnumerable());
    }

    public Task<Review?> GetReviewByEmailAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return Task.FromResult<Review?>(null);

        _reviews.TryGetValue(email, out var review);
        return Task.FromResult(review);
    }

    public Task<bool> AddReviewAsync(Review review)
    {
        if (review == null || string.IsNullOrWhiteSpace(review.Email))
            return Task.FromResult(false);

        return Task.FromResult(_reviews.TryAdd(review.Email, review));
    }

    public Task<bool> UpdateReviewAsync(Review review)
    {
        if (review == null || string.IsNullOrWhiteSpace(review.Email))
            return Task.FromResult(false);

        if (!_reviews.ContainsKey(review.Email))
            return Task.FromResult(false);

        _reviews[review.Email] = review;
        return Task.FromResult(true);
    }

    public Task<bool> DeleteReviewAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return Task.FromResult(false);

        return Task.FromResult(_reviews.TryRemove(email, out _));
    }

    public Task<bool> ExistsAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return Task.FromResult(false);

        return Task.FromResult(_reviews.ContainsKey(email));
    }
}
