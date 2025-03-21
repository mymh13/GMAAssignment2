using OutdoorsyCloudyMvc.Models;

namespace OutdoorsyCloudyMvc.Repositories;

public interface IReviewRepository
{
    Task<IEnumerable<Review>> GetAllReviewsAsync();
    Task<Review?> GetReviewByEmailAsync(string email);
    Task<bool> AddReviewAsync(Review review);
    Task<bool> UpdateReviewAsync(Review review);
    Task<bool> DeleteReviewAsync(string email);
    Task<bool> ExistsAsync(string email);
}
