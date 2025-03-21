using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using OutdoorsyCloudyMvc.Models;
using OutdoorsyCloudyMvc.Storage;

namespace OutdoorsyCloudyMvc.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;
    private readonly IImageService _imageService;

    public HomeController(ILogger<HomeController> logger, IImageService imageService)
    {
        _logger = logger;
        _imageService = imageService;
    }

    public IActionResult Index()
    {
        return View();
    }

    public IActionResult Privacy()
    {
        return View();
    }

    public IActionResult About()
    {
        var heroUrl = _imageService.GetImageUrl("hero.jpg");
        _logger.LogInformation($"Generated hero image URL: {heroUrl}");
        ViewData["HeroImageUrl"] = heroUrl;
        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        // Get hero image URL from the image service
        ViewData["HeroImageUrl"] = _imageService.GetImageUrl("hero.jpg");
        return View();
    }
}