using OutdoorsyCloudyMvc.Models;

namespace OutdoorsyCloudyMvc.Services;

public interface IReviewService
{
    Task<OperationResult> SubmitReviewAsync(Review review);
    Task<OperationResult> DeleteReviewByEmailAsync(string email);
    Task<IEnumerable<Review>> GetAllReviewsAsync();
    Task<IEnumerable<Review>> GetApprovedReviewsAsync();
}
