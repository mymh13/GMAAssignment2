namespace OutdoorsyCloudyMvc.Models;

public class ReviewViewModel
{
    public Review NewReview { get; set; } = new();
    public List<Review> Reviews { get; set; } = [];
}
