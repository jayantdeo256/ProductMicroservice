using Microsoft.AspNetCore.Mvc;
using ProductService.API.DTOs;
using ProductService.Core.Interfaces;
using ProductService.Core.Models;
using Prometheus;

namespace ProductService.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly IProductRepository _productRepository;
    
    // Custom metrics
    private static readonly Counter _productsCreatedCounter = Metrics
        .CreateCounter("products_created_total", "Total number of products created");
    
    private static readonly Counter _productsRequestCounter = Metrics
        .CreateCounter("products_requests_total", "Total number of product API requests", new CounterConfiguration
        {
            LabelNames = new[] { "method", "endpoint" }
        });
    
    private static readonly Gauge _productsInStockGauge = Metrics
        .CreateGauge("products_in_stock", "Current number of products in stock");
    
    private static readonly Histogram _requestDuration = Metrics
        .CreateHistogram("request_duration_seconds", "Duration of HTTP requests");

    public ProductsController(IProductRepository productRepository)
    {
        _productRepository = productRepository;
    }

    [HttpGet]
    public async Task<ActionResult<List<ProductDto>>> GetProducts()
    {
        using (_requestDuration.NewTimer())
        {
            _productsRequestCounter.WithLabels("GET", "all").Inc();
            
            var products = await _productRepository.GetAllAsync();
            UpdateStockGauge(products);
            
            var productDtos = products.Select(p => new ProductDto
            {
                Id = p.Id,
                Name = p.Name,
                Description = p.Description,
                Price = p.Price,
                Stock = p.Stock,
                CreatedAt = p.CreatedAt,
                UpdatedAt = p.UpdatedAt
            }).ToList();

            return Ok(productDtos);
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ProductDto>> GetProduct(int id)
    {
        using (_requestDuration.NewTimer())
        {
            _productsRequestCounter.WithLabels("GET", "byid").Inc();
            
            var product = await _productRepository.GetByIdAsync(id);
            if (product == null) 
            {
                _productsRequestCounter.WithLabels("GET", "byid-notfound").Inc();
                return NotFound();
            }

            var productDto = new ProductDto
            {
                Id = product.Id,
                Name = product.Name,
                Description = product.Description,
                Price = product.Price,
                Stock = product.Stock,
                CreatedAt = product.CreatedAt,
                UpdatedAt = product.UpdatedAt
            };

            return Ok(productDto);
        }
    }

    [HttpPost]
    public async Task<ActionResult<ProductDto>> CreateProduct(CreateProductDto createProductDto)
    {
        using (_requestDuration.NewTimer())
        {
            _productsRequestCounter.WithLabels("POST", "create").Inc();
            
            var product = new Product
            {
                Name = createProductDto.Name,
                Description = createProductDto.Description,
                Price = createProductDto.Price,
                Stock = createProductDto.Stock
            };

            var createdProduct = await _productRepository.AddAsync(product);
            
            // Increment creation counter
            _productsCreatedCounter.Inc();

            var productDto = new ProductDto
            {
                Id = createdProduct.Id,
                Name = createdProduct.Name,
                Description = createdProduct.Description,
                Price = createdProduct.Price,
                Stock = createdProduct.Stock,
                CreatedAt = createdProduct.CreatedAt,
                UpdatedAt = createdProduct.UpdatedAt
            };

            return CreatedAtAction(nameof(GetProduct), new { id = productDto.Id }, productDto);
        }
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateProduct(int id, CreateProductDto updateProductDto)
    {
        using (_requestDuration.NewTimer())
        {
            _productsRequestCounter.WithLabels("PUT", "update").Inc();
            
            var existingProduct = await _productRepository.GetByIdAsync(id);
            if (existingProduct == null) return NotFound();

            existingProduct.Name = updateProductDto.Name;
            existingProduct.Description = updateProductDto.Description;
            existingProduct.Price = updateProductDto.Price;
            existingProduct.Stock = updateProductDto.Stock;

            await _productRepository.UpdateAsync(existingProduct);

            return NoContent();
        }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteProduct(int id)
    {
        using (_requestDuration.NewTimer())
        {
            _productsRequestCounter.WithLabels("DELETE", "delete").Inc();
            
            var result = await _productRepository.DeleteAsync(id);
            if (!result) return NotFound();

            return NoContent();
        }
    }

    private void UpdateStockGauge(List<Product> products)
    {
        var totalStock = products.Sum(p => p.Stock);
        _productsInStockGauge.Set(totalStock);
    }
}