using Microsoft.AspNetCore.Mvc;
using OutdoorsyCloudyMvc.Models;
using OutdoorsyCloudyMvc.Services;

namespace OutdoorsyCloudyMvc.Controllers;

public class ReviewController : Controller
{
    private readonly IReviewService _reviewService;

    public ReviewController(IReviewService reviewService)
    {
        _reviewService = reviewService;
    }

    [HttpGet]
    public IActionResult Submit()
    {
        return View();
    }

    [HttpPost]
    public async Task<IActionResult> Submit(Review review)
    {
        if (!ModelState.IsValid)
        {
            return View(review);
        }

        var result = await _reviewService.SubmitReviewAsync(review);
        if (!result.IsSuccess)
        {
            ModelState.AddModelError("Email", result.Message);
            return View(review);
        }

        Console.WriteLine($"New review - Name: {review.Name} Email: {review.Email} Comment: {review.Comment}");

        TempData["SuccessMessage"] = result.Message;

        return RedirectToAction(nameof(Submit));
    }

    [HttpGet]
    public async Task<IActionResult> Reviews()
    {
        var reviews = await _reviewService.GetApprovedReviewsAsync();
        return View(reviews);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RemoveReview(string email)
    {
        var result = await _reviewService.DeleteReviewByEmailAsync(email);
        if (result.IsSuccess)
        {
            TempData["SuccessMessage"] = result.Message;
        }

        return RedirectToAction(nameof(Reviews));
    }
}
