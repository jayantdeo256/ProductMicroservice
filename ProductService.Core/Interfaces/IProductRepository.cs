using ProductService.Core.Models;

namespace ProductService.Core.Interfaces;

public interface IProductRepository
{
    Task<Product?> GetByIdAsync(int id); // Changed to nullable
    Task<List<Product>> GetAllAsync();
    Task<Product> AddAsync(Product product);
    Task<Product> UpdateAsync(Product product);
    Task<bool> DeleteAsync(int id);
}