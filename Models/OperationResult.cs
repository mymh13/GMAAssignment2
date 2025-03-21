namespace OutdoorsyCloudyMvc.Models;

public class OperationResult
{
        public bool IsSuccess { get; private set; }
        public string Message { get; private set; }

        public OperationResult(bool success, string message)
        {
            IsSuccess = success;
            Message = message;
        }
        
        public static OperationResult Success(string message = "Operation successful") => new(true, message);
        public static OperationResult Failure(string message = "Operation failed") => new(false, message);
}