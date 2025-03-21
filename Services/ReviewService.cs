using OutdoorsyCloudyMvc.Models;
using OutdoorsyCloudyMvc.Repositories;

namespace OutdoorsyCloudyMvc.Services;

public class ReviewService : IReviewService
{
    private readonly IReviewRepository _reviewRepository;

    public ReviewService(IReviewRepository reviewRepository)
    {
        _reviewRepository = reviewRepository;
    }

    public async Task<OperationResult> SubmitReviewAsync(Review review)
    {
        if (review == null || string.IsNullOrWhiteSpace(review.Email))
        {
            return OperationResult.Failure("Invalid review data");
        }

        if (await _reviewRepository.ExistsAsync(review.Email))
        {
            return OperationResult.Failure("A review from this email already exists");
        }

        var success = await _reviewRepository.AddReviewAsync(review);
        if (!success)
        {
            return OperationResult.Failure("Failed to submit review");
        }

        return OperationResult.Success($"Thanks for your review, {review.Name}!");
    }

    public async Task<OperationResult> DeleteReviewAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            return OperationResult.Failure("Invalid email address");
        }

        var existing = await _reviewRepository.GetReviewByEmailAsync(email);
        if (existing == null)
        {
            return OperationResult.Failure("No review found for this email");
        }

        var success = await _reviewRepository.DeleteReviewAsync(email);
        if (!success)
        {
            return OperationResult.Failure("Failed to delete review");
        }

        return OperationResult.Success("Review deleted successfully");
    }

    public async Task<IEnumerable<Review>> GetAllReviewsAsync()
    {
        var reviews = await _reviewRepository.GetAllReviewsAsync();
        return reviews.ToList();
    }

    public async Task<IEnumerable<Review>> GetApprovedReviewsAsync()
    {
        var reviews = await _reviewRepository.GetAllReviewsAsync();
        return reviews.Where(r => r.IsApproved).ToList();
    }

    public async Task<OperationResult> DeleteReviewByEmailAsync(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            return OperationResult.Failure("Invalid email address");
        }

        var existing = await _reviewRepository.GetReviewByEmailAsync(email);
        if (existing == null)
        {
            return OperationResult.Failure("No review found for this email");
        }

        var success = await _reviewRepository.DeleteReviewAsync(email);
        if (!success)
        {
            return OperationResult.Failure("Failed to delete review");
        }

        return OperationResult.Success("Review deleted successfully");
    }
}
